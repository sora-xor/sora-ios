// SPDX-License-Identifier: BSD-4-Clause
import Foundation
import IrohaCrypto
import RobinHood
import SSFUtils
import XCTest
@testable import SoraPassport

@MainActor
final class WebSocketStorageFlowTests: XCTestCase {
    private let key = Data([1, 2]), blockHash = Data(repeating: 9, count: 32)
    private func run(_ child: RecordingStorageChild, data: Data?, manager: StorageFlowManager) async {
        let done = expectation(description: "storage change and callback completed"); manager.done = { done.fulfill() }
        child.processUpdate(data, blockHash: blockHash); await fulfillment(of: [done], timeout: 3)
    }
    private func stored(_ repo: StorageFlowRepository) throws -> ChainStorageItem? { let operation = repo.fetchOperation(by: { "local" }, options: .init()); operation.start(); return try XCTUnwrap(operation.result).get() }
    private func makeChild(_ repo: StorageFlowRepository = StorageFlowRepository()) -> (RecordingStorageChild, StorageFlowRepository, StorageFlowManager) {
        let manager = StorageFlowManager()
        return (RecordingStorageChild(remoteStorageKey: key, localStorageKey: "local", storage: AnyDataProviderRepository(repo), operationManager: manager, logger: Logger.shared), repo, manager)
    }
    func testNewStorageValueIsPersistedBeforeItsInsertCallback() async throws {
        let (child, repo, manager) = makeChild(); await run(child, data: Data([3]), manager: manager)
        XCTAssertEqual(try stored(repo)?.data, Data([3])); XCTAssertEqual(child.kinds, ["insert"]); XCTAssertEqual(child.blocks, [blockHash])
    }
    func testChangedStorageValueProducesAnUpdate() async throws {
        let (child, repo, manager) = makeChild(); await run(child, data: Data([3]), manager: manager); await run(child, data: Data([4]), manager: manager)
        XCTAssertEqual(try stored(repo)?.data, Data([4])); XCTAssertEqual(child.kinds, ["insert", "update"])
    }
    func testUnchangedStorageValueDoesNotInventAChange() async throws {
        let (child, _, manager) = makeChild(); await run(child, data: Data([3]), manager: manager); await run(child, data: Data([3]), manager: manager)
        XCTAssertEqual(child.kinds, ["insert", "none"])
    }
    func testNilStorageDeletesTheStoredValue() async throws {
        let (child, repo, manager) = makeChild(); await run(child, data: Data([3]), manager: manager); await run(child, data: nil, manager: manager)
        XCTAssertNil(try stored(repo)); XCTAssertEqual(child.kinds, ["insert", "delete"])
    }
    func testAbsentValueFollowedByNilIsNotADeletion() async {
        let (child, _, manager) = makeChild(); await run(child, data: nil, manager: manager); XCTAssertEqual(child.kinds, ["none"])
    }
    func testReadFailureIsReportedWithoutOverwritingStoredData() async throws {
        let (child, repo, manager) = makeChild(); await run(child, data: Data([3]), manager: manager)
        repo.failReads = true; await run(child, data: Data([4]), manager: manager); repo.failReads = false
        XCTAssertEqual(child.kinds, ["insert", "failure"]); XCTAssertEqual(try stored(repo)?.data, Data([3]))
    }
    func testSaveFailureCannotBeAnnouncedAsASuccessfulStorageChange() async throws {
        let (child, repo, manager) = makeChild(); repo.failWrites = true; await run(child, data: Data([4]), manager: manager)
        XCTAssertNil(try stored(repo)); XCTAssertEqual(child.kinds, ["failure"])
    }
    func testSaveFailureCanRetryWithoutLosingTheUpdate() async throws {
        let (child, repo, manager) = makeChild(); repo.failWrites = true; await run(child, data: Data([4]), manager: manager)
        repo.failWrites = false; await run(child, data: Data([4]), manager: manager)
        XCTAssertEqual(try stored(repo)?.data, Data([4])); XCTAssertEqual(child.kinds, ["failure", "insert"])
    }
    func testContainerSubscribesToAllExactRemoteKeys() {
        let engine = StorageFlowEngine(), first = StorageFlowChild(Data([1])), second = StorageFlowChild(Data([2]))
        let container = StorageSubscriptionContainer(engine: engine, children: [first, second], logger: Logger.shared)
        XCTAssertEqual(engine.keys, [["0x01", "0x02"]]); XCTAssertEqual(container.children.count, 2)
    }
    func testContainerRoutesOnlyMatchingStorageKeys() throws {
        let engine = StorageFlowEngine(), first = StorageFlowChild(Data([1])), second = StorageFlowChild(Data([2]))
        let container = StorageSubscriptionContainer(engine: engine, children: [first, second], logger: Logger.shared)
        try engine.update(changes: [["0x02", "0x0304"]]); XCTAssertTrue(first.values.isEmpty); XCTAssertEqual(second.values, [Data([3, 4])])
        withExtendedLifetime(container) {}
    }
    func testContainerPassesExactBlockHashAndDeletion() throws {
        let engine = StorageFlowEngine(), child = StorageFlowChild(key)
        let container = StorageSubscriptionContainer(engine: engine, children: [child], logger: Logger.shared)
        try engine.update(changes: [["0x0102", NSNull()]], block: blockHash.toHex(includePrefix: true))
        XCTAssertEqual(child.values.count, 1); XCTAssertNil(child.values[0]); XCTAssertEqual(child.blocks, [blockHash]); withExtendedLifetime(container) {}
    }
    func testContainerFansOutAKeyToEachInterestedChild() throws {
        let engine = StorageFlowEngine(), first = StorageFlowChild(key), second = StorageFlowChild(key)
        let container = StorageSubscriptionContainer(engine: engine, children: [first, second], logger: Logger.shared)
        try engine.update(changes: [["0x0102", "0x03"]]); XCTAssertEqual(first.values, [Data([3])]); XCTAssertEqual(second.values, first.values); withExtendedLifetime(container) {}
    }
    func testMalformedHexValueCannotBeConvertedIntoADeletion() throws {
        let engine = StorageFlowEngine(), child = StorageFlowChild(key)
        let container = StorageSubscriptionContainer(engine: engine, children: [child], logger: Logger.shared)
        try engine.update(changes: [["0x0102", "not-hex"]]); XCTAssertTrue(child.values.isEmpty); withExtendedLifetime(container) {}
    }
    func testMalformedKeyAndWrongRowArityAreIgnored() throws {
        let engine = StorageFlowEngine(), child = StorageFlowChild(key)
        let container = StorageSubscriptionContainer(engine: engine, children: [child], logger: Logger.shared)
        try engine.update(changes: [["bad", "0x01"], ["0x0102"], ["0x0102", "0x01", "extra"]]); XCTAssertTrue(child.values.isEmpty); withExtendedLifetime(container) {}
    }
    func testUnknownKeyDoesNotReachAnyChild() throws {
        let engine = StorageFlowEngine(), child = StorageFlowChild(key)
        let container = StorageSubscriptionContainer(engine: engine, children: [child], logger: Logger.shared)
        try engine.update(changes: [["0xffff", "0x01"]]); XCTAssertTrue(child.values.isEmpty); withExtendedLifetime(container) {}
    }
    func testContainerReleaseCancelsItsSubscriptionAndIgnoresLateDelivery() throws {
        let engine = StorageFlowEngine(), child = StorageFlowChild(key)
        var container: StorageSubscriptionContainer? = StorageSubscriptionContainer(engine: engine, children: [child], logger: Logger.shared)
        weak var weakContainer = container; container = nil; XCTAssertNil(weakContainer); XCTAssertEqual(engine.cancelled, [1])
        try engine.update(changes: [["0x0102", "0x01"]]); XCTAssertTrue(child.values.isEmpty)
    }
    func testFailedSubscriptionDoesNotCancelAnUnissuedIdentifier() {
        let engine = StorageFlowEngine(); engine.failSubscribe = true
        var container: StorageSubscriptionContainer? = StorageSubscriptionContainer(engine: engine, children: [], logger: Logger.shared)
        XCTAssertNotNil(container); container = nil; XCTAssertTrue(engine.cancelled.isEmpty)
    }
    func testStartFactoryInstallsOnlyRuntimeSubscription() throws {
        let engine = StorageFlowEngine(); let factory = WebSocketSubscriptionFactory(storageFacade: SubstrateStorageTestFacade(), runtimeProvider: { nil })
        let subscriptions = try factory.createStartSubscriptions(type: SoraPassport.Chain.sora.addressType(), engine: engine)
        XCTAssertEqual(subscriptions.count, 1); XCTAssertTrue(subscriptions.first is RuntimeVersionSubscription)
        XCTAssertEqual(engine.methods, [SoraPassport.RPCMethod.runtimeVersionSubscribe])
    }
    func testMissingRuntimeThrowsBeforeAnySubscriptionsAreRegistered() throws {
        let f = try StorageFactoryFixture()
        let factory = WebSocketSubscriptionFactory(storageFacade: SubstrateStorageTestFacade(), runtimeProvider: { nil })
        XCTAssertThrowsError(try factory.createSubscriptions(address: f.address, type: SoraPassport.Chain.sora.addressType(), engine: f.engine))
        XCTAssertTrue(f.engine.methods.isEmpty)
    }
    func testRuntimeProviderIsCapturedOnceForTheEntireSubscriptionGraph() throws {
        let f = try StorageFactoryFixture(); var reads = 0
        let factory = WebSocketSubscriptionFactory(storageFacade: SubstrateStorageTestFacade(), runtimeProvider: { reads += 1; return reads == 1 ? f.runtime : nil })
        let subscriptions = try factory.createSubscriptions(address: f.address, type: SoraPassport.Chain.sora.addressType(), engine: f.engine)
        XCTAssertEqual(reads, 1); XCTAssertEqual(subscriptions.count, 3)
    }
    func testFullFactoryBuildsGlobalAccountAndRuntimeSubscriptions() throws {
        let f = try StorageFactoryFixture(); let subscriptions = try f.create()
        XCTAssertEqual(subscriptions.count, 3); XCTAssertTrue(subscriptions[2] is RuntimeVersionSubscription)
        let global = try XCTUnwrap(subscriptions[0] as? StorageSubscriptionContainer)
        let account = try XCTUnwrap(subscriptions[1] as? StorageSubscriptionContainer)
        XCTAssertEqual(global.children.count, 5); XCTAssertEqual(account.children.count, 1)
        XCTAssertEqual(f.engine.methods.filter { $0 == SoraPassport.RPCMethod.storageSubscribe }.count, 2)
    }
    func testGlobalFactoryKeysAreBoundToTheirRuntimeStoragePaths() throws {
        let f = try StorageFactoryFixture(); let subscriptions = try f.create()
        let global = try XCTUnwrap(subscriptions[0] as? StorageSubscriptionContainer); let keys = StorageKeyFactory()
        XCTAssertEqual(Set(global.children.map(\.remoteStorageKey)), Set(try [keys.updatedDualRefCount(), keys.activeEra(), keys.currentEra(), keys.totalIssuance(), keys.newBlock()]))
    }
    func testAccountFactoryUsesTheSelectedAccountAndInjectedServices() throws {
        let f = try StorageFactoryFixture(); let subscriptions = try f.create()
        let container = try XCTUnwrap(subscriptions[1] as? StorageSubscriptionContainer)
        let child = try XCTUnwrap(container.children.first as? AccountInfoSubscription)
        XCTAssertEqual(child.remoteStorageKey, try StorageKeyFactory().accountInfoKeyForId(f.accountId))
        XCTAssertEqual(child.transferSubscription.address, f.address)
        XCTAssertTrue((child.transferSubscription.runtimeService as AnyObject) === f.runtime)
        XCTAssertTrue((child.operationManager as AnyObject) === f.manager); XCTAssertTrue((child.eventCenter as AnyObject) === f.events)
    }
    func testInvalidAccountFailsBeforeRegisteringNetworkListeners() throws {
        let f = try StorageFactoryFixture()
        XCTAssertThrowsError(try f.factory.createSubscriptions(address: "bad", type: SoraPassport.Chain.sora.addressType(), engine: f.engine))
        XCTAssertTrue(f.engine.methods.isEmpty)
    }
    func testAccountInfoChangesWithoutBlockStillAnnounceBalanceRefreshOnMain() async throws {
        let f = try StorageFactoryFixture(); let subscriptions = try f.create()
        let container = try XCTUnwrap(subscriptions[1] as? StorageSubscriptionContainer); let child = try XCTUnwrap(container.children.first as? AccountInfoSubscription)
        let done = expectation(description: "balance change delivered"); f.events.onNotify = { done.fulfill() }
        child.handle(result: .success(.insert(newItem: .init(identifier: "local", data: Data([1])))), blockHash: nil)
        await fulfillment(of: [done], timeout: 2); XCTAssertEqual(f.events.balanceChanges, 1); XCTAssertTrue(f.events.allMain)
    }
    func testFailedAccountInfoChangeDoesNotAnnounceBalanceRefresh() throws {
        let f = try StorageFactoryFixture(); let subscriptions = try f.create()
        let container = try XCTUnwrap(subscriptions[1] as? StorageSubscriptionContainer); let child = try XCTUnwrap(container.children.first as? AccountInfoSubscription)
        child.handle(result: .failure(StorageFlowError.offline), blockHash: nil); child.handle(result: .success(nil), blockHash: nil)
        XCTAssertEqual(f.events.balanceChanges, 0)
    }
}
private enum StorageFlowError: Swift.Error { case offline }
private final class RecordingStorageChild: BaseStorageChildSubscription {
    var kinds = [String](), blocks = [Data?]()
    override func handle(result: Result<DataProviderChange<ChainStorageItem>?, Swift.Error>, blockHash: Data?) {
        blocks.append(blockHash)
        switch result { case .failure: kinds.append("failure")
        case .success(nil): kinds.append("none")
        case .success(.insert?): kinds.append("insert")
        case .success(.update?): kinds.append("update")
        case .success(.delete?): kinds.append("delete") }
    }
}
private final class StorageFlowChild: StorageChildSubscribing {
    let remoteStorageKey: Data; var values = [Data?](), blocks = [Data?]()
    init(_ key: Data) { remoteStorageKey = key }
    func processUpdate(_ data: Data?, blockHash: Data?) { values.append(data); blocks.append(blockHash) }
}
private final class StorageFlowManager: OperationManagerProtocol {
    let manager = OperationManager(); var done: (() -> Void)?
    func enqueue(operations: [Operation], in mode: OperationMode) {
        let completion = done; done = nil; let group = DispatchGroup()
        for operation in operations { group.enter(); let original = operation.completionBlock; operation.completionBlock = { original?(); group.leave() } }
        group.notify(queue: .main) { completion?() }; manager.enqueue(operations: operations, in: mode)
    }
}
private final class StorageFactoryFixture {
    let accountId = Data(repeating: 3, count: 32)
    let engine = StorageFlowEngine(), events = StorageFlowEvents(), runtime = StorageFlowRuntime(), manager = StorageFlowManager()
    let address: String; let factory: WebSocketSubscriptionFactory
    init() throws {
        address = try SS58AddressFactory().addressFromAccountId(data: accountId, type: SoraPassport.Chain.sora.addressType())
        let runtime = runtime
        factory = WebSocketSubscriptionFactory(storageFacade: SubstrateStorageTestFacade(), runtimeProvider: { runtime }, operationManager: manager, eventCenter: events)
    }
    func create() throws -> [WebSocketSubscribing] { try factory.createSubscriptions(address: address, type: SoraPassport.Chain.sora.addressType(), engine: engine) }
}
private final class StorageFlowEvents: EventCenterProtocol {
    var balanceChanges = 0, allMain = true, onNotify: (() -> Void)?
    func notify(with event: EventProtocol) { if event is WalletBalanceChanged { balanceChanges += 1; allMain = allMain && Thread.isMainThread; onNotify?() } }
    func notify(with event: EventProtocol, completionOnMain: @escaping () -> Void) { notify(with: event); completionOnMain() }
    func add(observer: EventVisitorProtocol, dispatchIn: DispatchQueue?) {}; func remove(observer: EventVisitorProtocol) {}
}
private final class StorageFlowRuntime: SoraPassport.RuntimeCodingServiceProtocol {
    func fetchCoderFactoryOperation(with timeout: TimeInterval, closure: SoraPassport.RuntimeMetadataClosure?) -> BaseOperation<RuntimeCoderFactoryProtocol> { ClosureOperation { XCTFail("Unexpected runtime fetch"); throw StorageFlowError.offline } }
}
private final class StorageFlowEngine: JSONRPCEngine {
    var url: URL?; var pendingEngineRequests: [JSONRPCRequest] { [] }
    var methods = [String](), keys = [[String]](), cancelled = [UInt16](), callbacks = [(Data) throws -> Void](), failSubscribe = false
    func callMethod<P: Codable, T: Decodable>(_ method: String, params: P?, options: JSONRPCOptions, completion closure: ((Result<T, Swift.Error>) -> Void)?) throws -> UInt16 { XCTFail("Unexpected RPC call"); throw StorageFlowError.offline }
    func subscribe<P: Codable, T: Decodable>(_ method: String, params: P?, updateClosure: @escaping (T) -> Void, failureClosure: @escaping (Swift.Error, Bool) -> Void) throws -> UInt16 {
        if failSubscribe { throw StorageFlowError.offline }; methods.append(method)
        let data = try JSONEncoder().encode(params)
        if let values = try? JSONDecoder().decode([[String]].self, from: data), let row = values.first { keys.append(row) }
        callbacks.append { updateClosure(try JSONDecoder().decode(T.self, from: $0)) }; return UInt16(callbacks.count)
    }
    func update(changes: [[Any]], block: String = "0x" + String(repeating: "09", count: 32)) throws {
        let body: [String: Any] = ["jsonrpc": "2.0", "method": "state_storage", "params": ["subscription": "1", "result": ["block": block, "changes": changes]]]
        try callbacks.first?(JSONSerialization.data(withJSONObject: body))
    }
    func cancelForIdentifier(_ identifier: UInt16) { cancelled.append(identifier) }; func generateRequestId() -> UInt16 { 1 }; func addSubscription(_ subscription: JSONRPCSubscribing) {}; func connectIfNeeded() {}; func disconnectIfNeeded() {}; func unsubsribe(_ identifier: UInt16) throws {}
}
private final class StorageFlowRepository: DataProviderRepositoryProtocol {
    typealias Model = ChainStorageItem
    let base = InMemoryDataProviderRepository<Model>(); var failWrites = false, failReads = false
    func fetchOperation(by ids: @escaping () throws -> [String], options: RepositoryFetchOptions) -> BaseOperation<[Model]> { base.fetchOperation(by: ids, options: options) }
    func fetchOperation(by id: @escaping () throws -> String, options: RepositoryFetchOptions) -> BaseOperation<Model?> { failReads ? ClosureOperation { throw StorageFlowError.offline } : base.fetchOperation(by: id, options: options) }
    func fetchOperation(by request: RepositorySliceRequest, options: RepositoryFetchOptions) -> BaseOperation<[Model]> { base.fetchOperation(by: request, options: options) }
    func fetchAllOperation(with options: RepositoryFetchOptions) -> BaseOperation<[Model]> { base.fetchAllOperation(with: options) }
    func saveOperation(_ update: @escaping () throws -> [Model], _ delete: @escaping () throws -> [String]) -> BaseOperation<Void> { failWrites ? ClosureOperation { throw StorageFlowError.offline } : base.saveOperation(update, delete) }
    func saveBatchOperation(_ update: @escaping () throws -> [Model], _ delete: @escaping () throws -> [String]) -> BaseOperation<Void> { saveOperation(update, delete) }
    func replaceOperation(_ update: @escaping () throws -> [Model]) -> BaseOperation<Void> { base.replaceOperation(update) }
    func deleteAllOperation() -> BaseOperation<Void> { base.deleteAllOperation() }
    func fetchCountOperation() -> BaseOperation<Int> { base.fetchCountOperation() }
}
