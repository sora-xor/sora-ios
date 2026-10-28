// SPDX-License-Identifier: Apache-2.0
import BigInt
import Foundation
import IrohaCrypto
import RobinHood
import SSFUtils
import XCTest
@testable import SoraPassport

@MainActor
final class TransactionSubscriptionFlowTests: XCTestCase {
    private func equal<T: Equatable>(_ a: T, _ b: T, file: StaticString = #filePath, line: UInt = #line) { XCTAssertEqual(a, b, file: file, line: line) }
    private func rows(_ f: SubscriptionFixture) throws -> [TransactionHistoryItem] { let op = f.rows.fetchAllOperation(with: .init()); op.start(); return try XCTUnwrap(op.result).get() }
    private func process(_ f: SubscriptionFixture) async {
        let done = expectation(description: "subscription graph completes")
        f.operations.onCompletion = { done.fulfill() }
        f.subject.process(blockHash: Data(repeating: 7, count: 32))
        await fulfillment(of: [done], timeout: 3)
        await Task.yield()
    }
    func testFinalizedTransferPersistsExactHashStatusAndPosition() async throws {
        let f = try SubscriptionFixture(); try f.track(); await process(f)
        let item = try XCTUnwrap(rows(f).first)
        equal(item.txHash, try Data(hexStringSSF: f.hex).blake2b32().toHex(includePrefix: true))
        equal(item.status, .success); equal(item.blockNumber, 42); equal(item.txIndex, 0)
        equal(item.sender, f.address); equal(item.receiver, try f.address(f.bob))
        equal(f.subject.unhandledTransactions.count, 0)
    }
    func testFailedTransferPersistsFailureInsteadOfSuccess() async throws {
        let f = try SubscriptionFixture(); try f.track(); f.storage.events = [try f.event("System", "ExtrinsicFailed")]
        await process(f); equal(try rows(f).first?.status, .failed)
    }
    func testDedicatedFeeIsStoredInExactRawUnits() async throws {
        let f = try SubscriptionFixture(); try f.track(); f.storage.events += [try f.event("XorFee", "FeeWithdrawn", data: ["1234567890123456789012345"])]
        await process(f); equal(try rows(f).first?.fee, "1234567890123456789012345")
    }
    func testUnknownBlockTransactionsDoNotProduceLocalRowsOrContacts() async throws {
        let f = try SubscriptionFixture(); await process(f)
        equal(try rows(f).count, 0); equal(f.contacts.addresses, []); equal(f.events.insertions, 0)
    }
    func testMissingOutcomeRetainsTransactionForLaterAuthoritativeRead() async throws {
        let f = try SubscriptionFixture(); try f.track(); f.storage.events = []
        await process(f); equal(try rows(f).count, 0); equal(f.subject.unhandledTransactions.count, 1)
    }
    func testRetryAfterMissingOutcomeCanResolveTheTransaction() async throws {
        let f = try SubscriptionFixture(); try f.track(); f.storage.events = []
        await process(f); f.storage.events = [try f.event()]; await process(f)
        equal(try rows(f).count, 1); equal(f.subject.unhandledTransactions.count, 0)
    }
    func testConflictingOutcomeRetainsTransactionForRetry() async throws {
        let f = try SubscriptionFixture(); try f.track(); f.storage.events += [try f.event("System", "ExtrinsicFailed")]
        await process(f); equal(try rows(f).count, 0); equal(f.subject.unhandledTransactions.count, 1)
    }
    func testUnrelatedWalletTransactionIsNotRemovedOrPersisted() async throws {
        let f = try SubscriptionFixture(); try f.track(from: f.carol)
        await process(f); equal(try rows(f).count, 0); equal(f.subject.unhandledTransactions.count, 1)
    }
    func testFailedHistoryWritePreservesRetryAndDoesNotAnnounceAnInsertion() async throws {
        let f = try SubscriptionFixture(); try f.track(); f.rows.failWrites = true
        await process(f); equal(try rows(f).count, 0); equal(f.events.insertions, 0)
        equal(f.subject.unhandledTransactions.count, 1)
    }
    func testHistoryWriteCanRetryAfterPersistenceRecovers() async throws {
        let f = try SubscriptionFixture(); try f.track(); f.rows.failWrites = true
        await process(f); f.rows.failWrites = false; await process(f)
        equal(try rows(f).count, 1); equal(f.events.insertions, 1); equal(f.subject.unhandledTransactions.count, 0)
    }
    func testOversizedBlockNumberDoesNotTrapOrConsumeTheTransaction() async throws {
        let f = try SubscriptionFixture(); try f.track(); f.engine.number = "0x10000000000000000"
        await process(f); equal(try rows(f).count, 0); equal(f.subject.unhandledTransactions.count, 1)
    }
    func testMaximumBlockNumberRetainsItsExactUnsignedValue() async throws {
        let f = try SubscriptionFixture(); try f.track(); f.engine.number = "0xffffffffffffffff"
        await process(f); equal(try rows(f).first?.blockNumber, UInt64.max)
    }
    func testBlockReadFailurePreservesPendingTransaction() async throws {
        let f = try SubscriptionFixture(); try f.track(); f.engine.failure = SubscriptionFailure.offline
        await process(f); equal(try rows(f).count, 0); equal(f.subject.unhandledTransactions.count, 1)
    }
    func testEventReadFailurePreservesPendingTransaction() async throws {
        let f = try SubscriptionFixture(); try f.track(); f.storage.failure = SubscriptionFailure.offline
        await process(f); equal(try rows(f).count, 0); equal(f.subject.unhandledTransactions.count, 1)
    }
    func testRuntimeReadFailurePreservesPendingTransaction() async throws {
        let f = try SubscriptionFixture(); try f.track(); f.runtime.failure = SubscriptionFailure.offline
        await process(f); equal(try rows(f).count, 0); equal(f.subject.unhandledTransactions.count, 1)
    }
    func testInvalidBlockNumberDoesNotConsumePendingTransaction() async throws {
        let f = try SubscriptionFixture(); try f.track(); f.engine.number = "invalid"
        await process(f); equal(try rows(f).count, 0); equal(f.subject.unhandledTransactions.count, 1)
    }
    func testMalformedExtrinsicBytesRemainUnresolvedWithoutContactMutation() async throws {
        let f = try SubscriptionFixture(); try f.track(hex: "not-hex"); f.engine.extrinsics = ["not-hex"]
        await process(f); equal(try rows(f).count, 0); equal(f.contacts.addresses, []); equal(f.subject.unhandledTransactions.count, 1)
    }
    func testEmptyBlockPreservesPendingTransaction() async throws {
        let f = try SubscriptionFixture(); try f.track(); f.engine.extrinsics = []
        await process(f); equal(try rows(f).count, 0); equal(f.subject.unhandledTransactions.count, 1)
    }
    func testTransactionIndexMatchesItsActualBlockPosition() async throws {
        let f = try SubscriptionFixture(); try f.track(); f.engine.extrinsics = ["0x0102", f.hex]
        f.storage.events = [try f.event(index: 1)]; await process(f)
        equal(try rows(f).first?.txIndex, 1)
    }
    func testDuplicateBlockDeliveryDoesNotRepeatContactsOrInsertions() async throws {
        let f = try SubscriptionFixture(); try f.track(); await process(f); await process(f)
        equal(try rows(f).count, 1); equal(f.contacts.addresses, [try f.address(f.bob)]); equal(f.events.insertions, 1)
    }
    func testContactFailureDoesNotDiscardConfirmedHistory() async throws {
        let f = try SubscriptionFixture(); try f.track(); f.contacts.failure = SubscriptionFailure.offline
        await process(f); equal(try rows(f).count, 1)
    }
    func testBlockAndEventsArePinnedToTheRequestedHash() async throws {
        let f = try SubscriptionFixture(); await process(f)
        equal(f.engine.requests.first?.0, SoraPassport.RPCMethod.getChainBlock)
        equal(f.engine.requests.first?.1, [Data(repeating: 7, count: 32).toHex(includePrefix: true)])
        equal(f.storage.blocks, [Data(repeating: 7, count: 32)])
        equal(f.storage.keys, [try StorageKeyFactory().key(from: .events)])
    }
    func testInsertionNotificationUsesMainQueueAfterRowPersistence() async throws {
        let f = try SubscriptionFixture(); try f.track(); await process(f)
        equal(f.events.insertions, 1); equal(f.events.allMain, true); equal(try rows(f).count, 1)
    }
}
private enum SubscriptionFailure: Swift.Error { case offline }
private final class SubscriptionFixture {
    let alice = Data(repeating: 3, count: 32), bob = Data(repeating: 4, count: 32), carol = Data(repeating: 5, count: 32)
    let hex = "0x040506"
    let rows = SubscriptionRepository()
    let operations = SubscriptionOperations(), storage = SubscriptionStorage(), contacts = SubscriptionContacts(), engine = SubscriptionEngine(), runtime = SubscriptionRuntime(), events = SubscriptionEvents()
    var subject: TransactionSubscription!
    var address: String { try! address(alice) }
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
  func signature(_ sender: Data) throws -> ExtrinsicSignature {
    ExtrinsicSignature(
      address: try MultiAddress.accoundId(sender).subscriptionJSON(),
      signature: try MultiSignature.sr25519(data: Data(repeating: 0, count: 64))
        .subscriptionJSON(), extra: .init(era: .immortal, nonce: 0, tip: 0),
      type: "MultiSignature")
  }
  func transfer(from: Data? = nil, to: Data? = nil) throws -> Extrinsic {
    let args = SoraTransferCall(
      receiver: to ?? bob, amount: 100, assetId: AssetId(wrappedValue: WalletAssetId.val.rawValue))
    return Extrinsic(
      signature: try signature(from ?? alice),
      call: try RuntimeCall(moduleName: "Assets", callName: "transfer", args: args)
        .subscriptionJSON())
  }
  func generic(from: Data? = nil) throws -> Extrinsic {
    Extrinsic(
      signature: try signature(from ?? alice),
      call: try RuntimeCall(moduleName: "System", callName: "remark", args: ProcessingEmptyArgs())
        .subscriptionJSON())
  }
  func event(
    _ module: String = "System", _ name: String = "ExtrinsicSuccess", index: UInt32 = 0,
    data: [Any] = []
  ) throws -> EventRecord {
    try JSONDecoder().decode(
      EventRecord.self,
      from: JSONSerialization.data(withJSONObject: [
        "phase": ["ApplyExtrinsic", String(index)], "event": [module, [name, data]],
      ]))
  }

