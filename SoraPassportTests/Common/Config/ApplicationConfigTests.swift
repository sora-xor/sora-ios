import CoreData
import XCTest
import Foundation
import SSFUtils
import RobinHood
@testable import SoraPassport

class ApplicationConfigTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testConfigurationIntegrity() {
        XCTAssertNotNil(ApplicationConfig(configName: "Dev"))
        XCTAssertNotNil(ApplicationConfig(configName: "Release"))
        XCTAssertNotNil(ApplicationConfig(configName: "Test"))
        XCTAssertNotNil(ApplicationConfig(configName: "Staging"))
        XCTAssertNotNil(ApplicationConfig.shared)

        XCTAssertNoThrow(ApplicationConfig.shared.termsURL)
        XCTAssertNoThrow(ApplicationConfig.shared.version)
    }

    func testSoraNetworkEndpoints() {
        XCTAssertEqual(ApplicationConfig.shared.polkaswapIndexerURL.absoluteString, "https://pi.soramitsu.io/graphql")
        XCTAssertEqual(ApplicationConfig.shared.subqueryUrl, ApplicationConfig.shared.polkaswapIndexerURL)

        let nodes = ApplicationConfig.shared.defaultChainNodes
        XCTAssertEqual(Set(nodes.map { $0.url.absoluteString }),
                       ["wss://mof2.sora.org"])
        XCTAssertTrue(nodes.allSatisfy { $0.apikey == nil && $0.url.scheme == "wss" })
    }

    func testRemoteConfigFallsBackFromInvalidURLs() {
        let fallback = ApplicationConfig.shared.polkaswapIndexerURL
        let config = RemoteConfig(
            polkaswapIndexerUrlString: "://not-a-valid-url",
            typesUrlString: "://not-a-valid-types-url",
            defaultNodes: []
        )

        XCTAssertEqual(config.polkaswapIndexerURL, fallback)
        XCTAssertEqual(config.subqueryURL, fallback)
        XCTAssertNil(config.typesURL)
        XCTAssertTrue(config.defaultNodes.isEmpty)
    }

    func testAppConfigExplorerURLsUseSorametrics() throws {
        let root = try repositoryRoot()
        let plistURL = root.appendingPathComponent("SoraPassport/Configs/appConfig.plist")
        let data = try Data(contentsOf: plistURL)
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        let strings = collectStrings(from: plist)
        let sorametricsURLs = strings.filter {
            $0 == "https://sorametrics.org/sorav2?tab=extrinsics&q={transaction}"
        }

        XCTAssertEqual(sorametricsURLs.count, 4)
        XCTAssertFalse(strings.contains { $0.contains("subscan") })
    }

    func testCocoaPodsArtifactsAreRemovedFromProject() throws {
        let root = try repositoryRoot()
        let fileManager = FileManager.default

        XCTAssertFalse(fileManager.fileExists(atPath: root.appendingPathComponent("Podfile").path))
        XCTAssertFalse(fileManager.fileExists(atPath: root.appendingPathComponent("Podfile.lock").path))
        XCTAssertFalse(fileManager.fileExists(atPath: root.appendingPathComponent("Pods").path))
        XCTAssertFalse(fileManager.fileExists(atPath: root.appendingPathComponent("SoraPassport.xcworkspace").path))

        let projectFile = root.appendingPathComponent("SoraPassport.xcodeproj/project.pbxproj")
        let project = try String(contentsOf: projectFile)
        XCTAssertFalse(project.contains("PODS_ROOT"))
        XCTAssertFalse(project.contains("[CP]"))
        XCTAssertFalse(project.contains("Pods-"))
        XCTAssertFalse(project.contains("pod install"))
    }

    func testNodeFailoverTriesEveryCandidateBeforeOneOutageAlert() throws {
        let mainnet = configuredChain(custom: [additionalNode])
        let nodes = SoraNodeConnectionPolicy.candidates(for: mainnet)
        XCTAssertEqual(nodes.map { $0.url.absoluteString }, ["wss://mof2.sora.org", additionalNode.url.absoluteString])
        var failover = NodeConnectionFailover()
        let first = failover.failed(url: nodes[0].url, candidates: nodes)
        XCTAssertEqual(first.nextNode, nodes[1])
        XCTAssertFalse(first.shouldPresentUnavailable)
        let exhausted = failover.failed(url: nodes[1].url, candidates: nodes)
        XCTAssertEqual(exhausted.nextNode, nodes[0])
        XCTAssertTrue(exhausted.shouldPresentUnavailable)
        XCTAssertFalse(failover.failed(url: nodes[0].url, candidates: nodes).shouldPresentUnavailable)
        XCTAssertFalse(failover.failed(url: nodes[1].url, candidates: nodes).shouldPresentUnavailable)
        failover.connected()
        XCTAssertFalse(failover.failed(url: nodes[0].url, candidates: nodes).shouldPresentUnavailable)
        XCTAssertTrue(failover.failed(url: nodes[1].url, candidates: nodes).shouldPresentUnavailable)

        var singleton = NodeConnectionFailover()
        XCTAssertTrue(singleton.failed(url: nodes[0].url, candidates: [nodes[0]]).shouldPresentUnavailable)
        XCTAssertNil(singleton.failed(url: nodes[0].url, candidates: [nodes[0]]).nextNode)
        XCTAssertFalse(singleton.failed(url: nodes[0].url, candidates: []).shouldPresentUnavailable)
        XCTAssertNil(mainnet.selectedNode)
        let custom = ChainNodeModel(url: URL(string: "wss://custom.example")!, name: "User node", apikey: nil)
        let selected = configuredChain(selected: custom, custom: [custom])
        XCTAssertEqual(SoraNodeConnectionPolicy.candidates(for: selected).first, custom)
        let otherChain = configuredChain(chainId: "other-genesis", selected: custom, custom: [custom])
        XCTAssertEqual(SoraNodeConnectionPolicy.candidates(for: otherChain), [custom])
        XCTAssertTrue(SoraNodeConnectionPolicy.candidates(for: configuredChain(chainId: "other-genesis")).isEmpty)
        XCTAssertTrue(SoraNodeConnectionPolicy.candidates(for: configuredChain(prefix: 42)).isEmpty)
    }

    func testConnectionPoolPreservesActiveFallbackUntilUserChangesPreference() throws {
        let factory = NodeTestConnectionFactory()
        let pool = ConnectionPool(connectionFactory: factory)
        let chain = configuredChain(custom: [additionalNode])
        let first = try pool.setupConnection(for: chain)
        XCTAssertEqual(first.url, SoraNodeConnectionPolicy.bundledMainnetNodes[0].url)
        // The same subscribed engine has moved temporarily to its fallback.
        first.reconnect(url: additionalNode.url)
        XCTAssertTrue(first === (try pool.setupConnection(for: chain)))
        XCTAssertEqual(factory.createdURLs.count, 1)
        XCTAssertNil(chain.selectedNode)

        let custom = ChainNodeModel(url: URL(string: "wss://custom.example")!, name: "User node", apikey: nil)
        let explicitlyChanged = configuredChain(selected: custom, custom: [custom])
        let second = try pool.setupConnection(for: explicitlyChanged)
        XCTAssertTrue(first === second)
        XCTAssertEqual(second.url, custom.url)
        let recording = try XCTUnwrap(second as? NodeTestConnection)
        XCTAssertEqual(Array(recording.operations.suffix(3)), ["disconnect", "reconnect", "connect"])
        XCTAssertEqual(factory.createdURLs.count, 1)
        XCTAssertEqual(explicitlyChanged.selectedNode, custom)
        let ignored = try pool.setupConnection(for: chain, ignoredUrl: SoraNodeConnectionPolicy.bundledMainnetNodes[0].url)
        XCTAssertEqual(ignored.url, additionalNode.url)
        XCTAssertThrowsError(try pool.setupConnection(for: configuredChain(chainId: "other-genesis")))
    }

    func testChainSyncKeepsNodesAndSavedChoiceWithoutRemoteWhitelist() throws {
        let repository = NodeTestRepository()
        let requestedWhitelist = expectation(description: "Optional whitelist starts after local chain is saved")
        let releaseWhitelist = DispatchSemaphore(value: 0)
        let fetchFactory = NodeTestDataFactory {
            XCTAssertEqual(repository.snapshot.count, 1)
            XCTAssertGreaterThanOrEqual(repository.snapshot.first?.nodes.count ?? 0, 1)
            requestedWhitelist.fulfill()
            return ClosureOperation {
                _ = releaseWhitelist.wait(timeout: .now() + 5)
                throw NSError(domain: "SyntheticOfflineWhitelist", code: 1)
            }
        }
        let queue = OperationQueue()
        let whitelistDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: whitelistDirectory) }
        let whitelistStore = AssetWhitelistStore(directory: whitelistDirectory, bundledURL: R.file.whitelistJson())
        let service = ChainSyncService(
            typesUrl: nil, assetsUrl: URL(string: "https://metadata.invalid/whitelist"),
            dataFetchFactory: fetchFactory, repository: AnyDataProviderRepository(repository),
            eventCenter: EventCenter(), operationQueue: queue, whitelistStore: whitelistStore
        )
        service.syncUp()
        wait(for: [requestedWhitelist], timeout: 3)
        releaseWhitelist.signal()
        queue.waitUntilAllOperationsAreFinished()
        XCTAssertEqual(repository.snapshot.count, 1)

        let custom = ChainNodeModel(url: URL(string: "wss://custom.example")!, name: "User node", apikey: nil)
        let local = configuredChain(selected: custom, custom: [custom])
        local.assets = [ChainAssetModel(assetId: AssetInfo.xor.assetId, type: .normal, asset: .xor, chain: local)]
        // Without the remote whitelist the bundled list (or, if even that is
        // unreadable, the predefined assets) decides; XOR stays listed.
        XCTAssertNil(AssetWhitelist.decode(Data("invalid metadata".utf8), source: .remote))
        for unavailableWhitelist in [whitelistStore.current(), AssetWhitelist.empty] {
            let synced = ChainSyncService.preparedChain(
                chainId: local.chainId, addressPrefix: 69, name: "SORA", nodes: [],
                typesURL: nil, local: local, assets: [], whitelist: unavailableWhitelist
            )
            XCTAssertEqual(synced.selectedNode, custom)
            XCTAssertEqual(synced.customNodes, [custom])
            XCTAssertEqual(Set(synced.nodes.map { $0.url }), Set(SoraNodeConnectionPolicy.bundledMainnetNodes.map { $0.url }))
            XCTAssertEqual(synced.assets.map { $0.assetId }, [AssetInfo.xor.assetId])
            XCTAssertTrue(synced.assets.allSatisfy { $0.chain === synced })
            XCTAssertEqual(local.selectedNode, custom)
            XCTAssertEqual(local.customNodes, [custom])
        }
        let cold = ChainSyncService.preparedChain(
            chainId: local.chainId, addressPrefix: 69, name: "SORA", nodes: [],
            typesURL: nil, local: nil, assets: [.xor], whitelist: .empty
        )
        XCTAssertEqual(cold.nodes.count, 1)
        XCTAssertEqual(cold.assets.count, 1)
        let different = ChainSyncService.preparedChain(
            chainId: "other-genesis", addressPrefix: 42, name: "Other", nodes: [],
            typesURL: nil, local: local, assets: [], whitelist: .empty
        )
        XCTAssertTrue(different.nodes.isEmpty)
        XCTAssertNil(different.selectedNode)
        XCTAssertNil(different.customNodes)

        // PI lists mof2 under another name. The store allows one node per
        // URL, so the chain must keep exactly one entry per URL, with the
        // bundled name, plus genuinely new PI nodes.
        let renamedMof2 = ChainNodeModel(url: URL(string: "wss://mof2.sora.org")!, name: "Sora", apikey: nil)
        let extra = ChainNodeModel(url: URL(string: "wss://extra.sora.example")!, name: "Extra", apikey: nil)
        let merged = ChainSyncService.preparedChain(
            chainId: local.chainId, addressPrefix: 69, name: "SORA", nodes: [renamedMof2, extra],
            typesURL: nil, local: nil, assets: [.xor], whitelist: .empty
        )
        XCTAssertEqual(merged.nodes.count, 2)
        XCTAssertEqual(Set(merged.nodes.map(\.url)).count, merged.nodes.count)
        XCTAssertEqual(
            merged.nodes.first { $0.url == renamedMof2.url }?.name,
            "SORA Ministry of Finance 2"
        )
        XCTAssertTrue(merged.nodes.contains(extra))
    }

    /// Node rows have a store-wide unique URL. Chains saved by older releases
    /// (a custom node at a URL 3.9.0 bundles, a selected node under PI's
    /// name) must save again without a constraint conflict, and the next sync
    /// must see no change.
    func testChainSyncDropsCompromisedCustomNodeFromOlderRelease() throws {
        let store = try ChainTestStore()
        defer { store.remove() }
        let piMof2 = ChainNodeModel(url: URL(string: "wss://mof2.sora.org")!, name: "Sora", apikey: nil)
        let bundledMof2 = SoraNodeConnectionPolicy.bundledMainnetNodes[0]
        let customMof = ChainNodeModel(
            url: URL(string: "wss://ws.mof.sora.org")!, name: "My node", apikey: nil
        )

        // 3.8.6 saved PI's mof2 as "Sora" and selected it; PI did not list
        // ws.mof.sora.org, so the user added it as a custom node.
        try store.save(store.legacyChain(nodes: [piMof2], selected: piMof2, custom: [customMof]))

        let upgraded = store.sync(try store.stored(), piNodes: [piMof2])
        XCTAssertEqual(upgraded.nodes, [bundledMof2])
        XCTAssertTrue(upgraded.customNodes?.isEmpty ?? true)
        XCTAssertEqual(upgraded.selectedNode, bundledMof2)
        XCTAssertNoThrow(try store.save(upgraded))
        let afterUpgrade = try store.stored()
        XCTAssertEqual(store.nodeState(afterUpgrade), store.nodeState(upgraded))
        // The next sync finds no node change, so it does not rewrite the
        // chain and restart its connection.
        XCTAssertEqual(
            store.nodeState(store.sync(afterUpgrade, piNodes: [piMof2])),
            store.nodeState(afterUpgrade)
        )
    }

    /// An older release saved a selected node that was in neither list on its
    /// own row. When 3.9.0 bundles that URL, the row is reused.
    func testChainSyncReusesAStandaloneSelectedNodeRow() throws {
        let store = try ChainTestStore()
        defer { store.remove() }
        let piMof2 = additionalNode
        let bundledMof = SoraNodeConnectionPolicy.bundledMainnetNodes[0]
        let bundledMof2 = additionalNode
        let standalone = ChainNodeModel(url: bundledMof.url, name: "Old name", apikey: nil)

        try store.save(store.legacyChain(nodes: [piMof2], selected: standalone, custom: nil))

        let resynced = store.sync(try store.stored(), piNodes: [piMof2])
        XCTAssertEqual(Set(resynced.nodes), [bundledMof, bundledMof2])
        XCTAssertEqual(resynced.selectedNode, bundledMof)
        XCTAssertNoThrow(try store.save(resynced))
        let afterResync = try store.stored()
        XCTAssertEqual(store.nodeState(afterResync), store.nodeState(resynced))
        XCTAssertEqual(
            store.nodeState(store.sync(afterResync, piNodes: [piMof2])),
            store.nodeState(afterResync)
        )
    }

    func testChainSyncSavesOneNodePerURLWhenTheIndexerNamesABundledNodeDifferently() throws {
        // The Polkaswap indexer's mobile config names mof2 "Sora", while the
        // bundled list names it differently. A custom node at a bundled URL
        // stays the user's custom node and is not saved again as a default.
        let indexerNode = ChainNodeModel(url: URL(string: "wss://mof2.sora.org")!, name: "Sora", apikey: nil)
        let customCopy = ChainNodeModel(url: indexerNode.url, name: "My node", apikey: nil)
        let chain = ChainSyncService.preparedChain(
            chainId: SoraNodeConnectionPolicy.mainnetGenesis, addressPrefix: 69, name: "SORA",
            nodes: [indexerNode], typesURL: nil, local: configuredChain(custom: [customCopy]),
            assets: [], whitelist: .empty
        )

        XCTAssertTrue(chain.nodes.isEmpty)
        XCTAssertEqual(chain.customNodes, [customCopy])
        let saved = try XCTUnwrap(try savedChains([chain]).first)
        XCTAssertEqual(saved.nodes, chain.nodes)
        XCTAssertEqual(saved.customNodes, chain.customNodes)

        // A chain holding two entries for one URL used to fail every save on
        // CDChainNode.url's uniqueness constraint, which left the wallet
        // without a connection. The chain mapper now reuses the row that has
        // the URL, so such a chain saves with one row per URL.
        let duplicated = ChainModel(
            chainId: SoraNodeConnectionPolicy.mainnetGenesis, name: "SORA",
            nodes: Set(SoraNodeConnectionPolicy.bundledMainnetNodes + [indexerNode]), addressPrefix: 69,
            icon: nil, selectedNode: nil, customNodes: nil, iosMinAppVersion: nil
        )
        let savedDuplicate = try XCTUnwrap(try savedChains([duplicated]).first)
        XCTAssertEqual(Set(savedDuplicate.nodes.map(\.url)).count, savedDuplicate.nodes.count)
        XCTAssertEqual(
            Set(savedDuplicate.nodes.map(\.url)),
            Set(SoraNodeConnectionPolicy.bundledMainnetNodes.map(\.url))
        )
    }

    /// Uniqueness constraints are enforced by SQLite stores only.
    private final class TemporaryChainStore: SoraPassport.StorageFacadeProtocol {
        let databaseService: CoreDataServiceProtocol

        init(directory: URL) {
            let settings = CoreDataPersistentSettings(databaseDirectory: directory,
                                                      databaseName: "SubstrateDataModel.sqlite",
                                                      incompatibleModelStrategy: .removeStore)
            databaseService = CoreDataService(configuration: CoreDataServiceConfiguration(
                modelURL: Bundle.main.url(forResource: "SubstrateDataModel", withExtension: "momd")!,
                storageType: .persistent(settings: settings)
            ))
        }

        func createRepository<T, U>(filter: NSPredicate?,
                                    sortDescriptors: [NSSortDescriptor],
                                    mapper: AnyCoreDataMapper<T, U>) -> CoreDataRepository<T, U>
        where T: Identifiable, U: NSManagedObject {
            CoreDataRepository(databaseService: databaseService, mapper: mapper,
                               filter: filter, sortDescriptors: sortDescriptors)
        }
    }

    private func savedChains(_ chains: [ChainModel]) throws -> [ChainModel] {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChainStore-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = ChainRepositoryFactory(storageFacade: TemporaryChainStore(directory: directory))
            .createRepository()
        let save = repository.saveOperation({ chains }, { [] })
        let fetch = repository.fetchAllOperation(with: RepositoryFetchOptions())
        fetch.addDependency(save)
        OperationQueue().addOperations([save, fetch], waitUntilFinished: true)
        try save.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        return try fetch.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
    }

    private var additionalNode: ChainNodeModel {
        ChainNodeModel(url: URL(string: "wss://fallback.example")!, name: "Test fallback", apikey: nil)
    }

    func testBundledSchemaFetchReadsTheReviewedResourceWithoutURLSession() throws {
        let url = try XCTUnwrap(ApplicationConfig.shared.commonTypesURL)
        let expected = try Data(contentsOf: url)
        let operation = DataOperationFactory().fetchData(from: url)
        operation.start()
        let actual = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        XCTAssertEqual(actual, expected)
    }

    func testSchemasStayBundledAndRemoteSchemasCannotOverrideThem() throws {
        let bundled = try XCTUnwrap(ApplicationConfig.shared.commonTypesURL)
        XCTAssertTrue(bundled.isFileURL)
        XCTAssertEqual(bundled.lastPathComponent, "runtime-sora.json")
        XCTAssertNil(ApplicationConfig.shared.nodesURL)
        XCTAssertEqual(Chain.sora.typeDefNetworkFileURL(), bundled)
        XCTAssertEqual(RemoteConfig().typesURL, bundled)
        XCTAssertNil(RemoteConfig(typesUrlString: "https://unreviewed.example/types.json").typesURL)
        XCTAssertNil(RemoteConfig(typesUrlString: "file:///tmp/types.json").typesURL)
    }

    func testCompromisedNodesCannotReturnThroughSavedOrRemoteConfiguration() throws {
        for host in ["ws.mof.sora.org", "MOF.SORA.ORG", "mof3.sora.org.", "207.254.29.218"] {
            let url = try XCTUnwrap(URL(string: "wss://\(host)"))
            let node = ChainNodeModel(url: url, name: "Rejected", apikey: nil)
            XCTAssertFalse(SoraNodeConnectionPolicy.isAllowedEndpoint(url))
            XCTAssertTrue(RemoteConfig(defaultNodes: [node]).defaultNodes.isEmpty)
            let saved = configuredChain(selected: node, custom: [node])
            XCTAssertFalse(SoraNodeConnectionPolicy.candidates(for: saved).contains { $0.url == url })
            XCTAssertThrowsError(try Sora2BoundedHTTPJSONRPCEngine.httpEndpoint(for: url))
            let prepared = ChainSyncService.preparedChain(
                chainId: saved.chainId, addressPrefix: 69, name: "SORA", nodes: [node],
                typesURL: nil, local: saved, assets: [], whitelist: .empty
            )
            XCTAssertNil(prepared.selectedNode)
            XCTAssertTrue(prepared.customNodes?.isEmpty ?? true)
            XCTAssertFalse(prepared.nodes.contains { $0.url == url })
        }
        XCTAssertTrue(SoraNodeConnectionPolicy.isAllowedEndpoint(additionalNode.url))
    }

    private func configuredChain(
        chainId: String = SoraNodeConnectionPolicy.mainnetGenesis,
        prefix: UInt16 = 69,
        selected: ChainNodeModel? = nil,
        custom: Set<ChainNodeModel>? = nil
    ) -> ChainModel {
        ChainModel(chainId: chainId, name: "SORA", nodes: [], addressPrefix: prefix,
                   icon: nil, selectedNode: selected, customNodes: custom, iosMinAppVersion: nil)
    }

    private func repositoryRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let fileManager = FileManager.default

        while directory.path != "/" {
            if fileManager.fileExists(atPath: directory.appendingPathComponent("SoraPassport.xcodeproj").path) {
                return directory
            }

            directory.deleteLastPathComponent()
        }

        throw NSError(domain: "ApplicationConfigTests", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Unable to locate repository root from \(#filePath)"
        ])
    }

    private func collectStrings(from value: Any) -> [String] {
        if let string = value as? String {
            return [string]
        }

        if let array = value as? [Any] {
            return array.flatMap(collectStrings)
        }

        if let dictionary = value as? [String: Any] {
            return dictionary.values.flatMap(collectStrings)
        }

        return []
    }
}

