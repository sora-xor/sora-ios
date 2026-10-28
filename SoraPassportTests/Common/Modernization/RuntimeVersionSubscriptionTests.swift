// SPDX-License-Identifier: BSD-4-Clause
import Foundation
import RobinHood
import SSFStorageQueryKitFixed
import SSFUtils
import XCTest

@testable import SoraPassport

final class RuntimeVersionSubscriptionTests: XCTestCase {
  private struct Fixture {
    var subscription: RuntimeVersionSubscription?
    let engine: VersionEngine
    let store: VersionRepository
    let manager: VersionManager
  }
  private func make() throws -> Fixture {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let bytes = try Data(
      contentsOf: root.appendingPathComponent("Fixtures/Modernization/sora2-metadata-spec133.scale")
    )
    let engine = VersionEngine()
    engine.metadata = "0x" + bytes.map { String(format: "%02x", $0) }.joined()
    let store = VersionRepository()
    let manager = VersionManager()
    let sub = RuntimeVersionSubscription(
      chain: .sora, storage: AnyDataProviderRepository(store), engine: engine,
      operationManager: manager, logger: Logger.shared)
    return Fixture(subscription: sub, engine: engine, store: store, manager: manager)
  }
  private func emit(_ f: Fixture, spec: UInt32 = 133, tx: UInt32 = 131) throws {
    try f.engine.emit(spec: spec, tx: tx)
  }
  private func run(_ f: Fixture, index: Int = 0) async {
    guard f.manager.groups.indices.contains(index) else {
      return XCTFail("Missing metadata operation group")
    }
    let ops = f.manager.groups[index]
    let done = expectation(description: "metadata completion")
    let finish = BlockOperation { done.fulfill() }
    ops.forEach { finish.addDependency($0) }
    let queue = OperationQueue()
    (ops.filter { !$0.isFinished } + [finish]).forEach { queue.addOperation($0) }
    await fulfillment(of: [done], timeout: 2)
  }
  private func item(_ f: Fixture, spec: UInt32 = 133, tx: UInt32 = 131)
    -> SoraPassport.RuntimeMetadataItem
  {
    SoraPassport.RuntimeMetadataItem(
      chain: Chain.sora.genesisHash(), version: spec, txVersion: tx, metadata: Data([0]),
      resolver: nil)
  }
  func testSubscribesToRuntimeVersionAndCancelsOnRelease() throws {
    var f = try make()
    XCTAssertEqual(f.engine.subscriptionMethods, ["state_subscribeRuntimeVersion"])
    f.subscription = nil
    XCTAssertEqual(f.engine.cancelled, [42])
  }
  func testVersionUpdateFetchesAndPersistsDecodedMetadata() async throws {
    let f = try make()
    try emit(f)
    await run(f)
    XCTAssertEqual(f.engine.methods, ["state_getMetadata"])
    XCTAssertEqual(f.store.saved.last?.version, 133)
    XCTAssertEqual(f.store.saved.last?.txVersion, 131)
    XCTAssertGreaterThan(f.store.saved.last?.metadata.count ?? 0, 100)
  }
  func testCompletedMetadataWorkDoesNotRetainTheSubscription() async throws {
    var f: Fixture? = try make()
    weak let subscription = f?.subscription
    let engine = f!.engine
    try emit(f!)
    await run(f!)
    f = nil
    XCTAssertNil(subscription)
    XCTAssertEqual(engine.cancelled, [42])
  }
  func testUnchangedRuntimeSkipsMetadataAndStorageWrite() async throws {
    let f = try make()
    f.store.current = item(f)
    try emit(f)
    await run(f)
    XCTAssertTrue(f.engine.methods.isEmpty)
    XCTAssertTrue(f.store.saved.isEmpty)
  }
  func testTransactionVersionChangeIsPersistedEvenWhenSpecMatches() async throws {
    let f = try make()
    f.store.current = item(f)
    try emit(f, tx: 132)
    await run(f)
    XCTAssertEqual(f.store.saved.last?.txVersion, 132)
  }
  func testOlderSpecCannotReplaceNewerPersistedMetadata() async throws {
    let f = try make()
    f.store.current = item(f, spec: 134)
    try emit(f)
    await run(f)
    XCTAssertEqual(f.store.current?.version, 134)
    XCTAssertTrue(f.store.saved.isEmpty)
  }
  func testOlderTransactionVersionCannotReplaceNewerAtSameSpec() async throws {
    let f = try make()
    f.store.current = item(f, tx: 132)
    try emit(f)
    await run(f)
    XCTAssertEqual(f.store.current?.txVersion, 132)
    XCTAssertTrue(f.store.saved.isEmpty)
  }
  func testOutOfOrderVersionGroupsCannotDowngradeRuntime() async throws {
    let f = try make()
    try emit(f, spec: 133)
    try emit(f, spec: 134)
    await run(f, index: 1)
    await run(f, index: 0)
    XCTAssertEqual(f.store.current?.version, 134)
  }
  func testOlderInFlightFetchCannotOverwriteANewerCompletedUpdate() async throws {
    let f = try make()
    try emit(f, spec: 133)
    try emit(f, spec: 134)
    f.manager.groups[0][0].start()
    f.manager.groups[1][0].start()
    await run(f, index: 1)
    await run(f, index: 0)
    XCTAssertEqual(f.store.current?.version, 134)
  }
  func testNewerSpecMayHaveADifferentTransactionVersion() async throws {
    let f = try make()
    f.store.current = item(f, tx: 150)
    try emit(f, spec: 134, tx: 1)
    await run(f)
    XCTAssertEqual(f.store.current?.version, 134)
    XCTAssertEqual(f.store.current?.txVersion, 1)
  }
  func testRepositoryFailurePreventsMetadataReadAndSave() async throws {
    let f = try make()
    f.store.fetchError = true
    try emit(f)
    await run(f)
    XCTAssertTrue(f.engine.methods.isEmpty)
    XCTAssertTrue(f.store.saved.isEmpty)
  }
  func testMetadataRpcErrorDoesNotOverwriteStoredRuntime() async throws {
    let f = try make()
    f.store.current = item(f, spec: 132)
    f.engine.failRequest = true
    try emit(f)
    await run(f)
    XCTAssertEqual(f.store.current?.version, 132)
    XCTAssertTrue(f.store.saved.isEmpty)
  }
  func testEmptyMetadataIsNeverSaved() async throws {
    let f = try make()
    f.engine.metadata = "0x"
    try emit(f)
    await run(f)
    XCTAssertTrue(f.store.saved.isEmpty)
  }
  func testMalformedMetadataIsNeverSaved() async throws {
    let f = try make()
    f.engine.metadata = "0x01020304"
    try emit(f)
    await run(f)
    XCTAssertTrue(f.store.saved.isEmpty)
  }
  func testNonHexMetadataIsNeverSaved() async throws {
    let f = try make()
    f.engine.metadata = "invalid"
    try emit(f)
    await run(f)
    XCTAssertTrue(f.store.saved.isEmpty)
  }
  func testSubscriptionFailureDoesNotStartMetadataWork() throws {
    let f = try make()
    f.engine.failed?(VersionFailure.injected, false)
    XCTAssertTrue(f.manager.groups.isEmpty)
  }
  func testSaveFailureKeepsPreviousRuntime() async throws {
    let f = try make()
    f.store.current = item(f, spec: 132)
    f.store.saveError = true
    try emit(f)
    await run(f)
    XCTAssertEqual(f.store.current?.version, 132)
  }
}
private enum VersionFailure: Error { case injected }
private final class VersionManager: OperationManagerProtocol {
  var groups: [[Operation]] = []
  func enqueue(operations: [Operation], in mode: OperationMode) { groups.append(operations) }
}
private final class VersionEngine: JSONRPCEngine {
  var url: URL?
  var pendingEngineRequests: [JSONRPCRequest] { [] }
  var metadata = "", failRequest = false
  var methods: [String] = [], subscriptionMethods: [String] = [], cancelled: [UInt16] = []
  var update: ((Data) throws -> Void)?, failed: ((Error, Bool) -> Void)?
  func emit(spec: UInt32, tx: UInt32) throws {
    let data = try JSONSerialization.data(withJSONObject: [
      "jsonrpc": "2.0", "method": "state_runtimeVersion",
      "params": ["subscription": "42", "result": ["specVersion": spec, "transactionVersion": tx]],
    ])
    try update?(data)
  }
  func callMethod<P: Codable, T: Decodable>(
    _ method: String, params: P?, options: JSONRPCOptions,
    completion closure: ((Result<T, Error>) -> Void)?
  ) throws -> UInt16 {
    methods.append(method)
    let value: Result<T, Error>
    if failRequest {
      value = .failure(VersionFailure.injected)
    } else {
      value = .success(try JSONDecoder().decode(T.self, from: JSONEncoder().encode(metadata)))
    }
    DispatchQueue.global().async { closure?(value) }
    return 7
  }
  func subscribe<P: Codable, T: Decodable>(
    _ method: String, params: P?, updateClosure: @escaping (T) -> Void,
    failureClosure: @escaping (Error, Bool) -> Void
  ) throws -> UInt16 {
    subscriptionMethods.append(method)
    update = { data in updateClosure(try JSONDecoder().decode(T.self, from: data)) }
    failed = failureClosure
    return 42
  }
  func cancelForIdentifier(_ identifier: UInt16) { cancelled.append(identifier) }
  func generateRequestId() -> UInt16 { 7 }
  func addSubscription(_ subscription: JSONRPCSubscribing) {}
  func connectIfNeeded() {}
  func disconnectIfNeeded() {}
  func unsubsribe(_ identifier: UInt16) throws {}
}
private final class VersionRepository: DataProviderRepositoryProtocol {
  typealias Model = SoraPassport.RuntimeMetadataItem
  var current: Model?
  var saved: [Model] = []
  var fetchError = false, saveError = false
  func fetchAllOperation(with options: RepositoryFetchOptions) -> BaseOperation<[Model]> {
    ClosureOperation { [] }
  }
  func fetchOperation(by ids: @escaping () throws -> [String], options: RepositoryFetchOptions)
    -> BaseOperation<[Model]>
  { ClosureOperation { [] } }
  func fetchOperation(by id: @escaping () throws -> String, options: RepositoryFetchOptions)
    -> BaseOperation<Model?>
  {
    ClosureOperation {
      if self.fetchError { throw VersionFailure.injected }
      return self.current
    }
  }
  func fetchOperation(by request: RepositorySliceRequest, options: RepositoryFetchOptions)
    -> BaseOperation<[Model]>
  { ClosureOperation { [] } }
  func fetchCountOperation() -> BaseOperation<Int> { ClosureOperation { 0 } }
  func saveOperation(
    _ updates: @escaping () throws -> [Model], _ deletions: @escaping () throws -> [String]
  ) -> BaseOperation<Void> {
    ClosureOperation {
      if self.saveError { throw VersionFailure.injected }
      let values = try updates()
      self.saved += values
      if let last = values.last { self.current = last }
      _ = try deletions()
    }
  }
  func saveBatchOperation(
    _ updates: @escaping () throws -> [Model], _ deletions: @escaping () throws -> [String]
  ) -> BaseOperation<Void> { saveOperation(updates, deletions) }
  func replaceOperation(_ models: @escaping () throws -> [Model]) -> BaseOperation<Void> {
    saveOperation(models, { [] })
  }
  func deleteAllOperation() -> BaseOperation<Void> { ClosureOperation {} }
}