    init() throws {
        runtime.coder = try Self.coder.get(); storage.events = [try event()]; engine.extrinsics = [hex]
        subject = TransactionSubscription(engine: engine, address: address, chain: .sora, addressFactory: SS58AddressFactory(), runtimeService: runtime, txStorage: AnyDataProviderRepository(rows), contactOperationFactory: contacts, storageRequestFactory: storage, operationManager: operations, eventCenter: events, logger: Logger.shared)
    }
    func address(_ data: Data) throws -> String { try SS58AddressFactory().address(fromAccountId: data, type: SNAddressType(chain: .sora)) }
    func track(from: Data? = nil, hex: String? = nil) throws { subject.unhandledTransactions.append(.init(object: try transfer(from: from), hex: hex ?? self.hex)) }
}
private extension Encodable {
    func subscriptionJSON() throws -> JSON { try JSONDecoder.scaleCompatible(snakeCase: false).decode(SoraPassport.JsonContainer.self, from: JSONEncoder.scaleCompatible().encode(SoraPassport.EncodingContainer(value: self))).value }
}
private struct ProcessingEmptyArgs: Codable {}
private final class SubscriptionRuntime: SoraPassport.RuntimeCodingServiceProtocol {
    var coder: RuntimeCoderFactoryProtocol!, failure: Swift.Error?
    func fetchCoderFactoryOperation(with timeout: TimeInterval, closure: SoraPassport.RuntimeMetadataClosure?) -> BaseOperation<RuntimeCoderFactoryProtocol> {
        ClosureOperation { if let failure = self.failure { throw failure }; return self.coder }
    }
}
private final class SubscriptionOperations: OperationManagerProtocol {
    let queue = OperationQueue(); var onCompletion: (() -> Void)?
    func enqueue(operations: [Operation], in mode: OperationMode) {
        let completion = onCompletion; onCompletion = nil
        let finished = DispatchGroup()
        for operation in operations {
            finished.enter()
            let existing = operation.completionBlock
            operation.completionBlock = { existing?(); finished.leave() }
        }
        finished.notify(queue: .main) { completion?() }
        queue.addOperations(operations, waitUntilFinished: false)
    }
}
private final class SubscriptionContacts: WalletContactOperationFactoryProtocol {
    var addresses = [String](), failure: Swift.Error?
    func saveByAddressOperation(_ address: String) -> CompoundOperationWrapper<Void> {
        .init(targetOperation: ClosureOperation { self.addresses.append(address); if let failure = self.failure { throw failure } })
    }
    func fetchContactsOperation() -> CompoundOperationWrapper<[ContactItem]> { .init(targetOperation: ClosureOperation { [] }) }
}
private final class SubscriptionEvents: EventCenterProtocol {
    var insertions = 0, allMain = true
    func notify(with event: EventProtocol) { if event is WalletNewTransactionInserted { insertions += 1; allMain = allMain && Thread.isMainThread } }
    func notify(with event: EventProtocol, completionOnMain: @escaping () -> Void) { notify(with: event); completionOnMain() }
    func add(observer: EventVisitorProtocol, dispatchIn: DispatchQueue?) {}
    func remove(observer: EventVisitorProtocol) {}
}
private final class SubscriptionEngine: JSONRPCEngine {
    var url: URL?; var pendingEngineRequests: [JSONRPCRequest] { [] }
    var failure: Swift.Error?, extrinsics = [String](), number = "0x2a", requests = [(String, [String])]()
    func callMethod<P: Codable, T: Decodable>(_ method: String, params: P?, options: JSONRPCOptions, completion closure: ((Result<T, Swift.Error>) -> Void)?) throws -> UInt16 {
        requests.append((method, try JSONDecoder().decode([String].self, from: JSONEncoder().encode(params))))
        let result = Result<T, Swift.Error> {
            if let failure { throw failure }
            let body: [String: Any] = ["block": ["extrinsics": extrinsics, "header": ["number": number, "digest": ["logs": []], "extrinsicsRoot": "0x00", "stateRoot": "0x00", "parentHash": "0x00"]]]
            return try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: body))
        }
        DispatchQueue.global().async { closure?(result) }; return 1
    }
    func subscribe<P: Codable, T: Decodable>(_ method: String, params: P?, updateClosure: @escaping (T) -> Void, failureClosure: @escaping (Swift.Error, Bool) -> Void) throws -> UInt16 { XCTFail("Unexpected subscription"); throw SubscriptionFailure.offline }
    func cancelForIdentifier(_ identifier: UInt16) {}; func generateRequestId() -> UInt16 { 1 }; func addSubscription(_ subscription: JSONRPCSubscribing) {}; func connectIfNeeded() {}; func disconnectIfNeeded() {}; func unsubsribe(_ identifier: UInt16) throws {}
}
private final class SubscriptionStorage: StorageRequestFactoryProtocol {
    var events = [EventRecord](), failure: Swift.Error?, blocks = [Data?](), keys = [Data]()
    func queryItems<T: Decodable>(engine: JSONRPCEngine, keys: @escaping () throws -> [Data], factory: @escaping () throws -> RuntimeCoderFactoryProtocol, storagePath: StorageCodingPath, at blockHash: Data?) -> CompoundOperationWrapper<[StorageResponse<T>]> {
        blocks.append(blockHash)
        return .init(targetOperation: ClosureOperation {
            if let failure = self.failure { throw failure }; _ = try factory(); self.keys = try keys()
            return [.init(key: self.keys[0], data: nil, value: try XCTUnwrap(self.events as? T))]
        })
    }
    func queryItems<K: Encodable, T: Decodable>(engine: JSONRPCEngine, keyParams: @escaping () throws -> [K], factory: @escaping () throws -> RuntimeCoderFactoryProtocol, storagePath: StorageCodingPath, at blockHash: Data?) -> CompoundOperationWrapper<[StorageResponse<T>]> { .init(targetOperation: ClosureOperation { XCTFail("Unexpected keyed read"); return [] }) }
    func queryItems<K1: Encodable, K2: Encodable, T: Decodable>(engine: JSONRPCEngine, keyParams1: @escaping () throws -> [K1], keyParams2: @escaping () throws -> [K2], factory: @escaping () throws -> RuntimeCoderFactoryProtocol, storagePath: StorageCodingPath, at blockHash: Data?) -> CompoundOperationWrapper<[StorageResponse<T>]> { .init(targetOperation: ClosureOperation { XCTFail("Unexpected keyed read"); return [] }) }
}

