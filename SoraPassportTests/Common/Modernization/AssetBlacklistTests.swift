// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

import Foundation
import RobinHood
import SoraUIKit
import UIKit
import XCTest
@testable import SoraPassport

/// The official Polkaswap token blacklist hides assets from the portfolio, the asset lists and
/// the swap pickers. An undecodable list never un-hides anything, and a balance the wallet
/// already holds in a blacklisted token stays in its full asset list, marked hidden.
@MainActor
final class AssetBlacklistTests: XCTestCase {
    private var directory: URL!
    private var savedNetworkAssets: [AssetInfo] = []

    private let liveIds = [
        "0x00b3e666ba302d608b659994fab741ba78904161e158f1421db05318588fe017",
        "0x00dadad1a20270d9246dd7ccc92730f32565baa4265cf30a23ebd15c9235e818"
    ]
    private let tokenId = "0x00aa" + String(repeating: "1", count: 60)
    private let otherId = "0x00bb" + String(repeating: "2", count: 60)
    private let xorId = WalletAssetId.xor.rawValue
    private let valId = WalletAssetId.val.rawValue

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AssetBlacklistTests-\(UUID().uuidString)", isDirectory: true)
        savedNetworkAssets = AssetManager.networkAssets
    }

    override func tearDownWithError() throws {
        AssetManager.networkAssets = savedNetworkAssets
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: - Helpers

    private func json(_ object: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: object)
    }

    private func makeStore(
        bundledURL: URL? = R.file.blacklistJson(),
        notificationCenter: NotificationCenter = NotificationCenter()
    ) -> AssetBlacklistStore {
        AssetBlacklistStore(directory: directory, bundledURL: bundledURL,
                            notificationCenter: notificationCenter, logger: nil)
    }

    private var savedURL: URL { directory.appendingPathComponent("blacklist.json") }

    private func asset(_ id: String, symbol: String, visible: Bool = true) -> AssetInfo {
        AssetInfo(id: id, symbol: symbol, chainId: "", precision: 18, icon: nil, displayName: symbol, visible: visible)
    }

    private func row(_ asset: AssetInfo, balance: Decimal, unavailable: Bool = false) -> AssetListItem {
        let item = AssetListItem(
            assetInfo: asset,
            assetViewModel: AssetViewModel(identifier: asset.identifier, title: asset.name,
                                           subtitle: "\(balance) \(asset.symbol)", fiatText: "$1",
                                           isFavorite: asset.visible),
            balance: balance
        )
        item.balanceUnavailable = unavailable
        return item
    }

    // MARK: - Format

    /// The live list (and the bundled copy of it) is a JSON array of asset id strings.
    func testBundledListIsTheLiveFormat() throws {
        let data = try Data(contentsOf: try XCTUnwrap(R.file.blacklistJson()))
        let bundled = try XCTUnwrap(AssetBlacklist.decode(data, source: .bundled))
        XCTAssertEqual(bundled.source, .bundled)
        XCTAssertGreaterThanOrEqual(bundled.count, 2)
        for id in liveIds {
            XCTAssertTrue(bundled.hides(assetId: id))
        }

        let messy = try XCTUnwrap(AssetBlacklist.decode(
            Data("[\" \(tokenId.uppercased().replacingOccurrences(of: "0X", with: "0x")) \"]".utf8), source: .remote))
        XCTAssertEqual(messy.assetIds, [tokenId], "ids are trimmed and compared case-insensitively")
    }

    /// Anything that is not an array of id strings is not a list: the last good one stays.
    func testUndecodableDocumentsAreRejected() throws {
        let whitelist = try Data(contentsOf: try XCTUnwrap(R.file.whitelistJson()))
        let unusable: [Data] = [
            Data(),
            Data("<html>502 Bad Gateway</html>".utf8),
            Data("null".utf8),
            Data("\"\(tokenId)\"".utf8),
            try json(["blacklist": [tokenId]]),
            try json([tokenId, 7] as [Any]),
            Data("[null]".utf8),
            try json([[tokenId]]),
            try json([["address": tokenId, "symbol": "BAD"]]),
            try json(["not an asset id", "0x1234"]),
            // The whitelist served in its place must never hide every listed token.
            whitelist
        ]
        for data in unusable {
            XCTAssertNil(AssetBlacklist.decode(data, source: .remote),
                         String(data: data.prefix(80), encoding: .utf8) ?? "binary")
        }
    }

    /// An asset id is "0x" and 64 ASCII hex digits: 66 UTF-8 bytes. Look-alike digits from other
    /// scripts (`Character.isHexDigit` accepts fullwidth ones) never make an id, so a list made
    /// only of them is not a list and cannot replace the last good one.
    func testOnlyAsciiHexIdsAreAssetIds() throws {
        let fullwidthDigits = "0x" + String(repeating: "\u{FF11}", count: 64)
        let fullwidthLetters = "0x" + String(repeating: "\u{FF41}", count: 64)
        let arabicIndic = "0x" + String(repeating: "\u{0661}", count: 64)
        let fullwidthPrefix = "\u{FF10}\u{FF58}" + String(repeating: "1", count: 64)
        let combining = "0x" + String(repeating: "1", count: 63) + "a\u{0301}"
        let tooLong = tokenId + "0"
        let impostors = [fullwidthDigits, fullwidthLetters, arabicIndic, fullwidthPrefix, combining, tooLong,
                         "0x" + String(repeating: "g", count: 64)]
        for impostor in impostors {
            XCTAssertNil(AssetBlacklist.decode(try json([impostor]), source: .remote), impostor)
        }
        let mixed = try XCTUnwrap(AssetBlacklist.decode(try json(impostors + [tokenId]), source: .remote))
        XCTAssertEqual(mixed.assetIds, [tokenId], "only the real id is kept")

        let store = makeStore()
        let lastGood = try json([tokenId])
        XCTAssertNotNil(store.acceptRemote(lastGood))
        XCTAssertNil(store.acceptRemote(try json([fullwidthDigits])))
        XCTAssertEqual(store.current().assetIds, [tokenId])
        XCTAssertEqual(try Data(contentsOf: savedURL), lastGood)
        XCTAssertEqual(makeStore().current().assetIds, [tokenId], "and after a restart")
    }

    func testEmptyListIsTheListsOwnStatementAndStrayStringsAreSkipped() throws {
        let empty = try XCTUnwrap(AssetBlacklist.decode(try json([String]()), source: .remote))
        XCTAssertEqual(empty.count, 0)
        XCTAssertEqual(empty.source, .remote)

        let mixed = try XCTUnwrap(AssetBlacklist.decode(try json([tokenId, "0xabc", "ETH", tokenId]), source: .remote))
        XCTAssertEqual(mixed.assetIds, [tokenId])
    }

    // MARK: - Admission

    func testHidesListedAssetsButNeverXor() {
        let blacklist = AssetBlacklist(assetIds: [tokenId.uppercased(), xorId, valId], source: .remote)
        XCTAssertTrue(blacklist.hides(assetId: tokenId))
        XCTAssertTrue(blacklist.hides(assetId: valId))
        XCTAssertFalse(blacklist.hides(assetId: otherId))
        XCTAssertFalse(blacklist.hides(assetId: xorId), "XOR pays every fee and is always shown")
        XCTAssertFalse(AssetBlacklist.empty.hides(assetId: tokenId))

        XCTAssertEqual(blacklist.pickable([otherId, tokenId, xorId, valId]), [otherId, xorId])

        XCTAssertTrue(blacklist.keepsRow(assetId: tokenId, balance: 5, balanceUnavailable: false), "held")
        XCTAssertTrue(blacklist.keepsRow(assetId: tokenId, balance: 0, balanceUnavailable: true), "maybe held")
        XCTAssertFalse(blacklist.keepsRow(assetId: tokenId, balance: 0, balanceUnavailable: false), "not held")
        XCTAssertTrue(blacklist.keepsRow(assetId: otherId, balance: 0, balanceUnavailable: false), "not blacklisted")
    }

    // MARK: - Sources and caching

    func testWithoutASavedListTheBundledListIsInForce() throws {
        let store = makeStore()
        XCTAssertEqual(store.current().source, .bundled)
        XCTAssertTrue(store.current().hides(assetId: liveIds[0]))

        let bare = AssetBlacklistStore(directory: directory.appendingPathComponent("bare"), bundledURL: nil, logger: nil)
        XCTAssertEqual(bare.current(), .empty, "with no list at all nothing is hidden")
    }

    func testAcceptedRemoteListIsUsedAtOnceAndSavedForTheNextLaunch() throws {
        let center = NotificationCenter()
        var changes = 0
        let observer = center.addObserver(forName: AssetBlacklistStore.didChange, object: nil, queue: nil) { _ in
            changes += 1
        }
        defer { center.removeObserver(observer) }
        let store = makeStore(notificationCenter: center)
        XCTAssertEqual(store.current().source, .bundled)

        let remote = try json([tokenId])
        let accepted = try XCTUnwrap(store.acceptRemote(remote))
        XCTAssertEqual(accepted.source, .remote)
        XCTAssertEqual(store.current(), accepted)
        XCTAssertFalse(store.current().hides(assetId: liveIds[0]), "the remote list replaces the bundled one")
        XCTAssertEqual(try Data(contentsOf: savedURL), remote)
        XCTAssertEqual(changes, 1)

        XCTAssertNotNil(store.acceptRemote(remote))
        XCTAssertEqual(changes, 1, "the same list again changes nothing")

        let nextLaunch = makeStore()
        XCTAssertEqual(nextLaunch.current().source, .lastKnownGood)
        XCTAssertEqual(nextLaunch.current().assetIds, [tokenId])
    }

    func testUnusableRemoteListKeepsTheLastGoodList() throws {
        let store = makeStore()
        // No saved list yet: the bundled list stays in force, never an empty one.
        XCTAssertNil(store.acceptRemote(Data("<html>".utf8)))
        XCTAssertEqual(store.current().source, .bundled)
        XCTAssertFalse(FileManager.default.fileExists(atPath: savedURL.path), "nothing is saved on failure")

        let lastGood = try json([tokenId, otherId])
        XCTAssertNotNil(store.acceptRemote(lastGood))
        for unusable in [Data(), Data("{}".utf8), try json([["address": valId]]), try json(["junk"])] {
            XCTAssertNil(store.acceptRemote(unusable))
            XCTAssertEqual(try Data(contentsOf: savedURL), lastGood)
            XCTAssertEqual(store.current().assetIds, [tokenId, otherId])
        }
        XCTAssertEqual(makeStore().current().assetIds, [tokenId, otherId])
    }

    func testDamagedSavedListFallsBackToTheBundledList() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("[\"0x00".utf8).write(to: savedURL)
        let store = makeStore()
        XCTAssertEqual(store.current().source, .bundled)
        XCTAssertTrue(store.current().hides(assetId: liveIds[1]))
    }

    // MARK: - Fetching

    private final class RoutedDataFactory: DataOperationFactoryProtocol {
        let routes: [URL: Result<Data, Error>]
        private let lock = NSLock()
        private var storedRequests: [URL] = []
        init(_ routes: [URL: Result<Data, Error>]) { self.routes = routes }
        var requests: [URL] {
            lock.lock()
            defer { lock.unlock() }
            return storedRequests
        }

        func fetchData(from url: URL) -> BaseOperation<Data> {
            lock.lock()
            storedRequests.append(url)
            lock.unlock()
            let result = routes[url] ?? .failure(NSError(domain: NSURLErrorDomain, code: NSURLErrorBadURL))
            return ClosureOperation { try result.get() }
        }
    }

    private final class SyncObserver: EventVisitorProtocol {
        let expectation: XCTestExpectation
        init(_ expectation: XCTestExpectation) { self.expectation = expectation }
        func processChainSyncDidComplete(event _: ChainSyncDidComplete) { expectation.fulfill() }
    }

    private func waitUntil(_ what: String, _ condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(10)
        while !condition() && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        XCTAssertTrue(condition(), what)
    }

    /// The blacklist is fetched with the whitelist and decides only what lists show: the chain
    /// store keeps the blacklisted token, so its balance is still read and can be reached.
    func testChainSyncFetchesTheBlacklistAndTheChainKeepsTheToken() throws {
        let whitelistURL = URL(string: "https://whitelist.invalid/whitelist.json")!
        let blacklistURL = URL(string: "https://whitelist.invalid/blacklist.json")!
        let whitelist = try json([
            ["address": xorId, "symbol": "XOR", "name": "SORA", "decimals": 18, "icon": ""] as [String: Any],
            ["address": tokenId, "symbol": "TKN", "name": "Token", "decimals": 18, "icon": ""] as [String: Any]
        ])
        let factory = RoutedDataFactory([whitelistURL: .success(whitelist), blacklistURL: .success(try json([tokenId]))])
        let blacklistStore = makeStore()
        AssetManager.networkAssets = [asset(xorId, symbol: "XOR"), asset(tokenId, symbol: "TKN")]

        let repository = ChainRepositoryFactory(storageFacade: SubstrateStorageTestFacade()).createRepository()
        let eventCenter = EventCenter()
        let finished = expectation(description: "bootstrap and whitelist passes")
        finished.expectedFulfillmentCount = 2
        let observer = SyncObserver(finished)
        eventCenter.add(observer: observer, dispatchIn: nil)
        let queue = OperationQueue()
        let service = ChainSyncService(
            typesUrl: nil, assetsUrl: whitelistURL, dataFetchFactory: factory,
            repository: AnyDataProviderRepository(repository), eventCenter: eventCenter, operationQueue: queue,
            whitelistStore: AssetWhitelistStore(directory: directory.appendingPathComponent("whitelist"),
                                                bundledURL: nil, logger: nil),
            blacklistUrl: blacklistURL, blacklistStore: blacklistStore
        )
        service.syncUp()
        wait(for: [finished], timeout: 10)
        waitUntil("the blacklist was accepted") { blacklistStore.current().source == .remote }
        queue.waitUntilAllOperationsAreFinished()
        withExtendedLifetime(observer) {}

        XCTAssertTrue(blacklistStore.current().hides(assetId: tokenId))
        XCTAssertEqual(Set(factory.requests), [whitelistURL, blacklistURL])
        let fetch = repository.fetchAllOperation(with: RepositoryFetchOptions())
        queue.addOperations([fetch], waitUntilFinished: true)
        guard case let .success(chains) = fetch.result else {
            return XCTFail("could not read the chain store")
        }
        let chain = try XCTUnwrap(chains.first)
        XCTAssertEqual(Set(chain.assets.map(\.assetId)), [xorId, tokenId],
                       "the blacklist never takes a token out of the chain store")
    }

    func testChainSyncWithoutABlacklistURLFetchesOnlyTheWhitelist() throws {
        let whitelistURL = URL(string: "https://whitelist.invalid/whitelist.json")!
        let factory = RoutedDataFactory([:])
        let eventCenter = EventCenter()
        // The bootstrap pass, then the end of the sync after the failed whitelist request.
        let finished = expectation(description: "bootstrap pass and sync end")
        finished.expectedFulfillmentCount = 2
        let observer = SyncObserver(finished)
        eventCenter.add(observer: observer, dispatchIn: nil)
        let queue = OperationQueue()
        let service = ChainSyncService(
            typesUrl: nil, assetsUrl: whitelistURL, dataFetchFactory: factory,
            repository: AnyDataProviderRepository(
                ChainRepositoryFactory(storageFacade: SubstrateStorageTestFacade()).createRepository()),
            eventCenter: eventCenter, operationQueue: queue,
            whitelistStore: AssetWhitelistStore(directory: directory, bundledURL: nil, logger: nil),
            blacklistStore: makeStore()
        )
        service.syncUp()
        wait(for: [finished], timeout: 10)
        queue.waitUntilAllOperationsAreFinished()
        withExtendedLifetime(observer) {}
        XCTAssertEqual(factory.requests, [whitelistURL])
    }

    // MARK: - Held balances stay reachable

    /// The full asset list keeps a blacklisted asset the wallet holds, marked hidden and not
    /// starrable, and drops one it does not hold. The saved visibility is left as it was.
    func testFullAssetListKeepsHeldBlacklistedTokensMarkedHidden() {
        let blacklist = AssetBlacklist(assetIds: [tokenId, otherId, valId], source: .remote)
        let held = row(asset(tokenId, symbol: "TKN", visible: true), balance: 5)
        let notHeld = row(asset(otherId, symbol: "OTH", visible: false), balance: 0)
        let unread = row(asset(valId, symbol: "VAL"), balance: 0, unavailable: true)
        let plain = row(asset("0x00cc" + String(repeating: "3", count: 60), symbol: "PLN", visible: false), balance: 0)

        let rows = ManageAssetListViewModel.applyingBlacklist([held, notHeld, unread, plain], blacklist: blacklist)

        XCTAssertEqual(rows.map(\.assetInfo.symbol), ["TKN", "VAL", "PLN"])
        XCTAssertTrue(held.isHiddenByBlacklist)
        XCTAssertFalse(held.canFavorite, "it cannot be starred back onto the home screen")
        XCTAssertFalse(held.showsAsFavorite)
        XCTAssertFalse(held.assetViewModel.isFavorite)
        XCTAssertTrue(held.assetInfo.visible, "the saved choice is not changed")
        XCTAssertEqual(held.assetViewModel.subtitle, "5 TKN · " + AssetBlacklist.hiddenNote)
        XCTAssertEqual(held.assetViewModel.fiatText, "$1", "the amount and its value stay")
        XCTAssertTrue(unread.isHiddenByBlacklist)
        XCTAssertFalse(plain.isHiddenByBlacklist)
        XCTAssertEqual(plain.assetViewModel.subtitle, "0 PLN")

        // Applying it again (rows are rebuilt on every balance update) marks only once.
        _ = ManageAssetListViewModel.applyingBlacklist([held], blacklist: blacklist)
        XCTAssertEqual(held.assetViewModel.subtitle, "5 TKN · " + AssetBlacklist.hiddenNote)
    }

    /// What the wallet owns is free plus reserved. A blacklisted token whose whole balance is
    /// reserved has nothing to send, yet it is held: its row stays, marked, above the "show
    /// zero balances" fold. The spendable balance on the row is still the one Send uses.
    func testFullAssetListKeepsABlacklistedTokenWhoseWholeBalanceIsReserved() throws {
        let token = asset(tokenId, symbol: "TKN", visible: false)
        let other = asset(otherId, symbol: "OTH", visible: false)
        let manager = Assets([token, other])
        let factory = AssetViewModelFactory(walletAssets: [token, other], assetManager: manager, fiatService: nil)
        func balance(_ id: String, free: Decimal, reserved: Decimal) -> BalanceData {
            let context = BalanceContext(free: free, reserved: reserved, miscFrozen: 0, feeFrozen: 0, bonded: 0,
                                         redeemable: 0, unbonding: 0, price: 0, priceChange: 0)
            return BalanceData(identifier: id, balance: AmountDecimal(value: context.available), context: context.toContext())
        }
        let rows = factory.assetListItems(
            assetIds: [tokenId, otherId],
            balances: [balance(tokenId, free: 0, reserved: 5), balance(otherId, free: 0, reserved: 0)],
            unavailable: [], mode: .view
        ) { balance, info in
            factory.createAssetViewModel(with: balance, assetInfo: info, fiatData: [], mode: .view)
        }
        let held = try XCTUnwrap(rows.first { $0.assetInfo.assetId == tokenId })
        XCTAssertEqual(held.balance, 0, "nothing of it can be sent")

        let kept = ManageAssetListViewModel.applyingBlacklist(
            rows, blacklist: AssetBlacklist(assetIds: [tokenId, otherId], source: .remote))
        XCTAssertEqual(kept.map(\.assetInfo.symbol), ["TKN"], "held, though all of it is reserved")
        XCTAssertTrue(held.isHiddenByBlacklist)
    }

    func testAssetListCellShowsAHeldBlacklistedTokenUnstarredAndLocked() throws {
        let item = row(asset(tokenId, symbol: "TKN", visible: true), balance: 5)
        item.markHiddenByBlacklist()
        let cell = AssetListCell(style: .default, reuseIdentifier: nil)
        cell.set(item: item, context: nil)
        let view = try XCTUnwrap(descendants(AssetView.self, in: cell).first)
        XCTAssertFalse(view.favoriteButton.isEnabled)
        XCTAssertEqual(view.subtitleLabel.text, "5 TKN · " + AssetBlacklist.hiddenNote)
    }

    private func descendants<T: UIView>(_ type: T.Type, in view: UIView) -> [T] {
        ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { descendants(type, in: $0) }
    }

    /// The portfolio hides a blacklisted holding like one the user turned off: out of the lists
    /// and the total, and counted in the note, with its own reason.
    func testPortfolioHidesBlacklistedHoldingsAndCountsThem() {
        let now = Date(timeIntervalSince1970: 10_000)
        let assets = [
            PortfolioAssetSource(id: xorId, symbol: "XOR", name: "SORA", icon: nil, precision: 18),
            PortfolioAssetSource(id: tokenId, symbol: "TKN", name: "Token", icon: nil, precision: 18, isBlacklisted: true)
        ]
        let reads = ["A": PortfolioWalletReadState(
            sora2: [xorId: PortfolioRawBalance(free: 10, reserved: 0, frozen: 0),
                    tokenId: PortfolioRawBalance(free: 4, reserved: 0, frozen: 0)],
            lastRead: now)]
        let snapshot = PortfolioSnapshotBuilder.build(
            .init(wallets: [PortfolioWalletSource(id: "A", name: "A", order: 0, isSelected: true, visibleAssetIds: nil,
                                                  orderedAssetIds: nil, addresses: [:])],
                  assets: assets, reads: reads, prices: PortfolioPriceSource(usd: [xorId: 2, tokenId: 100])),
            settings: .init(networks: [.sora2], liveNetworks: [.sora2], swapsAvailable: true, disclaimerAccepted: false),
            now: now)

        let token = snapshot.holdings.first { $0.token.id == tokenId }
        XCTAssertEqual(token?.amount, 4, "the balance is still read")
        XCTAssertEqual(token?.isHidden, true)
        XCTAssertEqual(token?.isBlacklisted, true)
        XCTAssertEqual(PortfolioAggregator.visibleHoldings(snapshot, scope: .allWallets).map(\.token.id), [xorId])
        let summary = PortfolioAggregator.summary(snapshot, scope: .allWallets)
        XCTAssertEqual(summary.total, 20)
        XCTAssertEqual(summary.hiddenCount, 1)
        XCTAssertEqual(summary.blacklistedCount, 1)
    }

    private final class Assets: AssetManagerProtocol {
        static var networkAssets: [AssetInfo] = []
        let assets: [AssetInfo]
        init(_ assets: [AssetInfo]) { self.assets = assets }
        func assetInfo(for identifier: String) -> AssetInfo? { assets.first { $0.assetId == identifier } }
        func getAssetList() -> [AssetInfo]? { assets }
        func updateAssetList(_: [AssetInfo]) {}
        func saveAssetList(_: [AssetInfo]) {}
        func sortedAssets(_ list: [WalletAsset], onlyVisible _: Bool) -> [WalletAsset] { list }
        func visibleCount() -> UInt { UInt(assets.count) }
        func setup(for _: SelectedWalletSettings) {}
    }
}

