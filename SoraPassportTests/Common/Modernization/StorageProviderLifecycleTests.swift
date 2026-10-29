// SPDX-License-Identifier: Apache-2.0
import BigInt
import Foundation
import SoraFoundation
import IrohaCrypto
import RobinHood
import SSFUtils
import XCTest

@testable import SoraPassport

final class StorageProviderLifecycleTests: XCTestCase {
  private typealias Value = StorageSourceValue
  private var fixtures = [StorageSourceFixture]()
  override func tearDown() { fixtures = []; super.tearDown() }
  private func make(initial: [ChainStorageItem] = [], serialDelivery: Bool = true) async throws -> StorageSourceFixture {
    let f = try StorageSourceFixture(initial: initial, serialDelivery: serialDelivery)
    fixtures.append(f)
    let ready = expectation(description: "storage observer registered")
    f.observable.whenReady { ready.fulfill() }
    await fulfillment(of: [ready], timeout: 3)
    await f.drainDelivery()
    return f
  }
  private func run<T>(_ wrapper: CompoundOperationWrapper<T>) async throws -> T {
    let e = expectation(description: "decode")
    wrapper.targetOperation.completionBlock = { e.fulfill() }
    let queue = OperationQueue()
    wrapper.allOperations.forEach { queue.addOperation($0) }
    await fulfillment(of: [e], timeout: 2)
    return try XCTUnwrap(wrapper.targetOperation.result).get()
  }
  private func equal<T: Equatable>(
    _ a: T, _ b: T, file: StaticString = #filePath, line: UInt = #line
  ) { XCTAssertEqual(a, b, file: file, line: line) }
  private func value(_ f: StorageSourceFixture) async throws -> BigUInt? {
    try await run(f.subject.fetchOperation(by: "target"))?.item.value
  }
  private func emit(_ f: StorageSourceFixture, _ changes: [DataProviderChange<ChainStorageItem>])
    async
  {
    await f.observable.emit(changes)
    await f.drainDelivery()
  }
  private func item(_ value: UInt8, id: String = "target") -> ChainStorageItem {
    ChainStorageItem(identifier: id, data: Data([value] + Array(repeating: 0, count: 15)))
  }
  func testDefaultDeliveryPreservesSerialChangeNotifications() async throws {
    let f = try await make(serialDelivery: false)
    let first = expectation(description: "first change delivering")
    let second = expectation(description: "second change delivered")
    let overlap = expectation(description: "later change must wait for prior delivery")
    overlap.isInverted = true
    let hold = StorageSourceDeliveryHold()
    defer { hold.release(); f.trigger.setCallback(nil) }
    f.trigger.setCallback { count in
      if count == 1 {
        first.fulfill()
        hold.wait()
      } else if count == 2 {
        if hold.isHolding { overlap.fulfill() }
        second.fulfill()
      }
    }
    await f.observable.emit([.insert(newItem: item(17))])
    await fulfillment(of: [first], timeout: 3)
    await f.observable.emit([.update(newItem: item(23))])
    await fulfillment(of: [overlap], timeout: 0.1)
    hold.release()
    await fulfillment(of: [second], timeout: 3)
    equal(try await value(f), 23)
  }
  func testEmptyStorageCacheProducesNoInventedValue() async throws {
    let f = try await make()
    equal(try await value(f), nil)
    equal(f.runtime.calls, 0)
  }
  func testInitialCacheRecordIsDecodedWithThePinnedRuntime() async throws {
    let f = try await make(initial: [item(17)])
    equal(try await value(f), 17)
    equal(f.runtime.calls, 1)
  }
  func testForeignInitialRecordCannotBeRelabeledAsTheRequestedKey() async throws {
    let f = try await make(initial: [item(17, id: "other")])
    equal(try await value(f), nil)
  }
  func testInsertUpdatesTheDecodedValue() async throws {
    let f = try await make()
    await emit(f, [.insert(newItem: item(23))])
    equal(try await value(f), 23)
    equal(f.trigger.count, 1)
  }
  func testUpdateReplacesThePriorDecodedValue() async throws {
    let f = try await make(initial: [item(17)])
    await emit(f, [.update(newItem: item(23))])
    equal(try await value(f), 23)
  }
  func testTargetDeletionClearsTheCachedValue() async throws {
    let f = try await make(initial: [item(17)])
    await emit(f, [.delete(deletedIdentifier: "target")])
    equal(try await value(f), nil)
  }
  func testUnrelatedInsertDoesNotReplaceTheTargetValue() async throws {
    let f = try await make(initial: [item(17)])
    await emit(f, [.insert(newItem: item(23, id: "other"))])
    equal(try await value(f), 17)
  }
  func testUnrelatedUpdateDoesNotReplaceTheTargetValue() async throws {
    let f = try await make(initial: [item(17)])
    await emit(f, [.update(newItem: item(23, id: "other"))])
    equal(try await value(f), 17)
  }
  func testUnrelatedDeletionDoesNotClearTheTargetValue() async throws {
    let f = try await make(initial: [item(17)])
    await emit(f, [.delete(deletedIdentifier: "other")])
    equal(try await value(f), 17)
  }
  func testEmptyChangeBatchDoesNotClearCachedStorage() async throws {
    let f = try await make(initial: [item(17)])
    await emit(f, [])
    equal(try await value(f), 17)
  }
  func testMixedBatchKeepsTheLastChangeForTheRequestedKeyOnly() async throws {
    let f = try await make()
    await emit(
      f,
      [
        .insert(newItem: item(17)), .update(newItem: item(23)),
        .insert(newItem: item(91, id: "other")),
      ])
    equal(try await value(f), 23)
  }
  func testDeleteThenInsertInOneBatchUsesTheReplacement() async throws {
    let f = try await make(initial: [item(17)])
    await emit(f, [.delete(deletedIdentifier: "target"), .insert(newItem: item(23))])
    equal(try await value(f), 23)
  }
  func testInsertThenDeleteInOneBatchHasNoValue() async throws {
    let f = try await make()
    await emit(f, [.insert(newItem: item(17)), .delete(deletedIdentifier: "target")])
    equal(try await value(f), nil)
  }
  func testIdenticalUpdateDoesNotTriggerAnUnnecessaryDecodeRefresh() async throws {
    let f = try await make(initial: [item(17)])
    let count = f.trigger.count
    await emit(f, [.update(newItem: item(17))])
    equal(f.trigger.count, count)
  }
  func testUnrelatedBatchDoesNotTriggerTheTargetProvider() async throws {
    let f = try await make(initial: [item(17)])
    let count = f.trigger.count
    await emit(f, [.update(newItem: item(19, id: "other"))])
    equal(f.trigger.count, count)
  }
  func testFetchingAnotherIdentifierDoesNotDecodeThisRecord() async throws {
    let f = try await make(initial: [item(17)])
    equal(try await run(f.subject.fetchOperation(by: "other")), nil)
    equal(f.runtime.calls, 0)
  }
  func testFirstPageContainsTheSingleBoundIdentifier() async throws {
    let f = try await make(initial: [item(17)])
    let page = try await run(f.subject.fetchOperation(page: 0))
    equal(page.map(\.identifier), ["target"])
    equal(page.first?.item.value, 17)
  }
  func testLaterPagesDoNotRepeatTheSingleStorageRecord() async throws {
    let f = try await make(initial: [item(17)])
    equal(try await run(f.subject.fetchOperation(page: 1)).count, 0)
  }
  func testMalformedStorageFailsInsteadOfReturningAnEmptyValue() async throws {
    let f = try await make(initial: [ChainStorageItem(identifier: "target", data: Data([1]))])
    do {
      _ = try await value(f)
      XCTFail("Malformed storage accepted")
    } catch {}
  }
  func testRuntimeFailureIsNotConvertedToAnEmptyValue() async throws {
    let f = try await make(initial: [item(17)])
    f.runtime.failure = StorageSourceError.offline
    do {
      _ = try await value(f)
      XCTFail("Failed metadata read accepted")
    } catch { XCTAssertTrue(error is StorageSourceError) }
  }
  func testPreparedReadUsesOneConsistentStorageSnapshot() async throws {
    let f = try await make(initial: [item(17)])
    let prepared = f.subject.fetchOperation(by: "target")
    let previousUpdates = f.trigger.count
    await emit(f, [.update(newItem: item(23))])
    XCTAssertGreaterThan(f.trigger.count, previousUpdates)
    equal(try await run(prepared)?.item.value, 17)
    equal(try await value(f), 23)
  }
}
private enum StorageSourceError: Error { case offline }
private final class StorageSourceFixture {
  typealias Value = StorageSourceValue
  let observable = StorageSourceObservable(), trigger = StorageSourceTrigger(),
    repository = InMemoryDataProviderRepository<ChainStorageItem>(), runtime: StorageSourceRuntime
  let deliveryQueue = DispatchQueue(label: "storage-source-fixture.delivery")
  let provider: StreamableProvider<ChainStorageItem>
  var subject: StorageProviderSource<Value>!
  static let coder: Result<RuntimeCoderFactory, Error> = Result {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let snapshot = try RuntimeSnapshotFactory.makeOwnTypesSnapshot(
      chainId: PIIndexerClient.soraMainnetGenesis,
      runtimeMetadataItem: SoraPassport.RuntimeMetadataItem(
        chain: PIIndexerClient.soraMainnetGenesis, version: 133, txVersion: 131,
        metadata: Data(
          contentsOf: root.appendingPathComponent(
            "Fixtures/Modernization/sora2-metadata-spec133.scale")), resolver: nil),
      ownTypes: Data(
        contentsOf: root.appendingPathComponent("SoraPassport/Resources/runtime-sora.json")),
      dataHasher: .twox256)
    return RuntimeCoderFactory(
      catalog: snapshot.typeRegistryCatalog, specVersion: 133, txVersion: 131,
      metadata: snapshot.metadata)
  }
  init(initial: [ChainStorageItem], serialDelivery: Bool) throws {
    runtime = StorageSourceRuntime(coder: try Self.coder.get())
    let save = repository.saveOperation({ initial }, { [] })
    save.start()
    try XCTUnwrap(save.result).get()
    provider = StreamableProvider(
      source: AnyStreamableSource(StorageSourceRemote()),
      repository: AnyDataProviderRepository(repository),
      observable: AnyDataProviderRepositoryObservable(observable),
      operationManager: OperationManager())
    if serialDelivery {
      subject = StorageProviderSource(
        itemIdentifier: "target", codingPath: .totalIssuance, runtimeService: runtime,
        provider: provider, trigger: trigger, observerQueue: deliveryQueue)
    } else {
      subject = StorageProviderSource(
        itemIdentifier: "target", codingPath: .totalIssuance, runtimeService: runtime,
        provider: provider, trigger: trigger)
    }
  }
  func drainDelivery() async {
    await withCheckedContinuation { continuation in
      deliveryQueue.async { continuation.resume() }
    }
  }
}
private final class StorageSourceRuntime: SoraPassport.RuntimeCodingServiceProtocol {
  let coder: RuntimeCoderFactoryProtocol
  var failure: Error?
  private let lock = NSLock()
  private var count = 0
  var calls: Int {
    lock.lock()
    defer { lock.unlock() }
    return count
  }
  init(coder: RuntimeCoderFactoryProtocol) { self.coder = coder }
  func fetchCoderFactoryOperation(
    with timeout: TimeInterval, closure: SoraPassport.RuntimeMetadataClosure?
  ) -> BaseOperation<RuntimeCoderFactoryProtocol> {
    lock.lock()
    count += 1
    lock.unlock()
    return ClosureOperation {
      if let failure = self.failure { throw failure }
      return self.coder
    }
  }
}
private final class StorageSourceTrigger: DataProviderTriggerProtocol, DataProviderTriggerDelegate {
  weak var delegate: DataProviderTriggerDelegate?
  private let lock = NSLock()
  private var updates = 0
  private var callback: ((Int) -> Void)?
  func setCallback(_ value: ((Int) -> Void)?) {
    lock.lock(); callback = value; lock.unlock()
  }
  var count: Int {
    lock.lock()
    defer { lock.unlock() }
    return updates
  }
  init() { delegate = self }
  func receive(event: DataProviderEvent) {}
  func didTrigger() {
    lock.lock()
    updates += 1
    let count = updates, callback = callback
    lock.unlock()
    callback?(count)
  }
}
private final class StorageSourceRemote: StreamableSourceProtocol {
  typealias Model = ChainStorageItem
  func fetchHistory(
    runningIn queue: DispatchQueue?, commitNotificationBlock: ((Result<Int, Error>?) -> Void)?
  ) { XCTFail("No remote reads expected") }
  func refresh(
    runningIn queue: DispatchQueue?, commitNotificationBlock: ((Result<Int, Error>?) -> Void)?
  ) { XCTFail("No remote reads expected") }
}
private final class StorageSourceObservable: DataProviderRepositoryObservable {
  typealias Model = ChainStorageItem
  private let lock = NSLock()
  private var callback: (([DataProviderChange<ChainStorageItem>]) -> Void)?, queue: DispatchQueue?
  private var readyCallback: (() -> Void)?
  func whenReady(_ completion: @escaping () -> Void) {
    lock.lock()
    if callback != nil { lock.unlock(); completion(); return }
    readyCallback = completion
    lock.unlock()
  }
  func start(completionBlock: @escaping (Error?) -> Void) { completionBlock(nil) }
  func stop(completionBlock: @escaping (Error?) -> Void) { completionBlock(nil) }
  func addObserver(
    _ observer: AnyObject, deliverOn queue: DispatchQueue,
    executing updateBlock: @escaping ([DataProviderChange<ChainStorageItem>]) -> Void
  ) {
    lock.lock()
    self.queue = queue
    callback = updateBlock
    let readyCallback = readyCallback
    self.readyCallback = nil
    lock.unlock()
    readyCallback?()
  }
  func removeObserver(_ observer: AnyObject) {
    lock.lock()
    callback = nil
    queue = nil
    lock.unlock()
  }
  func emit(_ changes: [DataProviderChange<ChainStorageItem>]) async {
    await withCheckedContinuation { continuation in
      lock.lock()
      let callback = callback
      let queue = queue
      lock.unlock()
      guard let queue else { continuation.resume(); return }
      queue.async { callback?(changes); continuation.resume() }
    }
  }
}

