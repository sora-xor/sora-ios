// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause
import Foundation
import RobinHood
import SSFModels
import SSFUtils
import XCTest

@testable import SoraPassport

final class RuntimeProviderLifecycleTests: XCTestCase {
  private var queues: [OperationQueue] = []
  override func tearDown() {
    queues.forEach {
      $0.cancelAllOperations()
      $0.isSuspended = false
    }
    queues.removeAll()
    super.tearDown()
  }
  private struct Fixture {
    let provider: RuntimeProvider
    let factory: SnapshotFixture
    let queue: OperationQueue
    let events: ProviderEvents
    let repository: MetadataRepository
  }
  private func make(reviewed: Bool = false, own: Bool = false, hot: Bool = true) -> Fixture {
    let factory = SnapshotFixture()
    let queue = OperationQueue()
    let events = ProviderEvents()
    let repository = MetadataRepository()
    queue.isSuspended = true
    queues.append(queue)
    let id = reviewed ? PIIndexerClient.soraMainnetGenesis : "fixture-chain"
    let types =
      own
      ? SoraPassport.ChainModel.TypesSettings(
        url: URL(string: "https://fixture.invalid/types")!, overridesCommon: true) : nil
    let chain = SoraPassport.ChainModel(
      chainId: id, name: "Fixture", nodes: [], addressPrefix: 69, types: types, icon: nil,
      iosMinAppVersion: nil)
    return Fixture(
      provider: RuntimeProvider(
        chainModel: chain, snapshotOperationFactory: factory,
        snapshotHotOperationFactory: hot ? factory : nil, eventCenter: events,
        operationQueue: queue, repository: AnyDataProviderRepository(repository)), factory: factory,
      queue: queue, events: events, repository: repository)
  }
  private func snapshot(version: UInt32 = 133) throws -> RuntimeSnapshot {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let value = try RuntimeSnapshotFactory.makeOwnTypesSnapshot(
      chainId: PIIndexerClient.soraMainnetGenesis,
      runtimeMetadataItem: SoraPassport.RuntimeMetadataItem(
        chain: PIIndexerClient.soraMainnetGenesis, version: 133, txVersion: 131,
        metadata: Data(
          contentsOf: root.appendingPathComponent(
            "Fixtures/Modernization/sora2-metadata-spec133.scale")), resolver: nil),
      ownTypes: Data(
        contentsOf: root.appendingPathComponent("SoraPassport/Resources/runtime-sora.json")),
      dataHasher: .twox256)
    return RuntimeSnapshot(
      localCommonHash: "common", localChainHash: "chain",
      typeRegistryCatalog: value.typeRegistryCatalog, specVersion: version, txVersion: 131,
      metadata: value.metadata)
  }
  private func wait(_ condition: () -> Bool) async -> Bool {
    for _ in 0..<100 {
      if condition() { return true }
      try? await Task.sleep(nanoseconds: 5_000_000)
    }
    return condition()
  }
  private func complete(_ f: Fixture, index: Int = 0, result: Result<RuntimeSnapshot?, Error>) async
  {
    let operation = f.factory.operations[index]
    operation.result = result
    operation.completionBlock?()
    _ = await wait { !f.events.values.isEmpty || f.provider.currentWrapper == nil }
  }
  private func start(_ operation: BaseOperation<RuntimeCoderFactoryProtocol>) -> OperationQueue {
    let queue = OperationQueue()
    queues.append(queue)
    queue.addOperation(operation)
    return queue
  }
  private func version(_ spec: UInt32) -> RuntimeVersion {
    try! JSONDecoder().decode(
      RuntimeVersion.self, from: Data("{\"specVersion\":\(spec),\"transactionVersion\":131}".utf8))
  }
  private func notifyReady(_ f: Fixture) {
    f.provider.processRuntimeChainTypesSyncCompleted(
      event: RuntimeChainTypesSyncCompleted(chainId: f.provider.chainId, fileHash: "chain"))
    f.provider.processRuntimeChainMetadataSyncCompleted(
      event: RuntimeMetadataSyncCompleted(
        chainId: f.provider.chainId,
        version: version(133)))
    f.provider.processRuntimeCommonTypesSyncCompleted(
      event: RuntimeCommonTypesSyncCompleted(fileHash: "common"))
  }
  func testReviewedChainAlwaysUsesOnlyItsReviewedTypes() {
    let f = make(reviewed: true)
    XCTAssertEqual(f.provider.typesUsage, .onlyOwn)
    f.provider.replaceTypesUsage(.both)
    XCTAssertEqual(f.provider.typesUsage, .onlyOwn)
    XCTAssertEqual(f.events.added, 1)
  }
  func testOtherChainsRetainTheirConfiguredTypeStrategy() {
    XCTAssertEqual(make().provider.typesUsage, .onlyCommon)
    XCTAssertEqual(make(own: true).provider.typesUsage, .onlyOwn)
  }
  func testColdSetupWaitsForAllRequiredInputs() {
    let f = make()
    f.provider.setup()
    XCTAssertTrue(f.factory.operations.isEmpty)
    f.provider.processRuntimeChainTypesSyncCompleted(
      event: RuntimeChainTypesSyncCompleted(chainId: f.provider.chainId, fileHash: "chain"))
    XCTAssertTrue(f.factory.operations.isEmpty)
    f.provider.processRuntimeChainMetadataSyncCompleted(
      event: RuntimeMetadataSyncCompleted(
        chainId: f.provider.chainId,
        version: version(133)))
    XCTAssertTrue(f.factory.operations.isEmpty)
    f.provider.processRuntimeCommonTypesSyncCompleted(
      event: RuntimeCommonTypesSyncCompleted(fileHash: "common"))
    XCTAssertEqual(f.factory.operations.count, 1)
  }
  func testOwnTypesDoNotWaitForUnrelatedCommonTypes() {
    let f = make(own: true)
    notifyReady(f)
    XCTAssertEqual(f.factory.operations.count, 1)
    XCTAssertEqual(f.factory.usages, [.onlyOwn])
  }
  func testUnrelatedChainEventsCannotStartABuild() {
    let f = make()
    f.provider.processRuntimeChainTypesSyncCompleted(
      event: RuntimeChainTypesSyncCompleted(chainId: "other", fileHash: "chain"))
    f.provider.processRuntimeChainMetadataSyncCompleted(
      event: RuntimeMetadataSyncCompleted(
        chainId: "other", version: version(133)))
    f.provider.processRuntimeCommonTypesSyncCompleted(
      event: RuntimeCommonTypesSyncCompleted(fileHash: "common"))
    XCTAssertTrue(f.factory.operations.isEmpty)
  }
  func testHotSetupCreatesOnlyOneConcurrentBuild() {
    let f = make()
    f.provider.setupHot()
    f.provider.setupHot()
    f.provider.setup()
    XCTAssertEqual(f.factory.operations.count, 1)
    XCTAssertNotNil(f.provider.currentWrapper)
  }
  func testMissingHotFactoryDoesNotInventASnapshot() {
    let f = make(hot: false)
    f.provider.setupHot()
    XCTAssertNil(f.provider.snapshot)
    XCTAssertNil(f.provider.currentWrapper)
    XCTAssertTrue(f.factory.operations.isEmpty)
  }
  func testSuccessfulHotSnapshotNotifiesObserversAndServesARealCoder() async throws {
    let f = make()
    f.provider.setupHot()
    await complete(f, result: .success(try snapshot()))
    XCTAssertEqual(f.provider.snapshot?.specVersion, 133)
    XCTAssertEqual(
      f.events.values.compactMap { $0 as? RuntimeCoderCreated }.map(\.chainId), [f.provider.chainId]
    )
    let operation = f.provider.fetchCoderFactoryOperation()
    _ = start(operation)
    let finished = await wait { operation.isFinished }
    XCTAssertTrue(finished)
    XCTAssertEqual(try XCTUnwrap(operation.result).get().specVersion, 133)
  }
  func testQueuedCoderRequestsCompleteWhenTheSnapshotArrives() async throws {
    let f = make()
    let op = f.provider.fetchCoderFactoryOperation(with: 1, closure: nil)
    _ = start(op)
    let pending = await wait { !f.provider.pendingRequests.isEmpty }
    XCTAssertTrue(pending)
    f.provider.setupHot()
    await complete(f, result: .success(try snapshot()))
    let finished = await wait { op.isFinished }
    XCTAssertTrue(finished)
    XCTAssertEqual(try XCTUnwrap(op.result).get().specVersion, 133)
    XCTAssertTrue(f.provider.pendingRequests.isEmpty)
  }
  func testCleanupCompletesPendingRequestsWithUnavailable() async {
    let f = make()
    let op = f.provider.fetchCoderFactoryOperation(with: 1, closure: nil)
    _ = start(op)
    _ = await wait { !f.provider.pendingRequests.isEmpty }
    f.provider.cleanup()
    let finished = await wait { op.isFinished }
    XCTAssertTrue(finished)
    XCTAssertThrowsError(try XCTUnwrap(op.result).get())
    XCTAssertTrue(f.provider.pendingRequests.isEmpty)
  }
  func testSnapshotFailureCompletesPendingRequestsRatherThanHanging() async {
    let f = make()
    let op = f.provider.fetchCoderFactoryOperation(with: 1, closure: nil)
    _ = start(op)
    _ = await wait { !f.provider.pendingRequests.isEmpty }
    f.provider.setupHot()
    await complete(f, result: .failure(ProviderFailure.unavailable))
    let finished = await wait { op.isFinished }
    XCTAssertTrue(finished, "Runtime failure must release callers")
    f.provider.cleanup()
    XCTAssertEqual(f.events.values.compactMap { $0 as? RuntimeCoderCreationFailed }.count, 1)
  }
  func testAbsentSnapshotCompletesPendingRequestsRatherThanHanging() async {
    let f = make()
    let op = f.provider.fetchCoderFactoryOperation(with: 1, closure: nil)
    _ = start(op)
    _ = await wait { !f.provider.pendingRequests.isEmpty }
    f.provider.setupHot()
    await complete(f, result: .success(nil))
    let finished = await wait { op.isFinished }
    XCTAssertTrue(finished, "A completed build with no metadata must release callers")
    f.provider.cleanup()
  }
  func testRequestedTimeoutBoundsAnUnavailableRuntimeWait() async {
    let f = make()
    let op = f.provider.fetchCoderFactoryOperation(with: 0.02, closure: nil)
    _ = start(op)
    let finished = await wait { op.isFinished }
    XCTAssertTrue(finished, "The requested runtime deadline must be respected")
    f.provider.cleanup()
    if finished { XCTAssertThrowsError(try XCTUnwrap(op.result).get()) }
  }
  func testZeroTimeoutFailsWithoutLeavingAPendingRequest() async {
    let f = make()
    let op = f.provider.fetchCoderFactoryOperation(with: 0, closure: nil)
    _ = start(op)
    let finished = await wait { op.isFinished }
    XCTAssertTrue(finished)
    f.provider.cleanup()
    XCTAssertTrue(f.provider.pendingRequests.isEmpty)
  }
  func testDeallocatedProviderDoesNotStrandAnAwaitOperation() async {
    var fixture: Fixture? = make()
    let op = fixture!.provider.fetchCoderFactoryOperation(with: 0.02, closure: nil)
    fixture = nil
    _ = start(op)
    let finished = await wait { op.isFinished }
    XCTAssertTrue(finished)
    if finished { XCTAssertThrowsError(try XCTUnwrap(op.result).get()) }
  }
  func testDeallocationCompletesAnAlreadyWaitingOperation() async {
    var fixture: Fixture? = make()
    let operation = fixture!.provider.fetchCoderFactoryOperation(with: 1, closure: nil)
    _ = start(operation)
    _ = await wait { fixture?.provider.pendingRequests.isEmpty == false }
    weak let provider = fixture?.provider
    let events = fixture!.events
    fixture = nil
    let finished = await wait { operation.isFinished }
    XCTAssertTrue(finished)
    XCTAssertNil(provider)
    XCTAssertEqual(events.added, 0)
  }
  func testNonfiniteAndNegativeDeadlinesCompleteWithoutWaiting() async {
    for deadline in [TimeInterval.nan, .infinity, -1] {
      let f = make()
      let operation = f.provider.fetchCoderFactoryOperation(with: deadline, closure: nil)
      _ = start(operation)
      let finished = await wait { operation.isFinished }
      XCTAssertTrue(finished)
      f.provider.cleanup()
    }
  }
  func testDeallocatedProviderFailsALegacyOperation() async {
    var fixture: Fixture? = make()
    let op = fixture!.provider.fetchCoderFactoryOperation()
    fixture = nil
    _ = start(op)
    let finished = await wait { op.isFinished }
    XCTAssertTrue(finished)
    XCTAssertThrowsError(try XCTUnwrap(op.result).get())
  }
  func testCleanupCancelsTheBuildAndDropsTheCachedSnapshot() async throws {
    let f = make()
    f.provider.setupHot()
    await complete(f, result: .success(try snapshot()))
    f.provider.processRuntimeChainMetadataSyncCompleted(
      event: RuntimeMetadataSyncCompleted(
        chainId: f.provider.chainId,
        version: version(134)))
    f.provider.cleanup()
    XCTAssertNil(f.provider.snapshot)
    XCTAssertNil(f.provider.currentWrapper)
  }
  func testCleanupCancelsAnInProgressBuild() {
    let f = make()
    f.provider.setupHot()
    f.provider.cleanup()
    XCTAssertTrue(f.factory.operations[0].isCancelled)
    XCTAssertNil(f.provider.currentWrapper)
  }
  func testLateSnapshotAfterCleanupCannotReactivateTheProvider() async throws {
    let f = make()
    f.provider.setupHot()
    let op = f.factory.operations[0]
    let completion = op.completionBlock
    f.provider.cleanup()
    op.result = .success(try snapshot())
    completion?()
    try? await Task.sleep(nanoseconds: 30_000_000)
    XCTAssertNil(f.provider.snapshot)
    XCTAssertTrue(f.events.values.isEmpty)
  }
  func testOldBuildCompletionCannotReplaceANewerRuntimeSnapshot() async throws {
    let f = make()
    notifyReady(f)
    let old = f.factory.operations[0]
    let oldCompletion = old.completionBlock
    f.provider.processRuntimeChainMetadataSyncCompleted(
      event: RuntimeMetadataSyncCompleted(
        chainId: f.provider.chainId,
        version: version(134)))
    XCTAssertEqual(f.factory.operations.count, 2)
    await complete(f, index: 1, result: .success(try snapshot(version: 134)))
    old.result = .success(try snapshot(version: 133))
    oldCompletion?()
    try? await Task.sleep(nanoseconds: 30_000_000)
    XCTAssertEqual(f.provider.snapshot?.specVersion, 134)
  }
  func testSameChainTypesHashDoesNotRebuildAnExistingSnapshot() async throws {
    let f = make()
    f.provider.setupHot()
    await complete(f, result: .success(try snapshot()))
    f.provider.processRuntimeChainTypesSyncCompleted(
      event: RuntimeChainTypesSyncCompleted(chainId: f.provider.chainId, fileHash: "chain"))
    f.provider.processRuntimeCommonTypesSyncCompleted(
      event: RuntimeCommonTypesSyncCompleted(fileHash: "common"))
    XCTAssertEqual(f.factory.operations.count, 1)
  }
  func testReplacingTypeUsageCancelsThePreviousBuild() {
    let f = make()
    notifyReady(f)
    let old = f.factory.operations[0]
    f.provider.replaceTypesUsage(.both)
    XCTAssertTrue(old.isCancelled)
    XCTAssertEqual(f.factory.usages, [.onlyCommon, .both])
  }
  func testReplacingWithTheSameUsageDoesNotRestartTheBuild() {
    let f = make()
    notifyReady(f)
    f.provider.replaceTypesUsage(.onlyCommon)
    XCTAssertEqual(f.factory.operations.count, 1)
    XCTAssertFalse(f.factory.operations[0].isCancelled)
  }
}
private enum ProviderFailure: Error { case unavailable }
private final class SnapshotFixture: RuntimeSnapshotFactoryProtocol,
  RuntimeHotBootSnapshotFactoryProtocol
{
  var operations: [BaseOperation<RuntimeSnapshot?>] = [],
    usages: [SoraPassport.ChainModel.TypesUsage] = []
  func createRuntimeSnapshotWrapper(
    for typesUsage: SoraPassport.ChainModel.TypesUsage, dataHasher: StorageHasher
  ) -> CompoundOperationWrapper<RuntimeSnapshot?> {
    let op = BaseOperation<RuntimeSnapshot?>()
    operations.append(op)
    usages.append(typesUsage)
    return CompoundOperationWrapper(targetOperation: op)
  }
}
private final class ProviderEvents: EventCenterProtocol {
  private let lock = NSLock()
  private var recorded: [EventProtocol] = []
  var added = 0
  var values: [EventProtocol] {
    lock.lock()
    defer { lock.unlock() }
    return recorded
  }
  func notify(with event: EventProtocol) {
    lock.lock()
    recorded.append(event)
    lock.unlock()
  }
  func notify(with event: EventProtocol, completionOnMain: @escaping () -> Void) {
    notify(with: event)
    DispatchQueue.main.async(execute: completionOnMain)
  }
  func add(observer: EventVisitorProtocol, dispatchIn queue: DispatchQueue?) { added += 1 }
  func remove(observer: EventVisitorProtocol) { added -= 1 }
}
private final class MetadataRepository: DataProviderRepositoryProtocol {
  typealias Model = SoraPassport.RuntimeMetadataItem
  func fetchAllOperation(with options: RepositoryFetchOptions) -> BaseOperation<[Model]> {
    ClosureOperation { [] }
  }
  func fetchOperation(by ids: @escaping () throws -> [String], options: RepositoryFetchOptions)
    -> BaseOperation<[Model]>
  { ClosureOperation { [] } }
  func fetchOperation(by id: @escaping () throws -> String, options: RepositoryFetchOptions)
    -> BaseOperation<Model?>
  { ClosureOperation { nil } }
  func fetchOperation(by request: RepositorySliceRequest, options: RepositoryFetchOptions)
    -> BaseOperation<[Model]>
  { ClosureOperation { [] } }
  func fetchCountOperation() -> BaseOperation<Int> { ClosureOperation { 0 } }
  func saveOperation(
    _ updates: @escaping () throws -> [Model], _ deletions: @escaping () throws -> [String]
  ) -> BaseOperation<Void> {
    ClosureOperation {
      _ = try updates()
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