private final class SubscriptionRepository: DataProviderRepositoryProtocol {
    typealias Model = TransactionHistoryItem
    let base = InMemoryDataProviderRepository<Model>()
    var failWrites = false
    func fetchOperation(by ids: @escaping () throws -> [String], options: RepositoryFetchOptions) -> BaseOperation<[Model]> { base.fetchOperation(by: ids, options: options) }
    func fetchOperation(by id: @escaping () throws -> String, options: RepositoryFetchOptions) -> BaseOperation<Model?> { base.fetchOperation(by: id, options: options) }
    func fetchOperation(by request: RepositorySliceRequest, options: RepositoryFetchOptions) -> BaseOperation<[Model]> { base.fetchOperation(by: request, options: options) }
    func fetchAllOperation(with options: RepositoryFetchOptions) -> BaseOperation<[Model]> { base.fetchAllOperation(with: options) }
    func saveOperation(_ update: @escaping () throws -> [Model], _ delete: @escaping () throws -> [String]) -> BaseOperation<Void> { failWrites ? ClosureOperation { throw SubscriptionFailure.offline } : base.saveOperation(update, delete) }
    func saveBatchOperation(_ update: @escaping () throws -> [Model], _ delete: @escaping () throws -> [String]) -> BaseOperation<Void> { saveOperation(update, delete) }
    func replaceOperation(_ update: @escaping () throws -> [Model]) -> BaseOperation<Void> { base.replaceOperation(update) }
    func deleteAllOperation() -> BaseOperation<Void> { base.deleteAllOperation() }
    func fetchCountOperation() -> BaseOperation<Int> { base.fetchCountOperation() }
}