// MARK: - Explore

@MainActor
final class AssetBlacklistExploreTests: XCTestCase {
    private let tokenId = "0x00aa" + String(repeating: "1", count: 60)
    private let xorId = WalletAssetId.xor.rawValue
    private let valId = WalletAssetId.val.rawValue

    private func asset(_ id: String, symbol: String) -> AssetInfo {
        AssetInfo(id: id, symbol: symbol, chainId: "", precision: 18, icon: nil, displayName: symbol, visible: true)
    }

    private func until(_ condition: () -> Bool) async {
        for _ in 0 ..< 300 where !condition() {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    private func changeList(_ blacklist: FixedAssetBlacklist, to ids: [String]) {
        blacklist.list = AssetBlacklist(assetIds: ids, source: .remote)
        NotificationCenter.default.post(name: AssetBlacklistStore.didChange, object: nil)
    }

    private func factory(_ blacklist: FixedAssetBlacklist) -> ExploreItemFactory {
        let factory = ExploreItemFactory(assetManager: ExploreAssets([
            asset(xorId, symbol: "XOR"), asset(valId, symbol: "VAL"), asset(tokenId, symbol: "TKN")
        ]))
        factory.assetBlacklist = blacklist
        return factory
    }

    /// Pool discovery and the search that uses it leave out a pair with a blacklisted token,
    /// numbered without a gap, and follow a list that arrives after the screen loaded.
    func testExplorePoolsLeaveOutPairsWithABlacklistedTokenAndFollowANewList() async {
        let blacklist = FixedAssetBlacklist(AssetBlacklist(assetIds: [tokenId], source: .remote))
        let pools = ExplorePoolsViewModelService(
            itemFactory: factory(blacklist),
            poolsService: ExplorePools([
                ExplorePool(id: "xor-tkn", baseAssetId: xorId, targetAssetId: tokenId, tvl: 3),
                ExplorePool(id: "xor-val", baseAssetId: xorId, targetAssetId: valId, tvl: 2)
            ]),
            apyService: ExploreAPY(), fiatService: ExploreFiat(), pause: { _ in }
        )
        pools.setup()
        await until { pools.viewModels.map(\.poolId) == ["xor-val"] }
        XCTAssertEqual(pools.viewModels.map(\.poolId), ["xor-val"])
        XCTAssertEqual(pools.viewModels.map(\.serialNumber), ["1"])

        let search = ExploreSearchPageViewModel(
            wireframe: ExploreRoute(),
            assetViewModelsService: ExploreAssetViewModelService(
                marketCapService: ExploreMarket(), fiatService: nil, itemFactory: factory(blacklist), assetInfos: []),
            poolViewModelsService: pools,
            farmsViewModelsService: ExploreFarmsViewModelService(demeterFarmingService: ExploreFarms()))
        search.assetViewModelsService.viewModels = []
        search.setup()
        search.searchTextChanged(with: "TKN")
        XCTAssertEqual(search.snapshot.numberOfItems, 0, "search finds no pool with the blacklisted token")

        changeList(blacklist, to: [valId])
        await until { pools.viewModels.map(\.poolId) == ["xor-tkn"] }
        XCTAssertEqual(pools.viewModels.map(\.poolId), ["xor-tkn"])
        XCTAssertEqual(pools.viewModels.map(\.serialNumber), ["1"])
        XCTAssertEqual(search.snapshot.numberOfItems, 1)
        search.searchTextChanged(with: "VAL")
        XCTAssertEqual(search.snapshot.numberOfItems, 0)
    }

    /// The Explore token list follows a blacklist that arrives after it loaded.
    func testExploreAssetsFollowANewList() async {
        let blacklist = FixedAssetBlacklist(AssetBlacklist(assetIds: [tokenId], source: .remote))
        let itemFactory = factory(blacklist)
        let service = ExploreAssetViewModelService(
            marketCapService: ExploreMarket(), fiatService: nil, itemFactory: itemFactory,
            assetInfos: [asset(xorId, symbol: "XOR"), asset(valId, symbol: "VAL"), asset(tokenId, symbol: "TKN")],
            priceInfoService: ExplorePrices())
        let page = ExploreAssetsPageViewModel(wireframe: ExploreRoute(), assetViewModelsService: service)
        func shown() -> [String] {
            page.snapshot.itemIdentifiers.compactMap { item in
                guard case let .asset(row) = item else { return nil }
                return row.assetViewModel.assetId
            }
        }
        page.setup()
        await until { shown() == [valId, xorId] }
        XCTAssertEqual(shown(), [valId, xorId])

        changeList(blacklist, to: [valId])
        await until { shown() == [tokenId, xorId] }
        XCTAssertEqual(shown(), [tokenId, xorId])
        XCTAssertEqual(service.viewModels.compactMap(\.assetId), [tokenId, xorId], "and what search uses")
    }
}

private final class ExploreAssets: AssetManagerProtocol {
    static var networkAssets: [AssetInfo] = []
    let assets: [AssetInfo]
    init(_ assets: [AssetInfo]) { self.assets = assets }
    func assetInfo(for identifier: String) -> AssetInfo? { assets.first { $0.assetId == identifier } }
    func getAssetList() -> [AssetInfo]? { assets }
    func updateAssetList(_: [AssetInfo]) {}
    func saveAssetList(_: [AssetInfo]) {}
    func sortedAssets(_ list: [WalletAsset], onlyVisible _: Bool) -> [WalletAsset] { list }
    func visibleCount() -> UInt { UInt(assets.count) }
    func setup(for _: SelectedWalletSettings) {}
}

private final class ExplorePools: ExplorePoolsServiceInputProtocol {
    let pools: [ExplorePool]
    init(_ pools: [ExplorePool]) { self.pools = pools }
    func getPools(with _: [PIExactFiatData]) async throws -> [ExplorePool] { pools }
}

private actor ExploreAPY: APYServiceProtocol {
    func getApy(for _: String, targetAssetId _: String) async -> Decimal? { 1 }
    func setup(factory _: PolkaswapNetworkOperationFactoryProtocol) {}
}

private actor ExploreFiat: FiatServiceProtocol {
    func getFiat() async -> [PIExactFiatData] { [] }
}

private final class ExploreMarket: MarketCapServiceProtocol {
    func getMarketCap(for _: [String]) async -> Set<MarketCapInfo> { [] }
}

private final class ExplorePrices: PriceInfoServiceProtocol {
    func getPriceInfo(for _: [String]) async -> PriceInfo { PriceInfo(fiatData: [], marketCapInfo: []) }
}

private final class ExploreRoute: ExploreWireframeProtocol {
    func showAssetDetails(on _: UIViewController?, assetId _: String) {}
    func showAccountPoolDetails(on _: UIViewController?, poolInfo _: PoolInfo) {}
    func showLiquidity(on _: UIViewController?) {}
    func showFarmDetails(on _: UIViewController?, farm _: Farm) {}
}

private final class ExploreFarms: DemeterFarmingServiceProtocol {
    func getUserFarmInfos(baseAssetId _: String?, targetAssetId _: String?) async -> [UserFarm] { [] }
    func loadUserFarmInfos(baseAssetId _: String?, targetAssetId _: String?, accountId _: Data) async throws -> [UserFarm] { [] }
    func getAllFarms() async throws -> [Farm] { [] }
    func getFarm(with _: String) -> Farm? { nil }
    func getFarmDetails(baseAssetId _: String, poolAssetId _: String, rewardAssetId _: String) async throws -> [Farm] { [] }
    func getSingleSidedXorFarmedPools(completion: @escaping ([UserFarmInfo]) -> Void) { completion([]) }
}

/// A blacklist store that answers with the list a test sets.
final class FixedAssetBlacklist: AssetBlacklistStoring {
    var list: AssetBlacklist
    init(_ list: AssetBlacklist) { self.list = list }
    func current() -> AssetBlacklist { list }
    func acceptRemote(_: Data) -> AssetBlacklist? { nil }
}
