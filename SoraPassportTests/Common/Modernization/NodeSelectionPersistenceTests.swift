// SPDX-License-Identifier: Apache-2.0
import Foundation
import RobinHood
import SoraKeystore
import XCTest

@testable import SoraPassport

@MainActor final class NodeSelectionPersistenceTests: XCTestCase {
  private func make() -> NodePersistenceFixture { NodePersistenceFixture() }
  private func finish(_ f: NodePersistenceFixture) async {
    for _ in 0..<200 {
      if f.manager.pending == 0 { break }
      try? await Task.sleep(nanoseconds: 5_000_000)
    }
    XCTAssertEqual(f.manager.pending, 0)
    await Task.yield()
  }
  func testSetupPublishesTheCurrentNodeCatalog() {
    let f = make()
    f.model.setup()
    XCTAssertEqual(f.presenter.chains.count, 1)
    XCTAssertEqual(f.presenter.chains.first?.chainId, f.chain.chainId)
    XCTAssertEqual(f.events.additions, 1)
  }
  func testMissingSelectionUsesTheActiveConnectionForPresentation() {
    let f = make()
    f.registry.active = f.a
    f.model.setup()
    XCTAssertEqual(f.presenter.chains.first?.selectedNode, f.a)
    XCTAssertNil(f.model.chain.selectedNode)
  }
  func testExplicitSelectionWinsOverTheActiveConnection() {
    let f = make()
    f.registry.active = f.b
    f.model.chain = f.chain.replacingSelectedNode(f.a)
    f.model.setup()
    XCTAssertEqual(f.presenter.chains.first?.selectedNode, f.a)
  }
  func testSelectingNodePersistsTheExactChoiceBeforePublishing() async throws {
    let f = make()
    f.model.changeSelectedNode(to: f.b)
    await finish(f)
    XCTAssertEqual(try f.repository.read()?.selectedNode, f.b)
    XCTAssertEqual(f.events.updates.first?.updatedChains.first?.selectedNode, f.b)
  }
  func testSelectedNodeWriteFailureDoesNotPublishSuccess() async {
    let f = make()
    f.repository.fail = true
    f.model.changeSelectedNode(to: f.b)
    await finish(f)
    XCTAssertTrue(f.events.updates.isEmpty)
  }
  func testSelectedNodeWriteFailureNotifiesTheVisibleScreen() async {
    let f = make()
    f.repository.fail = true
    f.model.changeSelectedNode(to: f.b)
    await finish(f)
    XCTAssertEqual(f.presenter.failures, 1)
    XCTAssertTrue(f.presenter.threads.allSatisfy { $0 })
  }
  func testRemovingCustomNodePersistsTheRemainingCatalog() async throws {
    let f = make()
    f.model.removeNode(f.a)
    await finish(f)
    XCTAssertEqual(try f.repository.read()?.customNodes, [f.b])
    XCTAssertEqual(f.events.updates.count, 1)
  }
  func testRemovingSelectedNodeClearsItsSelection() async throws {
    let f = make()
    f.model.chain = f.chain.replacingSelectedNode(f.a)
    f.model.removeNode(f.a)
    await finish(f)
    XCTAssertNil(try f.repository.read()?.selectedNode)
  }
  func testRemovingAnotherNodePreservesTheSelectedOne() async throws {
    let f = make()
    f.model.chain = f.chain.replacingSelectedNode(f.b)
    f.model.removeNode(f.a)
    await finish(f)
    XCTAssertEqual(try f.repository.read()?.selectedNode, f.b)
  }
  func testRemovalWriteFailureDoesNotPublishSuccess() async {
    let f = make()
    f.repository.fail = true
    f.model.removeNode(f.a)
    await finish(f)
    XCTAssertTrue(f.events.updates.isEmpty)
  }
  func testRemovalWriteFailureExplainsTheFailureToTheScreen() async {
    let f = make()
    f.repository.fail = true
    f.model.removeNode(f.a)
    await finish(f)
    XCTAssertEqual(f.presenter.failures, 1)
  }
  func testUnrelatedChainEventDoesNotReplaceTheCatalog() async {
    let f = make()
    f.model.setup()
    let other = ChainModel(
      chainId: "different", name: "Other", nodes: [], addressPrefix: 0, icon: nil,
      selectedNode: nil, customNodes: nil, iosMinAppVersion: nil)
    f.model.processChainsUpdated(event: .init(updatedChains: [other]))
    await Task.yield()
    XCTAssertEqual(f.model.chain, f.chain)
    XCTAssertEqual(f.presenter.chains.count, 1)
  }
  func testMatchingChainEventReplacesTheVisibleCatalog() async {
    let f = make()
    let next = f.chain.replacingSelectedNode(f.b)
    f.model.processChainsUpdated(event: .init(updatedChains: [next]))
    for _ in 0..<100 {
      if !f.presenter.chains.isEmpty { break }
      try? await Task.sleep(nanoseconds: 5_000_000)
    }
    XCTAssertEqual(f.model.chain, next)
    XCTAssertEqual(f.presenter.chains.last?.selectedNode, f.b)
    XCTAssertTrue(f.presenter.threads.allSatisfy { $0 })
  }
  func testConnectionFailureIsDeliveredOnTheMainThread() async {
    let f = make()
    let model = f.model!, node = f.a
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      DispatchQueue.global().async {
        model.processFailedNodeConnection(event: FailedNodeConnectionEvent(node: node))
        continuation.resume()
      }
    }
    for _ in 0..<100 {
      if f.presenter.failures > 0 { break }
      try? await Task.sleep(nanoseconds: 5_000_000)
    }
    XCTAssertEqual(f.presenter.failures, 1)
    XCTAssertTrue(f.presenter.threads.allSatisfy { $0 })
  }
  func testReleasedInteractorRemovesItsEventSubscription() {
    let f = make()
    f.model.setup()
    f.model = nil
    XCTAssertEqual(f.events.removals, 1)
  }
}
@MainActor private final class NodePersistenceFixture {
  let a = ChainNodeModel(url: URL(string: "wss://a.example/rpc")!, name: "A", apikey: nil),
    b = ChainNodeModel(url: URL(string: "wss://b.example/rpc")!, name: "B", apikey: nil)
  lazy var chain = ChainModel(
    chainId: SoraNodeConnectionPolicy.mainnetGenesis, name: "SORA", nodes: [], addressPrefix: 69,
    icon: nil, selectedNode: nil, customNodes: [a, b], iosMinAppVersion: nil)
  let events = NodePersistenceEvents(), presenter = NodePersistencePresenter(),
    repository = NodePersistenceRepository(), manager = NodePersistenceManager(),
    registry = NodePersistenceRegistry()
  lazy var model: NodesInteractor! = {
    let m = NodesInteractor(
      settings: InMemorySettingsManager(), chain: chain,
      repository: AnyDataProviderRepository(repository), eventCenter: events,
      operationManager: manager, chainRegistry: registry)
    m.presenter = presenter
    return m
  }()
}
private final class NodePersistencePresenter: NodesInteractorOutputProtocol {
  var chains = [ChainModel](), failures = 0, threads = [Bool]()
  func didReceive(chain: ChainModel) {
    threads.append(Thread.isMainThread)
    chains.append(chain)
  }
  func showConnectionFailed() {
    threads.append(Thread.isMainThread)
    failures += 1
  }
  func restart() {}
}
private final class NodePersistenceEvents: EventCenterProtocol {
  private let lock = NSLock()
  private var events = [ChainsUpdatedEvent]()
  var additions = 0, removals = 0
  var updates: [ChainsUpdatedEvent] {
    lock.lock()
    defer { lock.unlock() }
    return events
  }
  func notify(with event: EventProtocol) {
    if let event = event as? ChainsUpdatedEvent {
      lock.lock()
      events.append(event)
      lock.unlock()
    }
  }
  func notify(with event: EventProtocol, completionOnMain: @escaping () -> Void) {
    notify(with: event)
    DispatchQueue.main.async(execute: completionOnMain)
  }
  func add(observer: EventVisitorProtocol, dispatchIn queue: DispatchQueue?) { additions += 1 }
  func remove(observer: EventVisitorProtocol) { removals += 1 }
}
private final class NodePersistenceRepository: DataProviderRepositoryProtocol {
  typealias Model = ChainModel
  let backing = InMemoryDataProviderRepository<ChainModel>()
  var fail = false
  func read() throws -> ChainModel? {
    let op = backing.fetchAllOperation(with: .init())
    op.start()
    return try op.result?.get().first
  }
  func saveOperation(
    _ updates: @escaping () throws -> [ChainModel], _ deletions: @escaping () throws -> [String]
  ) -> BaseOperation<Void> {
    let fail = fail
    return ClosureOperation {
      if fail { throw CancellationError() }
      let op = self.backing.saveOperation(updates, deletions)
      op.start()
      try op.result?.get()
    }
  }
  func saveBatchOperation(
    _ updates: @escaping () throws -> [ChainModel], _ deletions: @escaping () throws -> [String]
  ) -> BaseOperation<Void> { saveOperation(updates, deletions) }
  func fetchAllOperation(with options: RepositoryFetchOptions) -> BaseOperation<[ChainModel]> {
    backing.fetchAllOperation(with: options)
  }
  func fetchOperation(by ids: @escaping () throws -> [String], options: RepositoryFetchOptions)
    -> BaseOperation<[ChainModel]>
  { backing.fetchOperation(by: ids, options: options) }
  func fetchOperation(by id: @escaping () throws -> String, options: RepositoryFetchOptions)
    -> BaseOperation<ChainModel?>
  { backing.fetchOperation(by: id, options: options) }
  func fetchOperation(by request: RepositorySliceRequest, options: RepositoryFetchOptions)
    -> BaseOperation<[ChainModel]>
  { backing.fetchOperation(by: request, options: options) }
  func replaceOperation(_ models: @escaping () throws -> [ChainModel]) -> BaseOperation<Void> {
    backing.replaceOperation(models)
  }
  func deleteAllOperation() -> BaseOperation<Void> { backing.deleteAllOperation() }
  func fetchCountOperation() -> BaseOperation<Int> { backing.fetchCountOperation() }
}
private final class NodePersistenceManager: OperationManagerProtocol {
  let queue = OperationQueue()
  private let lock = NSLock()
  private var count = 0
  var pending: Int {
    lock.lock()
    defer { lock.unlock() }
    return count
  }
  func enqueue(operations: [Operation], in mode: OperationMode) {
    lock.lock()
    count += operations.count
    lock.unlock()
    for operation in operations {
      let existing = operation.completionBlock
      operation.completionBlock = { [self] in
        existing?()
        lock.lock()
        count -= 1
        lock.unlock()
      }
    }
    queue.addOperations(operations, waitUntilFinished: false)
  }
}

