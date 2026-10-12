// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import Foundation
import RobinHood
import XCTest
@testable import SoraPassport

/// Anyone can register a SORA asset with any name and symbol. The wallet lists an
/// on-chain asset only when the asset whitelist admits it, and takes the name, symbol
/// and icon from the list. A whitelist outage must never let unvetted assets in.
final class AssetWhitelistTests: XCTestCase {
    private var directory: URL!
    private var savedNetworkAssets: [AssetInfo] = []

    private let spoofId = "0x00aa" + String(repeating: "1", count: 60)
    private let xstId = WalletAssetId.xst.rawValue

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AssetWhitelistTests-\(UUID().uuidString)", isDirectory: true)
        savedNetworkAssets = AssetManager.networkAssets
    }

    override func tearDownWithError() throws {
        AssetManager.networkAssets = savedNetworkAssets
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: - Helpers

    private final class SyncObserver: EventVisitorProtocol {
        let expectation: XCTestExpectation
        init(_ expectation: XCTestExpectation) { self.expectation = expectation }
        func processChainSyncDidComplete(event _: ChainSyncDidComplete) { expectation.fulfill() }
    }

    private final class StubDataFactory: DataOperationFactoryProtocol {
        let result: Result<Data, Error>
        private(set) var requests = 0
        init(_ result: Result<Data, Error>) { self.result = result }
        func fetchData(from _: URL) -> BaseOperation<Data> {
            requests += 1
            let result = result
            return ClosureOperation { try result.get() }
        }
    }

    private func onChain(_ id: String, symbol: String, name: String) -> AssetInfo {
        AssetInfo(id: id, symbol: symbol, chainId: "", precision: 18, icon: nil, displayName: name, visible: true)
    }

    private func entry(_ id: String, symbol: String, name: String) -> [String: Any] {
        ["address": id, "symbol": symbol, "name": name, "decimals": 18, "icon": "icon-\(symbol)"]
    }

    private func json(_ entries: [[String: Any]]) throws -> Data {
        try JSONSerialization.data(withJSONObject: entries)
    }

    private func makeStore() -> AssetWhitelistStore {
        AssetWhitelistStore(directory: directory, bundledURL: R.file.whitelistJson(), logger: nil)
    }

    /// Runs the production chain sync against an in-memory chain store.
    private func sync(
        networkAssets: [AssetInfo],
        remote: Result<Data, Error>,
        store: AssetWhitelistStore,
        repository: CoreDataRepository<ChainModel, CDChain>? = nil
    ) throws -> ChainModel {
        AssetManager.networkAssets = networkAssets
        let repository = repository ?? ChainRepositoryFactory(storageFacade: SubstrateStorageTestFacade()).createRepository()
        let eventCenter = EventCenter()
        let finished = expectation(description: "bootstrap and whitelist passes")
        finished.expectedFulfillmentCount = 2
        let observer = SyncObserver(finished)
        eventCenter.add(observer: observer, dispatchIn: nil)
        let queue = OperationQueue()
        let service = ChainSyncService(
            typesUrl: nil,
            assetsUrl: URL(string: "https://whitelist.invalid/whitelist.json"),
            dataFetchFactory: StubDataFactory(remote),
            repository: AnyDataProviderRepository(repository),
            eventCenter: eventCenter,
            operationQueue: queue,
            whitelistStore: store
        )
        service.syncUp()
        wait(for: [finished], timeout: 10)
        queue.waitUntilAllOperationsAreFinished()
        withExtendedLifetime(observer) {}

        let fetch = repository.fetchAllOperation(with: RepositoryFetchOptions())
        queue.addOperations([fetch], waitUntilFinished: true)
        guard case let .success(chains) = fetch.result else {
            throw BaseOperationError.parentOperationCancelled
        }
        return try XCTUnwrap(chains.first)
    }

    private func listed(_ chain: ChainModel) -> [String: AssetInfo] {
        Dictionary(uniqueKeysWithValues: chain.assets.map { ($0.assetId, $0.asset) })
    }

    // MARK: - Tests

    func testRemoteOutageWithoutSavedListUsesBundledListAndDropsUnvettedAssets() throws {
        let store = makeStore()
        let bundledVal = try XCTUnwrap(store.current().entry(for: WalletAssetId.val.rawValue))
        XCTAssertEqual(store.current().source, .bundled)

        let chain = try sync(
            networkAssets: [
                onChain(WalletAssetId.xor.rawValue, symbol: "XOR", name: "SORA"),
                onChain(WalletAssetId.val.rawValue, symbol: "VAL", name: "Totally VAL"),
                onChain(spoofId, symbol: "USDT", name: "Tether USD"),
                onChain(xstId, symbol: "XST", name: "SORA Synthetics")
            ],
            remote: .failure(NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)),
            store: store
        )

        let assets = listed(chain)
        XCTAssertNil(assets[spoofId], "an unlisted on-chain asset must never be listed")
        XCTAssertEqual(assets[WalletAssetId.val.rawValue]?.name, bundledVal.name)
        XCTAssertEqual(assets[WalletAssetId.val.rawValue]?.symbol, bundledVal.symbol)
        XCTAssertEqual(assets[WalletAssetId.val.rawValue]?.icon, bundledVal.icon)
        XCTAssertNotNil(assets[WalletAssetId.xor.rawValue])
        // The bundled list predates XST's listing; predefined assets stay visible.
        XCTAssertEqual(assets[xstId]?.symbol, "XST")
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path), "nothing is saved on failure")
    }

    func testRemoteOutageUsesLastGoodListStrictly() throws {
        let store = makeStore()
        let lastGood = try json([
            entry(WalletAssetId.xor.rawValue, symbol: "XOR", name: "SORA"),
            entry(WalletAssetId.val.rawValue, symbol: "VAL", name: "SORA Validator Token")
        ])
        XCTAssertNotNil(store.acceptRemote(lastGood))
        XCTAssertEqual(store.current().source, .lastKnownGood)

        let chain = try sync(
            networkAssets: [
                onChain(WalletAssetId.xor.rawValue, symbol: "XOR", name: "SORA"),
                onChain(WalletAssetId.val.rawValue, symbol: "VAL", name: "Totally VAL"),
                onChain(spoofId, symbol: "USDT", name: "Tether USD"),
                onChain(xstId, symbol: "XST", name: "SORA Synthetics")
            ],
            remote: .failure(NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)),
            store: store
        )

        let assets = listed(chain)
        XCTAssertEqual(Set(assets.keys), [WalletAssetId.xor.rawValue, WalletAssetId.val.rawValue])
        XCTAssertEqual(assets[WalletAssetId.val.rawValue]?.name, "SORA Validator Token")
        XCTAssertEqual(assets[WalletAssetId.val.rawValue]?.icon, "icon-VAL")
    }

    func testFreshRemoteListDecidesAndIsSaved() throws {
        let store = makeStore()
        let remote = try json([
            entry(WalletAssetId.xor.rawValue, symbol: "XOR", name: "SORA"),
            entry(spoofId, symbol: "NEW", name: "Newly listed token")
        ])

        let chain = try sync(
            networkAssets: [
                onChain(WalletAssetId.xor.rawValue, symbol: "XOR", name: "SORA"),
                onChain(spoofId, symbol: "USDT", name: "Tether USD"),
                onChain(WalletAssetId.val.rawValue, symbol: "VAL", name: "SORA Validator Token")
            ],
            remote: .success(remote),
            store: store
        )

        let assets = listed(chain)
        XCTAssertEqual(Set(assets.keys), [WalletAssetId.xor.rawValue, spoofId])
        XCTAssertEqual(assets[spoofId]?.symbol, "NEW")
        XCTAssertEqual(assets[spoofId]?.name, "Newly listed token")
        XCTAssertEqual(store.current().source, .lastKnownGood)
        XCTAssertNotNil(store.current().entry(for: spoofId))
    }

    func testUnusableRemoteListKeepsTheLastGoodList() throws {
        let store = makeStore()
        let lastGood = try json([entry(WalletAssetId.xor.rawValue, symbol: "XOR", name: "SORA")])
        XCTAssertNotNil(store.acceptRemote(lastGood))
        let savedURL = directory.appendingPathComponent("whitelist.json")

        for unusable in [Data(), Data("<html>502</html>".utf8), try json([]),
                         try json([entry(WalletAssetId.val.rawValue, symbol: "VAL", name: "No XOR")])] {
            XCTAssertNil(store.acceptRemote(unusable))
            XCTAssertEqual(try Data(contentsOf: savedURL), lastGood)
        }

        let chain = try sync(
            networkAssets: [
                onChain(WalletAssetId.xor.rawValue, symbol: "XOR", name: "SORA"),
                onChain(spoofId, symbol: "USDT", name: "Tether USD")
            ],
            remote: .success(try json([])),
            store: store
        )
        XCTAssertEqual(Set(listed(chain).keys), [WalletAssetId.xor.rawValue])
    }

    func testAssetsKeptFromTheLocalStoreAreFilteredToo() throws {
        let repository = ChainRepositoryFactory(storageFacade: SubstrateStorageTestFacade()).createRepository()
        let local = ChainModel(
            chainId: Chain.sora.genesisHash(), name: "SORA", nodes: [], addressPrefix: ApplicationConfig.shared.addressType,
            icon: nil, selectedNode: nil, customNodes: nil, iosMinAppVersion: nil
        )
        // An earlier build saved every on-chain asset unfiltered.
        local.assets = [
            ChainAssetModel(assetId: WalletAssetId.xor.rawValue, type: .normal,
                            asset: onChain(WalletAssetId.xor.rawValue, symbol: "XOR", name: "SORA"), chain: local),
            ChainAssetModel(assetId: spoofId, type: .normal,
                            asset: onChain(spoofId, symbol: "USDT", name: "Tether USD"), chain: local)
        ]
        let save = repository.saveOperation({ [local] }, { [] })
        OperationQueue().addOperations([save], waitUntilFinished: true)
        guard case .success = save.result else {
            return XCTFail("could not seed the local chain")
        }

        // The node is unreachable, so no on-chain asset list was loaded.
        let chain = try sync(
            networkAssets: [],
            remote: .failure(NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)),
            store: makeStore(),
            repository: repository
        )
        XCTAssertNil(listed(chain)[spoofId])
        XCTAssertNotNil(listed(chain)[WalletAssetId.xor.rawValue])
    }

    /// The first launch after an update has no saved last-good list. If it cannot reach the
    /// whitelist server, the old bundled list hides tokens it predates (VXOR, for example).
    /// The user's order and visibility for such a token must survive that pass, so the token
    /// comes back where it was, visible, once the live list arrives.
    func testBundledFirstPassKeepsTheOrderAndVisibilityOfTokensItLacks() throws {
        let xor = WalletAssetId.xor.rawValue
        let val = WalletAssetId.val.rawValue
        let pswap = WalletAssetId.pswap.rawValue
        let vxor = "0x006a271832f44c93bd8692584d85415f0f3dccef9748fecd129442c8edcb4361"
        // An explicit historical subset keeps this regression independent of
        // future updates to the application's bundled whitelist.
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let oldBundle = directory.appendingPathComponent("historical-whitelist.json")
        try json([
            entry(xor, symbol: "XOR", name: "SORA"),
            entry(val, symbol: "VAL", name: "SORA Validator Token"),
            entry(pswap, symbol: "PSWAP", name: "Polkaswap")
        ]).write(to: oldBundle)
        let store = AssetWhitelistStore(directory: directory.appendingPathComponent("cache"),
                                       bundledURL: oldBundle, logger: nil)
        XCTAssertNil(store.current().entry(for: vxor))
        let network = [
            onChain(xor, symbol: "XOR", name: "SORA"),
            onChain(val, symbol: "VAL", name: "SORA Validator Token"),
            onChain(vxor, symbol: "VXOR", name: "Vested XOR"),
            onChain(pswap, symbol: "PSWAP", name: "Polkaswap")
        ]
        let saved = AccountSettings(visibleAssetIds: [xor, val, vxor], orderedAssetIds: [xor, val, vxor, pswap])

        // First launch after the update, whitelist server unreachable.
        let firstPass = try sync(
            networkAssets: network,
            remote: .failure(NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)),
            store: store
        )
        XCTAssertNil(listed(firstPass)[vxor])
        let shown = AssetManager.arrangedAssets(firstPass.chainAssets.map(\.asset), settings: saved)
        XCTAssertEqual(shown.map(\.assetId), [xor, val, pswap])
        let selection = AssetManager.savedSelection(for: shown, keeping: saved)
        XCTAssertEqual(selection.ordered, [xor, val, vxor, pswap], "VXOR keeps its place")
        XCTAssertEqual(Set(selection.visible), [xor, val, vxor], "VXOR stays visible")
        let afterFirstPass = AccountSettings(visibleAssetIds: selection.visible, orderedAssetIds: selection.ordered)

        // The live list arrives, later in the session or on the next launch.
        let live = try json([
            entry(xor, symbol: "XOR", name: "SORA"),
            entry(val, symbol: "VAL", name: "SORA Validator Token"),
            entry(vxor, symbol: "VXOR", name: "Vested XOR"),
            entry(pswap, symbol: "PSWAP", name: "Polkaswap")
        ])
        let secondPass = try sync(networkAssets: network, remote: .success(live), store: store)
        let arranged = AssetManager.arrangedAssets(secondPass.chainAssets.map(\.asset), settings: afterFirstPass)
        XCTAssertEqual(arranged.map(\.assetId), [xor, val, vxor, pswap])
        XCTAssertEqual(arranged.first { $0.assetId == vxor }?.visible, true)
        XCTAssertEqual(arranged.first { $0.assetId == pswap }?.visible, false)
        let resaved = AssetManager.savedSelection(for: arranged, keeping: afterFirstPass)
        XCTAssertEqual(resaved.ordered, [xor, val, vxor, pswap])
        XCTAssertEqual(Set(resaved.visible), [xor, val, vxor])
    }

    /// Before the chain is loaded the asset list is empty. Saving then used to erase the
    /// user's whole order and visibility.
    func testSavingWithNoListedAssetsKeepsTheSavedChoice() {
        let saved = AccountSettings(
            visibleAssetIds: [WalletAssetId.xor.rawValue, spoofId],
            orderedAssetIds: [WalletAssetId.val.rawValue, WalletAssetId.xor.rawValue, spoofId]
        )
        let selection = AssetManager.savedSelection(for: [], keeping: saved)
        XCTAssertEqual(selection.ordered, saved.orderedAssetIds)
        XCTAssertEqual(selection.visible, saved.visibleAssetIds)

        // The user hides XOR and moves VAL last while the token is missing: their change
        // is saved, and the missing token keeps its place after XOR.
        var xorInfo = onChain(WalletAssetId.xor.rawValue, symbol: "XOR", name: "SORA")
        xorInfo.visible = false
        let edited = [xorInfo, onChain(WalletAssetId.val.rawValue, symbol: "VAL", name: "VAL")]
        let afterEdit = AssetManager.savedSelection(for: edited, keeping: saved)
        XCTAssertEqual(afterEdit.ordered, [WalletAssetId.xor.rawValue, spoofId, WalletAssetId.val.rawValue])
        XCTAssertEqual(afterEdit.visible, [WalletAssetId.val.rawValue, spoofId])
    }

    func testPredefinedAssetIds() {
        XCTAssertTrue(AssetWhitelist.isPredefinedAsset(WalletAssetId.xor.rawValue))
        XCTAssertTrue(AssetWhitelist.isPredefinedAsset(WalletAssetId.xst.rawValue))
        XCTAssertTrue(AssetWhitelist.isPredefinedAsset(WalletAssetId.kusd.rawValue))
        XCTAssertTrue(AssetWhitelist.isPredefinedAsset(WalletAssetId.kxor))
        XCTAssertFalse(AssetWhitelist.isPredefinedAsset(spoofId))
        XCTAssertFalse(AssetWhitelist.isPredefinedAsset("0x0200050000000000000000000000000000000000000000000000000000000001"))
        XCTAssertFalse(AssetWhitelist.isPredefinedAsset("0x006a271832f44c93bd8692584d85415f0f3dccef9748fecd129442c8edcb4361"))
        XCTAssertFalse(AssetWhitelist.isPredefinedAsset("0x0200"))

        XCTAssertFalse(AssetWhitelist.empty.admits(assetId: spoofId))
        XCTAssertTrue(AssetWhitelist.empty.admits(assetId: WalletAssetId.xor.rawValue))
        let strict = AssetWhitelist(entries: [], source: .lastKnownGood)
        XCTAssertFalse(strict.admits(assetId: WalletAssetId.xst.rawValue))
    }

    func testBundledListDecodes() throws {
        let bundled = try XCTUnwrap(AssetWhitelist.decode(
            try Data(contentsOf: try XCTUnwrap(R.file.whitelistJson())),
            source: .bundled
        ))
        XCTAssertGreaterThanOrEqual(bundled.count, 277)
        XCTAssertNotNil(bundled.entry(for: "0x006a271832f44c93bd8692584d85415f0f3dccef9748fecd129442c8edcb4361"),
                        "VXOR is available on a first launch without the whitelist server")
        XCTAssertNotNil(bundled.entry(for: WalletAssetId.xor.rawValue))

        let mixedCase = "0x02000A" + String(repeating: "0", count: 58)
        let list = AssetWhitelist(
            entries: [Whitelist(symbol: "TBCD", name: "TBCD", assetId: mixedCase, precision: 18, icon: "")],
            source: .remote
        )
        XCTAssertNotNil(list.entry(for: WalletAssetId.tbcd.rawValue), "ids compare case-insensitively")
    }
}
