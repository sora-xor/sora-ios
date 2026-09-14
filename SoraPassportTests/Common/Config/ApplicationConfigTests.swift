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
                       ["wss://ws.mof.sora.org", "wss://mof2.sora.org"])
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
        let mainnet = configuredChain()
        let nodes = SoraNodeConnectionPolicy.candidates(for: mainnet)
        XCTAssertEqual(nodes.map { $0.url.absoluteString }, ["wss://ws.mof.sora.org", "wss://mof2.sora.org"])
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
        let chain = configuredChain()
        let first = try pool.setupConnection(for: chain)
        XCTAssertEqual(first.url, SoraNodeConnectionPolicy.bundledMainnetNodes[0].url)
        // The same subscribed engine has moved temporarily to its fallback.
        first.reconnect(url: SoraNodeConnectionPolicy.bundledMainnetNodes[1].url)
        XCTAssertTrue(first === (try pool.setupConnection(for: chain)))
        XCTAssertEqual(factory.createdURLs.count, 1)
        XCTAssertNil(chain.selectedNode)

        let custom = ChainNodeModel(url: URL(string: "wss://custom.example")!, name: "User node", apikey: nil)
        let explicitlyChanged = configuredChain(selected: custom, custom: [custom])
        let second = try pool.setupConnection(for: explicitlyChanged)
        XCTAssertFalse(first === second)
        XCTAssertEqual(second.url, custom.url)
        XCTAssertEqual(explicitlyChanged.selectedNode, custom)
        let ignored = try pool.setupConnection(for: chain, ignoredUrl: SoraNodeConnectionPolicy.bundledMainnetNodes[0].url)
        XCTAssertEqual(ignored.url, SoraNodeConnectionPolicy.bundledMainnetNodes[1].url)
        XCTAssertThrowsError(try pool.setupConnection(for: configuredChain(chainId: "other-genesis")))
    }

    func testChainSyncKeepsNodesAndSavedChoiceWithoutRemoteWhitelist() throws {
        let repository = NodeTestRepository()
        let requestedWhitelist = expectation(description: "Optional whitelist starts after local chain is saved")
        let releaseWhitelist = DispatchSemaphore(value: 0)
        let fetchFactory = NodeTestDataFactory {
            XCTAssertEqual(repository.snapshot.count, 1)
            XCTAssertGreaterThanOrEqual(repository.snapshot.first?.nodes.count ?? 0, 2)
            requestedWhitelist.fulfill()
            return ClosureOperation {
                _ = releaseWhitelist.wait(timeout: .now() + 5)
                throw NSError(domain: "SyntheticOfflineWhitelist", code: 1)
            }
        }
        let queue = OperationQueue()
        let service = ChainSyncService(
            typesUrl: nil, assetsUrl: URL(string: "https://metadata.invalid/whitelist"),
            dataFetchFactory: fetchFactory, repository: AnyDataProviderRepository(repository),
            eventCenter: EventCenter(), operationQueue: queue
        )
        service.syncUp()
        wait(for: [requestedWhitelist], timeout: 3)
        releaseWhitelist.signal()
        queue.waitUntilAllOperationsAreFinished()
        XCTAssertEqual(repository.snapshot.count, 1)

        let custom = ChainNodeModel(url: URL(string: "wss://custom.example")!, name: "User node", apikey: nil)
        let local = configuredChain(selected: custom, custom: [custom])
        local.assets = [ChainAssetModel(assetId: AssetInfo.xor.assetId, type: .normal, asset: .xor, chain: local)]
        for unavailableWhitelist in [nil, Data("invalid metadata".utf8)] as [Data?] {
            let synced = ChainSyncService.preparedChain(
                chainId: local.chainId, addressPrefix: 69, name: "SORA", nodes: [],
                typesURL: nil, local: local, assets: [], whitelistData: unavailableWhitelist
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
            typesURL: nil, local: nil, assets: [.xor], whitelistData: nil
        )
        XCTAssertEqual(cold.nodes.count, 2)
        XCTAssertEqual(cold.assets.count, 1)
        let different = ChainSyncService.preparedChain(
            chainId: "other-genesis", addressPrefix: 42, name: "Other", nodes: [],
            typesURL: nil, local: local, assets: [], whitelistData: nil
        )
        XCTAssertTrue(different.nodes.isEmpty)
        XCTAssertNil(different.selectedNode)
        XCTAssertNil(different.customNodes)
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
        let engine = WebSocketEngine(connectionName: nil, url: url, reachabilityManager: nil, autoconnect: false)
        engine.delegate = delegate
        return engine
    }
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