private struct StorageSourceValue: Decodable, Equatable {
  let value: BigUInt
  init(from decoder: Decoder) throws {
    let text = try decoder.singleValueContainer().decode(String.self)
    guard let value = BigUInt(text) else { throw StorageSourceError.offline }
    self.value = value
  }
}

private final class StorageSourceDeliveryHold: @unchecked Sendable {
  private let lock = NSLock(), semaphore = DispatchSemaphore(value: 0)
  private var holding = true
  var isHolding: Bool { lock.lock(); defer { lock.unlock() }; return holding }
  func wait() { _ = semaphore.wait(timeout: .now() + 3) }
  func release() {
    lock.lock(); let shouldSignal = holding; holding = false; lock.unlock()
    if shouldSignal { semaphore.signal() }
  }
}

/// Real in-memory Core Data stores exercise filtering and provider reuse without network access.
final class StorageFactoryBoundaryTests: XCTestCase {
    private func run<T>(_ operation: BaseOperation<T>) async throws -> T {
        let completed = expectation(description: "repository operation")
        operation.completionBlock = { completed.fulfill() }
        let queue = OperationQueue(); queue.addOperation(operation)
        await fulfillment(of: [completed], timeout: 3)
        return try XCTUnwrap(operation.result).get()
    }
    private func fetch<T>(_ provider: StreamableProvider<T>) async throws -> [T] {
        let completed = expectation(description: "provider read")
        var result: Result<[T], Error>?
        _ = provider.fetch(offset: 0, count: 100, synchronized: true) { result = $0; completed.fulfill() }
        await fulfillment(of: [completed], timeout: 3)
        return try XCTUnwrap(result).get()
    }
    func testStorageProviderReturnsOnlyItsExactKey() async throws {
        let facade = SubstrateStorageTestFacade()
        let repository: CoreDataRepository<ChainStorageItem, CDChainStorageItem> = facade.createRepository()
        _ = try await run(repository.saveOperation({ [ChainStorageItem(identifier: "wanted", data: Data([7])), ChainStorageItem(identifier: "other", data: Data([9]))] }, { [] }))
        let factory = SubstrateDataProviderFactory(facade: facade, operationManager: OperationManager())
        let values = try await fetch(factory.createStorageProvider(for: "wanted"))
        XCTAssertEqual(values.map(\.identifier), ["wanted"]); XCTAssertEqual(values.first?.data, Data([7]))
        let absent = try await fetch(factory.createStorageProvider(for: "missing")); XCTAssertTrue(absent.isEmpty)
    }
    func testRuntimeMetadataProviderCannotReturnAnotherChainsSnapshot() async throws {
        let facade = SubstrateStorageTestFacade()
        let repository: CoreDataRepository<SoraPassport.RuntimeMetadataItem, CDRuntimeMetadataItem> = facade.createRepository()
        let expected = SoraPassport.RuntimeMetadataItem(chain: Chain.sora.genesisHash(), version: 133, txVersion: 131, metadata: Data([1,2,3]), resolver: nil)
        let other = SoraPassport.RuntimeMetadataItem(chain: "another-chain", version: 9, txVersion: 7, metadata: Data([9]), resolver: nil)
        _ = try await run(repository.saveOperation({ [expected, other] }, { [] }))
        let factory = SubstrateDataProviderFactory(facade: facade, operationManager: OperationManager())
        let values = try await fetch(factory.createRuntimeMetadataItemProvider(for: .sora))
        XCTAssertEqual(values.map(\.chain), [expected.chain]); XCTAssertEqual(values.first?.version, 133); XCTAssertEqual(values.first?.metadata, expected.metadata)
    }
    func testAccountProviderReusesTheSameAddressWithoutMixingOtherAccounts() throws {
        let factory = SingleValueProviderFactory(facade: SubstrateStorageTestFacade(), operationManager: OperationManager(), logger: Logger.shared)
        let runtime = StorageSourceRuntime(coder: try StorageSourceFixture.coder.get())
        let addresses = SS58AddressFactory()
        let first = try addresses.addressFromAccountId(data: Data(repeating: 3, count: 32), type: 69)
        let second = try addresses.addressFromAccountId(data: Data(repeating: 4, count: 32), type: 69)
        let one = try factory.getAccountProvider(for: first, runtimeService: runtime)
        let reused = try factory.getAccountProvider(for: first, runtimeService: runtime)
        let two = try factory.getAccountProvider(for: second, runtimeService: runtime)
        XCTAssertTrue(one === reused); XCTAssertFalse(one === two); XCTAssertEqual(runtime.calls, 0)
    }
    func testInvalidAccountAddressIsRejectedBeforeRuntimeLookup() throws {
        let factory = SingleValueProviderFactory(facade: SubstrateStorageTestFacade(), operationManager: OperationManager(), logger: Logger.shared)
        let runtime = StorageSourceRuntime(coder: try StorageSourceFixture.coder.get())
        for value in ["", "invalid", "0x1234", "  wallet  "] { XCTAssertThrowsError(try factory.getAccountProvider(for: value, runtimeService: runtime)) }
        XCTAssertEqual(runtime.calls, 0)
    }
    func testFactoryDoesNotOwnAnUnusedAccountProviderForever() async throws {
        let factory = SingleValueProviderFactory(facade: SubstrateStorageTestFacade(), operationManager: OperationManager(), logger: Logger.shared)
        let runtime = StorageSourceRuntime(coder: try StorageSourceFixture.coder.get())
        let address = try SS58AddressFactory().addressFromAccountId(data: Data(repeating: 3, count: 32), type: 69)
        var provider: DataProvider<DecodedAccountInfo>? = try factory.getAccountProvider(for: address, runtimeService: runtime)
        weak var old = provider; provider = nil
        for _ in 0..<100 { if old == nil { break }; try? await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertNil(old)
        let replacement = try factory.getAccountProvider(for: address, runtimeService: runtime)
        XCTAssertTrue(replacement === (try factory.getAccountProvider(for: address, runtimeService: runtime)))
    }
}

final class RuntimeHotBootBoundaryTests: XCTestCase {
    private func chain(_ id: String) -> SoraPassport.ChainModel {
        SoraPassport.ChainModel(chainId: id, name: id, nodes: [], addressPrefix: 69, types: nil, icon: nil, iosMinAppVersion: nil)
    }
    private func metadata(_ id: String, version: UInt32 = 133) -> SoraPassport.RuntimeMetadataItem {
        SoraPassport.RuntimeMetadataItem(chain: id, version: version, txVersion: 131, metadata: Data([1,2,3]), resolver: nil)
    }
    private func boot(chains: [SoraPassport.ChainModel], metadata: [SoraPassport.RuntimeMetadataItem], common: Data? = Data([4,5]), failure: Bool = false) async throws -> HotBootPoolRecorder {
        let chainsRepository = InMemoryDataProviderRepository<SoraPassport.ChainModel>()
        let runtimeRepository = InMemoryDataProviderRepository<SoraPassport.RuntimeMetadataItem>()
        let saves = [chainsRepository.saveOperation({ chains }, { [] }), runtimeRepository.saveOperation({ metadata }, { [] })]
        saves.forEach { $0.start() }; for save in saves { try XCTUnwrap(save.result).get() }
        let queue = OperationQueue(), pool = HotBootPoolRecorder(), files = HotBootFiles(common: common, failure: failure)
        let builder = SnapshotHotBootBuilder(runtimeProviderPool: pool, chainRepository: AnyDataProviderRepository(chainsRepository), filesOperationFactory: files, runtimeItemRepository: AnyDataProviderRepository(runtimeRepository), operationQueue: queue, logger: Logger.shared)
        let expectedRecords = common == nil || failure ? 0 : chains.filter { chain in metadata.contains { $0.chain == chain.chainId } }.count
        var waits = [XCTestExpectation]()
        if expectedRecords > 0 {
            let recorded = expectation(description: "hot runtimes published")
            recorded.expectedFulfillmentCount = expectedRecords
            pool.onRecord = { recorded.fulfill() }
            waits.append(recorded)
        }
        builder.startHotBoot()
        let completed = expectation(description: "hot boot operations completed")
        queue.addBarrierBlock { completed.fulfill() }
        waits.append(completed)
        await fulfillment(of: waits, timeout: 5)
        withExtendedLifetime(builder) {}
        return pool
    }
    func testCachedRuntimeAndCommonTypesAreBoundToTheirMatchingChain() async throws {
        let pool = try await boot(chains: [chain("one"), chain("two")], metadata: [metadata("two", version: 17), metadata("one")])
        XCTAssertEqual(Set(pool.records.map { $0.0 }), ["one", "two"])
        XCTAssertTrue(pool.records.allSatisfy { $0.0 == $0.1.chain && $0.2 == Data([4,5]) })
        XCTAssertEqual(pool.records.first { $0.0 == "two" }?.1.version, 17)
    }
    func testMissingRuntimeLeavesOnlyThatChainForNormalStartup() async throws {
        let pool = try await boot(chains: [chain("one"), chain("two")], metadata: [metadata("two"), metadata("unconfigured")])
        XCTAssertEqual(pool.records.map { $0.0 }, ["two"])
    }
    func testMissingCommonTypesCannotPublishAPartialHotSnapshot() async throws {
        let pool = try await boot(chains: [chain("one")], metadata: [metadata("one")], common: nil)
        XCTAssertTrue(pool.records.isEmpty)
    }
    func testFailedCommonTypesReadCannotPublishACachedRuntime() async throws {
        let pool = try await boot(chains: [chain("one")], metadata: [metadata("one")], failure: true)
        XCTAssertTrue(pool.records.isEmpty)
    }
    func testUnconfiguredRuntimeCacheDoesNotCreateInventedChains() async throws {
        let pool = try await boot(chains: [], metadata: [metadata("one")])
        XCTAssertTrue(pool.records.isEmpty)
    }
}
private final class HotBootFiles: RuntimeFilesOperationFactoryProtocol {
    let common: Data?; let failure: Bool
    init(common: Data?, failure: Bool) { self.common = common; self.failure = failure }
    func fetchCommonTypesOperation() -> CompoundOperationWrapper<Data?> {
        CompoundOperationWrapper(targetOperation: ClosureOperation { if self.failure { throw StorageSourceError.offline }; return self.common })
    }
    func fetchChainTypesOperation(for chainId: String) -> CompoundOperationWrapper<Data?> { XCTFail("Unexpected chain read"); return CompoundOperationWrapper(targetOperation: ClosureOperation { nil }) }
    func saveCommonTypesOperation(data closure: @escaping () throws -> Data) -> CompoundOperationWrapper<Void> { XCTFail("Hot boot must not write files"); return CompoundOperationWrapper(targetOperation: ClosureOperation {}) }
    func saveChainTypesOperation(for chainId: String, data closure: @escaping () throws -> Data) -> CompoundOperationWrapper<Void> { XCTFail("Hot boot must not write files"); return CompoundOperationWrapper(targetOperation: ClosureOperation {}) }
}
private final class HotBootPoolRecorder: RuntimeProviderPoolProtocol {
    var onRecord: (() -> Void)?
    var records: [(String, SoraPassport.RuntimeMetadataItem, Data)] = []
    func setupRuntimeProvider(for chain: SoraPassport.ChainModel) -> RuntimeProviderProtocol { XCTFail("Unexpected cold startup"); return HotBootRuntime(chainId: chain.chainId) }
    func setupHotRuntimeProvider(for chain: SoraPassport.ChainModel, runtimeItem: SoraPassport.RuntimeMetadataItem, commonTypes: Data) -> RuntimeProviderProtocol {
        records.append((chain.chainId, runtimeItem, commonTypes)); onRecord?(); return HotBootRuntime(chainId: chain.chainId)
    }
    func destroyRuntimeProvider(for chainId: String) { XCTFail("Unexpected destruction") }
    func getRuntimeProvider(for chainId: String) -> RuntimeProviderProtocol? { nil }
}
private final class HotBootRuntime: RuntimeProviderProtocol {
    let chainId: String; var snapshot: RuntimeSnapshot? { nil }
    init(chainId: String) { self.chainId = chainId }
    func setup() {}; func setupHot() {}; func replaceTypesUsage(_ usage: SoraPassport.ChainModel.TypesUsage) {}; func cleanup() {}
    func fetchCoderFactoryOperation(with timeout: TimeInterval, closure: SoraPassport.RuntimeMetadataClosure?) -> BaseOperation<RuntimeCoderFactoryProtocol> { ClosureOperation { throw StorageSourceError.offline } }
}

final class PhishingServiceLifecycleTests: XCTestCase {
    private func run<T>(_ op: BaseOperation<T>) async throws -> T {
        let done = expectation(description: "phishing storage operation"); op.completionBlock = { done.fulfill() }
        let queue = OperationQueue(); queue.addOperation(op); await fulfillment(of: [done], timeout: 3)
        return try XCTUnwrap(op.result).get()
    }
    private func repository() -> CoreDataRepository<PhishingItem, CDPhishingItem> { SubstrateStorageTestFacade().createRepository() }
    private func values(_ repository: CoreDataRepository<PhishingItem, CDPhishingItem>) async throws -> [String] {
        try await run(repository.fetchAllOperation(with: RepositoryFetchOptions())).map(\.publicKey).sorted()
    }
    private func waitFor(_ expected: [String], in repository: CoreDataRepository<PhishingItem, CDPhishingItem>) async throws {
        for _ in 0..<80 { if try await values(repository) == expected { return }; try? await Task.sleep(nanoseconds: 10_000_000) }
        let actual = try await values(repository); XCTAssertEqual(actual, expected)
    }
    func testSuccessfulRefreshReplacesTheOldBlacklistWithExactlyTheFetchedKeys() async throws {
        let store = repository(); _ = try await run(store.saveOperation({ [PhishingItem(source: "old", publicKey: "old-key")] }, { [] }))
        let op = ClosureOperation { [PhishingItem(source: "fixture", publicKey: "bad-a"), PhishingItem(source: "fixture", publicKey: "bad-b")] }
        let service = GitHubPhishingAPIService(operation: op, logger: Logger.shared, storage: store)
        XCTAssertTrue(service.isThrottled); service.setup(); XCTAssertFalse(service.isThrottled)
        try await waitFor(["bad-a", "bad-b"], in: store)
        let rows = try await run(store.fetchAllOperation(with: RepositoryFetchOptions())); XCTAssertTrue(rows.allSatisfy { $0.source == "fixture" })
        service.throttle(); XCTAssertTrue(service.isThrottled)
    }
    func testAnAuthoritativeEmptyBlacklistClearsOldEntries() async throws {
        let store = repository(); _ = try await run(store.saveOperation({ [PhishingItem(source: "old", publicKey: "old-key")] }, { [] }))
        let service = GitHubPhishingAPIService(operation: ClosureOperation { [] }, logger: Logger.shared, storage: store)
        service.setup(); try await waitFor([], in: store); service.throttle()
    }
    func testFailedRefreshPreservesPreviouslyKnownPhishingKeys() async throws {
        let store = repository(); _ = try await run(store.saveOperation({ [PhishingItem(source: "old", publicKey: "old-key")] }, { [] }))
        let attempted = expectation(description: "read failed")
        let op = ClosureOperation<[PhishingItem]> { attempted.fulfill(); throw StorageSourceError.offline }
        let service = GitHubPhishingAPIService(operation: op, logger: Logger.shared, storage: store)
        service.setup(); await fulfillment(of: [attempted], timeout: 3)
        try? await Task.sleep(nanoseconds: 30_000_000)
        let keys = try await values(store); XCTAssertEqual(keys, ["old-key"]); service.throttle()
    }
    func testRepeatedSetupDoesNotRunASecondRequest() async throws {
        let store = repository(), attempted = expectation(description: "request ran")
        var requests = 0
        let op = ClosureOperation<[PhishingItem]> { requests += 1; attempted.fulfill(); return [] }
        let service = GitHubPhishingAPIService(operation: op, logger: Logger.shared, storage: store)
        service.setup(); service.setup(); await fulfillment(of: [attempted], timeout: 3)
        XCTAssertEqual(requests, 1); service.throttle(); service.throttle(); XCTAssertTrue(service.isThrottled)
    }
    func testThrottleCancelsAQueuedRequestWithoutClearingExistingProtection() async throws {
        let store = repository(); _ = try await run(store.saveOperation({ [PhishingItem(source: "old", publicKey: "old-key")] }, { [] }))
        let dependency = BlockOperation {}, op = ClosureOperation<[PhishingItem]> { XCTFail("Cancelled request ran"); return [] }
        op.addDependency(dependency)
        let service = GitHubPhishingAPIService(operation: op, logger: Logger.shared, storage: store)
        service.setup(); service.throttle(); dependency.start()
        XCTAssertTrue(op.isCancelled); XCTAssertTrue(service.isThrottled)
        try? await Task.sleep(nanoseconds: 30_000_000)
        let keys = try await values(store); XCTAssertEqual(keys, ["old-key"])
    }
}

final class AssetManagerOrderingBoundaryTests: XCTestCase {
    private let xor = WalletAssetId.xor.rawValue, val = WalletAssetId.val.rawValue
    private func asset(_ id: String, symbol: String, visible: Bool = true) -> AssetInfo {
        AssetInfo(id: id, symbol: symbol, chainId: "", precision: 18, icon: nil, displayName: symbol, visible: visible)
    }
    private func wallet(_ id: String, symbol: String) -> WalletAsset {
        WalletAsset(identifier: id, name: LocalizableResource { _ in symbol }, symbol: symbol, precision: 18)
    }
    private func manager() -> AssetManager {
        let storage = SubstrateStorageTestFacade(), queue = OperationQueue()
        let repository = ChainRepositoryFactory(storageFacade: storage).createRepository()
        let observable = CoreDataContextObservable(service: storage.databaseService, mapper: repository.dataMapper, predicate: { _ in true })
        observable.start { XCTAssertNil($0) }
        let provider = StreamableProvider(source: AnyStreamableSource(SoraPassport.EmptyStreamableSource<ChainModel>()),
            repository: AnyDataProviderRepository(repository), observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: OperationManager(operationQueue: queue))
        let assets: CoreDataRepository<AssetInfo, CDAssetInfo> = storage.createRepository()
        let result = AssetManager(storage: AnyDataProviderRepository(assets), chainProvider: provider, chainId: "public-chain",
            operationManager: OperationManager(operationQueue: queue), eventCenter: EventCenter())
        result.setup(for: SelectedWalletSettings(storageFacade: UserDataStorageTestFacade(), operationQueue: queue))
        return result
    }
    func testUnknownAssetLookupDoesNotFabricateMetadata() {
        let m = manager(); XCTAssertNil(m.assetInfo(for: "unknown")); XCTAssertEqual(m.visibleCount(), 1)
        m.saveAssetList([asset(xor, symbol: "XOR")]); XCTAssertEqual(m.assetInfo(for: xor)?.symbol, "XOR"); XCTAssertNil(m.assetInfo(for: val))
    }
    func testSavedOrderIsUsedInsteadOfAlphabeticSymbolOrder() {
        let m = manager(); m.saveAssetList([asset(xor, symbol: "XOR"), asset(val, symbol: "VAL")])
        let values = [wallet(val, symbol: "VAL"), wallet(xor, symbol: "XOR")]
        XCTAssertEqual(m.sortedAssets(values, onlyVisible: false).map(\.identifier), [xor, val]); XCTAssertEqual(m.visibleCount(), 2)
    }
    func testUnorderedAssetsUseStableAlphabeticalFallback() {
        let m = manager(); let values = [wallet("z", symbol: "ZZZ"), wallet("a", symbol: "AAA")]
        XCTAssertEqual(m.sortedAssets(values).map(\.identifier), ["a", "z"])
    }
    func testHiddenTokensAreFilteredButTheFeeAssetAlwaysRemainsAvailable() {
        let m = manager(); m.saveAssetList([asset(xor, symbol: "XOR", visible: false), asset(val, symbol: "VAL", visible: false)])
        XCTAssertEqual(m.sortedAssets([wallet(xor, symbol: "XOR"), wallet(val, symbol: "VAL")], onlyVisible: true).map(\.identifier), [xor])
        XCTAssertEqual(m.visibleCount(), 1)
    }
    func testVisibleFeeBalanceAddsTheCapitalReloadMarker() {
        let m = manager(); m.saveAssetList([asset(xor, symbol: "XOR"), asset(val, symbol: "VAL")])
        let ordered = m.sortedAssets([wallet(val, symbol: "VAL"), wallet(xor, symbol: "XOR")], onlyVisible: true)
        XCTAssertEqual(ordered.map(\.identifier), [xor, val, WalletAsset.dummyAsset.identifier])
    }
    func testTokensMissingMetadataRemainVisibleRatherThanDisappearing() {
        let m = manager(); XCTAssertEqual(m.sortedAssets([wallet("unknown", symbol: "NEW")], onlyVisible: true).map(\.identifier), ["unknown"])
    }
    func testDefaultAssetArrangementPrioritizesBuiltInsAndHidesUnselectedCustomTokens() {
        let values = [asset("custom-z", symbol: "ZZZ"), asset(val, symbol: "VAL"), asset("custom-a", symbol: "AAA"), asset(xor, symbol: "XOR")]
        let arranged = AssetManager.arrangedAssets(values, settings: nil)
        XCTAssertEqual(arranged.map(\.identifier), [xor, val, "custom-a", "custom-z"])
        XCTAssertEqual(arranged.map(\.visible), [true, true, false, false])
    }
    func testSavingAReorderedListKeepsTheUnavailableTokensSavedPositionOnlyOnce() {
        let previous = AccountSettings(visibleAssetIds: ["missing", xor, "missing"], orderedAssetIds: ["missing", "missing", xor, val])
        let selection = AssetManager.savedSelection(for: [asset(val, symbol: "VAL"), asset(xor, symbol: "XOR", visible: false)], keeping: previous)
        XCTAssertEqual(selection.ordered, ["missing", val, xor]); XCTAssertEqual(selection.visible, [val, "missing"])
    }
}

final class CommonTypesRetryLifecycleTests: XCTestCase {
    private let bytes = Data("{\"types\":{\"Balance\":\"u128\"}}".utf8)
    private struct Fixture {
        let service: CommonTypesSyncService, files: TypesRetryFiles, fetch: TypesRetryFetch,
            events: TypesRetryEvents, retry: TypesRetryStrategy, queue: OperationQueue
    }
    private func make(_ results: [Result<Data, Error>], delay: TimeInterval? = nil, reviewed: Bool = false) -> Fixture {
        let files = TypesRetryFiles(), fetch = TypesRetryFetch(results), events = TypesRetryEvents(), retry = TypesRetryStrategy(delay), queue = OperationQueue()
        let service = CommonTypesSyncService(url: URL(string: "https://fixture.invalid/types.json"), filesOperationFactory: files,
            dataOperationFactory: fetch, eventCenter: events, operationQueue: queue, retryStrategy: retry, usesReviewedSoraBundle: reviewed)
        return Fixture(service: service, files: files, fetch: fetch, events: events, retry: retry, queue: queue)
    }
    private func waitFor(_ description: String, _ condition: @escaping () -> Bool) async {
        for _ in 0..<200 { if condition() { return }; try? await Task.sleep(nanoseconds: 5_000_000) }
        XCTAssertTrue(condition(), description)
    }
    func testSuccessfulRemoteTypesAreSavedBeforeTheirHashIsPublished() async throws {
        let f = make([.success(bytes)]); f.service.syncUp()
        await waitFor("hash published") { f.events.hashes.count == 1 }
        XCTAssertEqual(f.files.saved, [bytes]); XCTAssertEqual(f.events.hashes, [try StorageHasher.twox256.hash(data: bytes).toHex()])
        XCTAssertEqual(f.fetch.urls.map(\.absoluteString), ["https://fixture.invalid/types.json"])
        XCTAssertEqual(f.service.retryAttempt, 0); XCTAssertFalse(f.service.isSyncing)
    }
    func testDuplicateSyncDuringAQueuedPassDoesNotEnqueueAnotherFetch() async {
        let f = make([.success(bytes)]); f.queue.isSuspended = true
        f.service.syncUp(); f.service.syncUp(); XCTAssertTrue(f.service.isSyncing); XCTAssertEqual(f.fetch.urls.count, 1)
        f.queue.isSuspended = false; await waitFor("one completed pass") { f.events.hashes.count == 1 }
        XCTAssertEqual(f.files.saved.count, 1)
    }
    func testFetchFailureDoesNotSaveOrPublishAndRequestsFirstRetry() async {
        let f = make([.failure(TypesRetryFailure.offline)]); f.service.syncUp()
        await waitFor("retry requested") { f.retry.attempts.count == 1 }
        XCTAssertEqual(f.retry.attempts, [1]); XCTAssertTrue(f.files.saved.isEmpty); XCTAssertTrue(f.events.hashes.isEmpty)
        XCTAssertFalse(f.service.isSyncing); XCTAssertEqual(f.service.retryAttempt, 1)
    }
    func testSaveFailureDoesNotPublishAHashForUnpersistedTypes() async {
        let f = make([.success(bytes)]); f.files.failSave = true; f.service.syncUp()
        await waitFor("save failure retry") { f.retry.attempts.count == 1 }
        XCTAssertTrue(f.events.hashes.isEmpty); XCTAssertTrue(f.files.saved.isEmpty); XCTAssertEqual(f.service.retryAttempt, 1)
    }
    func testManualRetryCancelsTheScheduledBackoffAndResetsAttemptsOnSuccess() async {
        let f = make([.failure(TypesRetryFailure.offline), .success(bytes)], delay: 3600); f.service.syncUp()
        await waitFor("scheduled retry") { f.retry.attempts.count == 1 }
        f.service.syncUp(); await waitFor("manual recovery") { f.events.hashes.count == 1 }
        XCTAssertEqual(f.fetch.urls.count, 2); XCTAssertEqual(f.service.retryAttempt, 0); XCTAssertEqual(f.files.saved, [bytes])
    }
    func testScheduledRetryPerformsAnotherFetchAndPublishesOnlySuccess() async {
        let f = make([.failure(TypesRetryFailure.offline), .success(bytes)], delay: 0.02); f.service.syncUp()
        await waitFor("scheduled recovery") { f.events.hashes.count == 1 }
        XCTAssertEqual(f.fetch.urls.count, 2); XCTAssertEqual(f.retry.attempts, [1]); XCTAssertEqual(f.service.retryAttempt, 0)
    }
    func testRepeatedFailuresIncrementRetryAttemptWithoutPublishing() async {
        let f = make([.failure(TypesRetryFailure.offline), .failure(TypesRetryFailure.offline)]); f.service.syncUp()
        await waitFor("first retry") { f.retry.attempts.count == 1 }; f.service.syncUp()
        await waitFor("second retry") { f.retry.attempts.count == 2 }
        XCTAssertEqual(f.retry.attempts, [1, 2]); XCTAssertEqual(f.service.retryAttempt, 2); XCTAssertTrue(f.events.hashes.isEmpty)
    }
    func testReviewedBundleBypassesRemoteFetchAndPublishesItsValidatedHash() async throws {
        let f = make([], reviewed: true); f.service.syncUp()
        await waitFor("reviewed bundle saved") { f.events.hashes.count == 1 }
        let reviewed = try ReviewedSoraRuntimeSnapshotAdmission.loadReviewedCommonTypes()
        XCTAssertEqual(f.files.saved, [reviewed]); XCTAssertTrue(f.fetch.urls.isEmpty)
        XCTAssertEqual(f.events.hashes, [try StorageHasher.twox256.hash(data: reviewed).toHex()])
    }
}
private enum TypesRetryFailure: Error { case offline }
private final class TypesRetryFetch: DataOperationFactoryProtocol {
    private let lock = NSLock(); private var results: [Result<Data, Error>], storedURLs: [URL] = []
    var urls: [URL] { lock.lock(); defer { lock.unlock() }; return storedURLs }
    init(_ results: [Result<Data, Error>]) { self.results = results }
    func fetchData(from url: URL) -> BaseOperation<Data> {
        lock.lock(); storedURLs.append(url); let result = results.isEmpty ? .failure(TypesRetryFailure.offline) : results.removeFirst(); lock.unlock()
        return ClosureOperation { try result.get() }
    }
}
private final class TypesRetryFiles: RuntimeFilesOperationFactoryProtocol {
    private let lock = NSLock(); private var values: [Data] = []
    var failSave = false
    var saved: [Data] { lock.lock(); defer { lock.unlock() }; return values }
    func saveCommonTypesOperation(data closure: @escaping () throws -> Data) -> CompoundOperationWrapper<Void> {
        CompoundOperationWrapper(targetOperation: ClosureOperation {
            let data = try closure(); if self.failSave { throw TypesRetryFailure.offline }
            self.lock.lock(); self.values.append(data); self.lock.unlock()
        })
    }
    func fetchCommonTypesOperation() -> CompoundOperationWrapper<Data?> { XCTFail("Unexpected cache read"); return CompoundOperationWrapper(targetOperation: ClosureOperation { nil }) }
    func fetchChainTypesOperation(for chainId: String) -> CompoundOperationWrapper<Data?> { XCTFail("Unexpected chain read"); return CompoundOperationWrapper(targetOperation: ClosureOperation { nil }) }
    func saveChainTypesOperation(for chainId: String, data closure: @escaping () throws -> Data) -> CompoundOperationWrapper<Void> { XCTFail("Unexpected chain write"); return CompoundOperationWrapper(targetOperation: ClosureOperation {}) }
}
private final class TypesRetryStrategy: SoraPassport.ReconnectionStrategyProtocol {
    private let lock = NSLock(); private var values: [Int] = []; let delay: TimeInterval?
    var attempts: [Int] { lock.lock(); defer { lock.unlock() }; return values }
    init(_ delay: TimeInterval?) { self.delay = delay }
    func reconnectAfter(attempt: Int) -> TimeInterval? { lock.lock(); defer { lock.unlock() }; values.append(attempt); return delay }
}
private final class TypesRetryEvents: EventCenterProtocol {
    private let lock = NSLock(); private var values: [String] = []
    var hashes: [String] { lock.lock(); defer { lock.unlock() }; return values }
    func notify(with event: EventProtocol) { if let event = event as? RuntimeCommonTypesSyncCompleted { lock.lock(); values.append(event.fileHash); lock.unlock() } }
    func notify(with event: EventProtocol, completionOnMain: @escaping () -> Void) { notify(with: event); DispatchQueue.main.async(execute: completionOnMain) }
    func add(observer: EventVisitorProtocol, dispatchIn queue: DispatchQueue?) {}
    func remove(observer: EventVisitorProtocol) {}
}