private final class NodeTestConnectionFactory: ConnectionFactoryProtocol {
    var createdURLs: [URL] = []
    func createConnection(for url: URL, delegate: WebSocketEngineDelegate) -> ChainConnection {
        createdURLs.append(url)
        return NodeTestConnection(url: url)
    }
}

private final class NodeTestConnection: ChainConnection {
    var url: URL?
    var state: WebSocketEngine.State = .notConnected
    var ranking: [ConnectionRank] = []
    var pendingEngineRequests: [JSONRPCRequest] = []
    var operations: [String] = []
    init(url: URL) { self.url = url }
    func set(ranking: [ConnectionRank]) { self.ranking = ranking }
    func disconnectIfNeeded() { operations.append("disconnect"); state = .notConnected }
    func reconnect(url: URL) { operations.append("reconnect"); self.url = url }
    func connectIfNeeded() { operations.append("connect"); state = .connecting(attempt: 0) }
    func callMethod<P: Codable, T: Decodable>(
        _ method: String, params: P?, options: JSONRPCOptions,
        completion closure: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 { 0 }
    func subscribe<P: Codable, T: Decodable>(
        _ method: String, params: P?, updateClosure: @escaping (T) -> Void,
        failureClosure: @escaping (Error, Bool) -> Void
    ) throws -> UInt16 { 0 }
    func cancelForIdentifier(_ identifier: UInt16) {}
    func generateRequestId() -> UInt16 { 0 }
    func addSubscription(_ subscription: JSONRPCSubscribing) {}
    func unsubsribe(_ identifier: UInt16) throws {}
}

private final class NodeTestDataFactory: DataOperationFactoryProtocol {
    let makeOperation: () -> BaseOperation<Data>
    init(_ makeOperation: @escaping () -> BaseOperation<Data>) { self.makeOperation = makeOperation }
    func fetchData(from url: URL) -> BaseOperation<Data> { makeOperation() }
}

private final class NodeTestRepository: DataProviderRepositoryProtocol {
    typealias Model = ChainModel
    private let lock = NSLock()
    private var stored: [ChainModel] = []
    var snapshot: [ChainModel] {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }
    func fetchAllOperation(with options: RepositoryFetchOptions) -> BaseOperation<[ChainModel]> {
        ClosureOperation { self.snapshot }
    }
    func saveOperation(_ updates: @escaping () throws -> [ChainModel],
                       _ deletions: @escaping () throws -> [String]) -> BaseOperation<Void> {
        ClosureOperation {
            let changed = try updates()
            let removed = try deletions()
            self.lock.lock()
            defer { self.lock.unlock() }
            self.stored.removeAll { old in removed.contains(old.chainId) || changed.contains(where: { $0.chainId == old.chainId }) }
            self.stored.append(contentsOf: changed)
        }
    }
    func saveBatchOperation(_ updates: @escaping () throws -> [ChainModel],
                            _ deletions: @escaping () throws -> [String]) -> BaseOperation<Void> {
        saveOperation(updates, deletions)
    }
    func fetchOperation(by ids: @escaping () throws -> [String], options: RepositoryFetchOptions) -> BaseOperation<[ChainModel]> {
        ClosureOperation { let selected = try ids(); return self.snapshot.filter { selected.contains($0.chainId) } }
    }
    func fetchOperation(by id: @escaping () throws -> String, options: RepositoryFetchOptions) -> BaseOperation<ChainModel?> {
        ClosureOperation { let selected = try id(); return self.snapshot.first { $0.chainId == selected } }
    }
    func fetchOperation(by request: RepositorySliceRequest, options: RepositoryFetchOptions) -> BaseOperation<[ChainModel]> {
        fetchAllOperation(with: options)
    }
    func replaceOperation(_ models: @escaping () throws -> [ChainModel]) -> BaseOperation<Void> {
        saveOperation(models, { self.snapshot.map { $0.chainId } })
    }
    func deleteAllOperation() -> BaseOperation<Void> { replaceOperation { [] } }
    func fetchCountOperation() -> BaseOperation<Int> { ClosureOperation { self.snapshot.count } }
}

/// A chain store on disk (SQLite enforces the node URL uniqueness constraint
/// the way the app's store does).
private final class ChainTestStore {
    let directory: URL
    let repository: CoreDataRepository<ChainModel, CDChain>

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let modelURL = try XCTUnwrap(
            Bundle.main.url(forResource: "SubstrateDataModel", withExtension: "momd")
        )
        let service = CoreDataService(configuration: CoreDataServiceConfiguration(
            modelURL: modelURL,
            storageType: .persistent(settings: CoreDataPersistentSettings(
                databaseDirectory: directory,
                databaseName: "Chains.sqlite",
                incompatibleModelStrategy: .removeStore
            ))
        ))
        repository = CoreDataRepository(
            databaseService: service,
            mapper: AnyCoreDataMapper(ChainModelMapper())
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }

    func legacyChain(
        nodes: Set<ChainNodeModel>,
        selected: ChainNodeModel?,
        custom: Set<ChainNodeModel>?
    ) -> ChainModel {
        let chain = ChainModel(
            chainId: SoraNodeConnectionPolicy.mainnetGenesis, name: "SORA", nodes: nodes,
            addressPrefix: 69, icon: nil, selectedNode: selected, customNodes: custom,
            iosMinAppVersion: nil
        )
        chain.assets = [ChainAssetModel(
            assetId: AssetInfo.xor.assetId, type: .normal, asset: .xor, chain: chain
        )]
        return chain
    }

    func save(_ chain: ChainModel) throws {
        let operation = repository.saveOperation({ [chain] }, { [] })
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        switch operation.result {
        case .success:
            return
        case let .failure(error):
            throw error
        case .none:
            throw BaseOperationError.parentOperationCancelled
        }
    }

    func stored() throws -> ChainModel {
        let operation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        guard case let .success(chains) = operation.result else {
            throw BaseOperationError.parentOperationCancelled
        }
        return try XCTUnwrap(chains.first)
    }

    struct NodeState: Equatable {
        let nodes: Set<ChainNodeModel>
        let selected: ChainNodeModel?
        let custom: Set<ChainNodeModel>
    }

    func nodeState(_ chain: ChainModel) -> NodeState {
        NodeState(nodes: chain.nodes, selected: chain.selectedNode, custom: chain.customNodes ?? [])
    }

    func sync(_ local: ChainModel, piNodes: Set<ChainNodeModel>) -> ChainModel {
        ChainSyncService.preparedChain(
            chainId: SoraNodeConnectionPolicy.mainnetGenesis,
            addressPrefix: 69,
            name: "SORA",
            nodes: piNodes,
            typesURL: nil,
            local: local,
            assets: [.xor],
            whitelist: .empty
        )
    }
}