private final class NodePersistenceRegistry: ChainRegistryProtocol {
  var provider: RuntimeProviderProtocol?, ids = [String](), active: ChainNodeModel?
  var availableChainIds: Set<ChainModel.Id>? { nil }
  func getConnection(for chainId: ChainModel.Id) -> ChainConnection? { nil }
  func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol? {
    ids.append(chainId)
    return provider
  }
  func getAssetManager(for chainId: ChainModel.Id) -> AssetManagerProtocol {
    fatalError("No asset read expected")
  }
  func getChain(for chainId: ChainModel.Id) -> ChainModel? { nil }
  func getActiveNode(for chainId: ChainModel.Id) -> ChainNodeModel? { active }
  func subscribeToChians() {}
  func chainsSubscribe(
    _ target: AnyObject, runningInQueue: DispatchQueue,
    updateClosure: @escaping ([DataProviderChange<ChainModel>]) -> Void
  ) {}
  func chainsUnsubscribe(_ target: AnyObject) {}
  func performHotBoot() {}
  func performColdBoot() {}
  func syncUp() {}
}

@MainActor final class CustomNodePersistenceBoundaryTests: XCTestCase {
    private func run(_ fixture: CustomNodePersistenceFixture, name: String = "Replacement") async {
        fixture.interactor.updateCustomNode(url: fixture.replacement.url, name: name)
        for _ in 0..<400 {
            if fixture.output.finished { break }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTAssertTrue(fixture.output.finished)
    }
    func testEditingTheSelectedNodeReplacesBothCatalogEntryAndSelection() async throws {
        let f = CustomNodePersistenceFixture(edit: true, selectedOld: true); await run(f)
        let saved = try XCTUnwrap(f.chains.read())
        XCTAssertEqual(saved.selectedNode, f.replacement)
        XCTAssertEqual(saved.customNodes, [f.other, f.replacement]); XCTAssertEqual(f.output.chains, [saved])
        XCTAssertEqual(f.events.updates.first?.updatedChains, [saved])
    }
    func testEditingAnUnselectedNodePreservesTheSelectedEndpoint() async throws {
        let f = CustomNodePersistenceFixture(edit: true, selectedOld: false); await run(f)
        let saved = try XCTUnwrap(f.chains.read()); XCTAssertEqual(saved.selectedNode, f.other)
        XCTAssertEqual(saved.customNodes, [f.other, f.replacement])
    }
    func testEditingCanKeepAnExistingURLWithoutTreatingItAsAnAddedDuplicate() async throws {
        let f = CustomNodePersistenceFixture(edit: true); f.storeDuplicate()
        await run(f); XCTAssertTrue(f.output.errors.isEmpty); XCTAssertEqual(try f.chains.read()?.customNodes, [f.other, f.replacement])
    }
    func testAddingAnExistingURLIsRejectedBeforeAnyChainMutation() async throws {
        let f = CustomNodePersistenceFixture(edit: false); f.storeDuplicate(); await run(f)
        XCTAssertEqual(f.output.errors.count, 1); XCTAssertNil(try f.chains.read()); XCTAssertTrue(f.events.updates.isEmpty)
    }
    func testFailedNetworkProbeDoesNotSaveOrBroadcastTheNewNode() async throws {
        let f = CustomNodePersistenceFixture(edit: false); f.network.fail = true; await run(f)
        XCTAssertEqual(f.output.errors.count, 1); XCTAssertNil(try f.chains.read()); XCTAssertTrue(f.events.updates.isEmpty)
    }
    func testFailedRepositorySaveDoesNotPublishASuccessfulCatalog() async {
        let f = CustomNodePersistenceFixture(edit: true); f.chains.fail = true; await run(f)
        XCTAssertTrue(f.output.chains.isEmpty); XCTAssertEqual(f.output.errors.count, 1); XCTAssertTrue(f.events.updates.isEmpty)
    }
    func testAddingAnotherNodeKeepsTheCurrentSelectionAndExistingCatalog() async throws {
        let f = CustomNodePersistenceFixture(edit: false, selectedOld: true); await run(f)
        let saved = try XCTUnwrap(f.chains.read()); XCTAssertEqual(saved.selectedNode, f.old)
        XCTAssertEqual(saved.customNodes, [f.old, f.other, f.replacement])
        XCTAssertEqual(f.output.mainThreads, [true]); XCTAssertEqual(f.network.urls, [f.replacement.url])
    }
    func testFailedEditCanBeRetriedWithTheCorrectedName() async throws {
        let f = CustomNodePersistenceFixture(edit: true, selectedOld: true)
        f.chains.fail = true; await run(f); XCTAssertTrue(f.output.chains.isEmpty)
        f.chains.fail = false; f.output.errors.removeAll(); await run(f, name: "Retried name")
        let saved = try XCTUnwrap(f.chains.read()); XCTAssertEqual(saved.customNodes?.count, 2)
        XCTAssertFalse(saved.customNodes?.contains(f.old) ?? true)
        XCTAssertEqual(saved.customNodes?.first(where: { $0.url == f.replacement.url })?.name, "Retried name")
        XCTAssertEqual(f.events.updates.count, 1)
    }
}
@MainActor private final class CustomNodePersistenceFixture {
    let old = ChainNodeModel(url: URL(string: "wss://old.example.invalid/rpc")!, name: "Old", apikey: nil)
    let other = ChainNodeModel(url: URL(string: "wss://other.example.invalid/rpc")!, name: "Other", apikey: nil)
    let replacement = ChainNodeModel(url: URL(string: "wss://replacement.example.invalid/Rpc?Network=Fixture")!, name: "Replacement", apikey: nil)
    let chains = NodePersistenceRepository(), nodes = InMemoryDataProviderRepository<ChainNodeModel>(), events = NodePersistenceEvents(), output = CustomNodePersistenceOutput(), network = CustomNodePersistenceNetwork()
    let interactor: CustomNodeInteractor
    init(edit: Bool, selectedOld: Bool = false) {
        let chain = ChainModel(chainId: "isolated-test-chain", name: "Fixture", nodes: [], addressPrefix: 42, icon: nil, selectedNode: selectedOld ? old : other, customNodes: [old, other], iosMinAppVersion: nil)
        interactor = CustomNodeInteractor(settings: InMemorySettingsManager(), eventCenter: events, operationManager: OperationManager(), repository: AnyDataProviderRepository(chains), nodeRepository: AnyDataProviderRepository(nodes), substrateOperationFactory: network, chain: chain, mode: edit ? .edit(node: old) : .add, signingRouteProbe: { _ in XCTFail("Non-SORA fixture must not use signing route"); return .missing }, genesisOperationFactory: { _ in ClosureOperation { chain.chainId } })
        interactor.presenter = output
    }
    func storeDuplicate() { let node = replacement; let operation = nodes.saveOperation({ [node] }, { [] }); operation.start(); XCTAssertNoThrow(try operation.result?.get()) }
}
private final class CustomNodePersistenceNetwork: SubstrateOperationFactoryProtocol {
    var fail = false, urls = [URL]()
    func fetchChainOperation(_ url: URL) -> BaseOperation<String> { urls.append(url); let fail = fail; return ClosureOperation { if fail { throw URLError(.cannotConnectToHost) }; return "Fixture" } }
}
private final class CustomNodePersistenceOutput: CustomNodeInteractorOutputProtocol {
    var chains = [ChainModel](), errors = [AddConnectionError](), mainThreads = [Bool]()
    var finished: Bool { !chains.isEmpty || !errors.isEmpty }
    func didCompleteAdding(in chain: ChainModel) { mainThreads.append(Thread.isMainThread); chains.append(chain) }
    func didReceive(error: AddConnectionError) { mainThreads.append(Thread.isMainThread); errors.append(error) }
}
