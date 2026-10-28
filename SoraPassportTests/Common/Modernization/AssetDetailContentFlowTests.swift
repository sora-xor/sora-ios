// SPDX-License-Identifier: Apache-2.0
import BigInt
import Foundation
import RobinHood
import SoraFoundation
import SoraUIKit
import SSFUtils
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class AssetDetailContentFlowTests: XCTestCase {
    private func wait(_ condition: @escaping () -> Bool) async {
        for _ in 0..<200 { if condition() { return }; try? await Task.sleep(nanoseconds: 5_000_000) }
        XCTAssertTrue(condition())
    }
    private func item<T>(_ type: T.Type, _ fixture: DetailFixture) throws -> T { try XCTUnwrap(fixture.items.compactMap { $0 as? T }.first) }
    func testInitialScreenShowsBalancesBeforePricesArrive() throws {
        let f = DetailFixture(); f.prices.hold = true; f.model.viewDidLoad()
        XCTAssertEqual(try item(PriceItem.self, f).priceText, "")
        XCTAssertEqual(try item(TransferableItem.self, f).balance.decimalValue, 10)
        XCTAssertNotNil(try item(RecentActivityItem.self, f)); XCTAssertNotNil(try item(AssetIdItem.self, f))
        f.prices.releaseAll()
    }
    func testPriceRefreshFillsExactAssetPrice() async throws {
        let f = DetailFixture(); f.prices.answer = f.price(2); f.model.viewDidLoad()
        await wait { f.priceText == "$2" }; XCTAssertEqual(try item(TransferableItem.self, f).fiat, "$20")
    }
    func testUnknownPricesAreNotRenderedAsZero() async throws {
        let f = DetailFixture(); f.model.viewDidLoad(); await wait { f.priceText == WalletUX.priceUnavailableText }
        XCTAssertEqual(try item(TransferableItem.self, f).fiat, "")
    }
    func testPriceResultsPublishOnTheMainThread() async {
        let f = DetailFixture(); var main = [Bool](); f.model.setupItems = { [weak f] in f?.items = $0; main.append(Thread.isMainThread) }
        f.model.viewDidLoad(); await wait { main.count == 2 }; XCTAssertTrue(main.allSatisfy { $0 })
    }
    func testPriceChangeNotificationRefreshesTheBoundAsset() async {
        let f = DetailFixture(); f.model.viewDidLoad(); await wait { f.prices.requests.count == 1 }
        f.prices.answer = f.price(7); NotificationCenter.default.post(name: PICatalogs.pricesDidChange, object: nil)
        await wait { f.priceText == "$7" }; XCTAssertEqual(f.prices.requests, [[f.asset.identifier], [f.asset.identifier]])
    }
    func testRepeatedViewLoadRegistersOnePriceNotificationObserver() async {
        let f = DetailFixture(); f.model.viewDidLoad(); await wait { f.prices.requests.count == 1 }
        f.model.viewDidLoad(); await wait { f.prices.requests.count == 2 }
        NotificationCenter.default.post(name: PICatalogs.pricesDidChange, object: nil)
        await wait { f.prices.requests.count == 3 }; try? await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertEqual(f.prices.requests.count, 3)
    }
    func testPriceRefreshReusesTheExistingActivityItem() async throws {
        let f = DetailFixture(); f.model.viewDidLoad(); let initial = try item(RecentActivityItem.self, f)
        await wait { f.priceText == WalletUX.priceUnavailableText }
        XCTAssertTrue(initial === (try item(RecentActivityItem.self, f))); XCTAssertEqual(f.history.requests, 1)
    }
    func testNonFeeAssetDoesNotReadReferralBalance() async {
        let f = DetailFixture(); f.model.viewDidLoad(); await wait { f.priceText == WalletUX.priceUnavailableText }
        XCTAssertEqual(f.referrals.reads, 0)
    }
    func testFeeAssetToleratesUnavailableReferralState() async throws {
        let f = DetailFixture(feeAsset: true); f.model.viewDidLoad(); await wait { f.priceText == WalletUX.priceUnavailableText }
        XCTAssertGreaterThan(f.referrals.reads, 0); XCTAssertEqual(try item(TransferableItem.self, f).balance.decimalValue, 10)
    }
    func testTransferableSendActionRoutesOnce() throws { let f = DetailFixture(); f.draw(); try item(TransferableItem.self, f).actionHandler?(.send); XCTAssertEqual(f.route.calls, ["send"]) }
    func testTransferableReceiveActionRoutesOnce() throws { let f = DetailFixture(); f.draw(); try item(TransferableItem.self, f).actionHandler?(.receive); XCTAssertEqual(f.route.calls, ["receive"]) }
    func testTransferableSwapActionRoutesOnce() throws { let f = DetailFixture(); f.draw(); try item(TransferableItem.self, f).actionHandler?(.swap); XCTAssertEqual(f.route.calls, ["swap"]) }
    func testFrozenRowsPreserveExactComponentsAndFiatValues() throws {
        let f = DetailFixture(); f.draw(referral: 3, price: 2); try item(TransferableItem.self, f).actionHandler?(.frozenDetails)
        XCTAssertEqual(f.route.frozen.map { $0.amount.attributedString.string }, ["12 VAL", "7 VAL", "3 VAL", "2 VAL", "4 VAL", "5 VAL"])
        XCTAssertEqual(f.route.frozen.map { $0.fiatAmount.attributedString.string }, ["$24", "$14", "$6", "$4", "$8", "$10"])
        XCTAssertEqual(f.route.frozen.map { $0.title.attributedString.string }, FrozenDetailType.allCases.map(\.title))
    }
    func testFrozenRowsLeaveUnknownFiatBlank() throws {
        let f = DetailFixture(); f.draw(); try item(TransferableItem.self, f).actionHandler?(.frozenDetails)
        XCTAssertEqual(f.route.frozen.count, 6); XCTAssertTrue(f.route.frozen.allSatisfy { $0.fiatAmount.attributedString.string.isEmpty })
    }
    func testUnavailableBalanceSuppressesInventedAmountsAndFrozenValues() throws {
        let f = DetailFixture(); f.balances.balances = []; f.balances.unavailable = [f.asset.identifier]; f.draw(price: 2)
        let row = try item(TransferableItem.self, f); XCTAssertTrue(row.balanceUnavailable); XCTAssertEqual(row.fiat, ""); XCTAssertEqual(row.frozenFiatAmount, ""); XCTAssertEqual(row.frozenAmount?.decimalValue, 0)
    }
    func testNoPoolsDoesNotCreateAnEmptyPoolSection() {
        let f = DetailFixture(); f.draw(); XCTAssertFalse(f.items.contains { $0 is PooledItem })
    }
    func testPoolRowHasTheSelectedAssetsAndExactHoldings() throws {
        let f = DetailFixture(); f.pools.pool = f.pool; f.draw(price: 2)
        let row = try item(PooledItem.self, f); XCTAssertEqual(row.assetSymbol, "VAL"); XCTAssertEqual(row.poolViewModels.count, 1); XCTAssertEqual(row.poolViewModels.first?.identifier, "pool-xor-val")
    }
    func testOpeningAPoolPreservesItsAccountState() throws {
        let f = DetailFixture(); f.pools.pool = f.pool; f.draw(); try item(PooledItem.self, f).openPoolDetailsHandler?("pool-xor-val")
        XCTAssertEqual(f.route.pool?.accountPoolBalance, 5); XCTAssertEqual(f.route.pool?.accountId, "public-fixture")
    }
    func testUnknownPoolIdentifierDoesNotNavigate() throws {
        let f = DetailFixture(); f.pools.pool = f.pool; f.draw(); try item(PooledItem.self, f).openPoolDetailsHandler?("not-in-this-screen"); XCTAssertNil(f.route.pool)
    }
    func testFullActivityRouteIsFilteredToTheBoundAsset() throws {
        let f = DetailFixture(); f.draw(); try item(RecentActivityItem.self, f).openFullActivityHandler?(); XCTAssertEqual(f.route.activityAsset, f.asset.identifier)
    }
    func testUnknownActivityHashDoesNotOpenDetails() throws {
        let f = DetailFixture(); f.draw(); try item(RecentActivityItem.self, f).openActivityDetailsHandler?("unknown"); XCTAssertTrue(f.route.calls.isEmpty)
    }
    func testHistoryUpdatesReloadOnlyTheActivityItem() throws {
        let f = DetailFixture(); f.draw(); var reloaded = [SoramitsuTableViewItemProtocol](); f.model.reloadItems = { reloaded = $0 }
        f.recent.updateHandler?(); XCTAssertEqual(reloaded.count, 1); XCTAssertTrue(reloaded.first is RecentActivityItem)
    }
    func testReplacingPriceReadIgnoresItsLateResult() async throws {
        let f = DetailFixture(); f.prices.hold = true; f.model.viewDidLoad(); await wait { f.prices.pendingCount == 1 }
        NotificationCenter.default.post(name: PICatalogs.pricesDidChange, object: nil); await wait { f.prices.pendingCount == 2 }
        f.prices.release(1, with: f.price(9)); await wait { f.priceText == "$9" }
        f.prices.release(0, with: f.price(1)); try? await Task.sleep(nanoseconds: 30_000_000); XCTAssertEqual(f.priceText, "$9")
    }
}

@MainActor
private final class DetailFixture {
    let assets = DetailAssets(), balances = DetailBalances(), pools = DetailPools(), route = DetailRoute(), referrals = DetailReferrals(), prices = DetailPrices(), history = DetailHistory(), events = DetailEvents()
    let asset: AssetInfo
    lazy var recent = RecentActivityItemService(assetId: asset.identifier, viewModelFactory: ActivityViewModelFactory(walletAssets: assets.assets, assetManager: assets), historyService: history, eventCenter: events, assetsProvider: balances)
    lazy var factory = AssetDetailsItemFactory(assetsProvider: balances, poolViewModelsFactory: PoolViewModelFactory(walletAssets: assets.assets, assetManager: assets, fiatService: nil), historyService: history, recentActivityService: recent, wireframe: route, poolsService: pools, transferableItemService: TransferableItemService(assetInfo: asset, eventCenter: events, assetsProvider: balances, referralFactory: referrals))
    lazy var model: AssetDetailsViewModel = { let m = AssetDetailsViewModel(wireframe: route, assetInfo: asset, referralFactory: referrals, priceInfoService: prices, itemsFactory: factory); m.setupItems = { [weak self] in self?.items = $0 }; return m }()
    var items = [SoramitsuTableViewItemProtocol]()
    var priceText: String? { (items.first { $0 is PriceItem } as? PriceItem)?.priceText }
    var pool: PoolInfo { .init(baseAssetId: WalletAssetId.xor.rawValue, targetAssetId: WalletAssetId.val.rawValue, poolId: "pool-xor-val", accountId: "public-fixture", baseAssetPooledByAccount: 10, targetAssetPooledByAccount: 20, accountPoolBalance: 5) }
    init(feeAsset: Bool = false) { asset = assets.assets[feeAsset ? 0 : 1]; balances.balances = [BalanceData(identifier: asset.identifier, balance: AmountDecimal(value: 10), context: [BalanceContext.freeKey: "17", BalanceContext.reservedKey: "2", BalanceContext.miscFrozenKey: "6", BalanceContext.feeFrozenKey: "7", BalanceContext.redeemableKey: "4", BalanceContext.unbondingKey: "5"])] }
    func price(_ value: Int) -> PriceInfo { .init(fiatData: [PIExactFiatData(id: asset.identifier, priceUsd: try! PIQuantity(String(value)))], marketCapInfo: []) }
    func draw(referral: Decimal? = nil, price value: Int? = nil) { model.createItems(with: .init(priceInfo: value.map(price) ?? .init(fiatData: [], marketCapInfo: []), referralBalance: referral)) }
}
private final class DetailPrices: PriceInfoServiceProtocol {
    private let lock = NSLock(); private var held = false; private var answerValue = PriceInfo(fiatData: [], marketCapInfo: [])
    var hold: Bool { get { lock.lock(); defer { lock.unlock() }; return held } set { lock.lock(); held = newValue; lock.unlock() } }
    var answer: PriceInfo { get { lock.lock(); defer { lock.unlock() }; return answerValue } set { lock.lock(); answerValue = newValue; lock.unlock() } }
    private var asked = [[String]](), continuations = [Int: CheckedContinuation<PriceInfo, Never>](); private var next = 0
    var requests: [[String]] { lock.lock(); defer { lock.unlock() }; return asked }
    var pendingCount: Int { lock.lock(); defer { lock.unlock() }; return continuations.count }
    func getPriceInfo(for assetIds: [String]) async -> PriceInfo { await withCheckedContinuation { c in lock.lock(); asked.append(assetIds); let n = next; next += 1; if held { continuations[n] = c; lock.unlock() } else { let value = answerValue; lock.unlock(); c.resume(returning: value) } } }
    func release(_ id: Int, with value: PriceInfo) { lock.lock(); let c = continuations.removeValue(forKey: id); lock.unlock(); c?.resume(returning: value) }
    func releaseAll() { lock.lock(); held = false; let cs = Array(continuations.values); continuations.removeAll(); lock.unlock(); cs.forEach { $0.resume(returning: answer) } }
}
private final class DetailHistory: HistoryServiceProtocol {
    private let lock = NSLock(); private var count = 0
    var requests: Int { lock.lock(); defer { lock.unlock() }; return count }
    func getHistory(count: Int, assetId: String?) async throws -> [Transaction] { note(); return [] }
    private func note() { lock.lock(); count += 1; lock.unlock() }
    func getTransaction(by: String) -> Transaction? { nil }
    func getPageHistory(count: Int, page: Int, assetId: String?) async throws -> HistoryPage { throw URLError(.notConnectedToInternet) }
    func getHistory(count: Int, assetId: String?, completion: @escaping (Result<[Transaction], Error>) -> Void) { completion(.success([])) }
    func getPageHistory(count: Int, page: Int, assetId: String?, completion: @escaping (Result<HistoryPage, Error>) -> Void) { completion(.failure(URLError(.notConnectedToInternet))) }
}
private final class DetailRoute: AssetDetailsWireframeProtocol {
    var calls = [String](), frozen = [BalanceDetailViewModel](); var pool: PoolInfo?, activityAsset: String?
    func showActivity(assetId: String) { activityAsset = assetId }
    func showActivityDetails(model: Transaction) { calls.append("details") }
    func showSwap() { calls.append("swap") }; func showReceive() { calls.append("receive") }; func showSend() { calls.append("send") }
    func showFrozenBalance(frozenDetailViewModels: [BalanceDetailViewModel]) { frozen = frozenDetailViewModels }
    func showPoolDetails(poolInfo: PoolInfo, poolsService: PoolsServiceInputProtocol) { pool = poolInfo }
}

private final class DetailEvents: EventCenterProtocol {
    func notify(with event: EventProtocol) {}
    func notify(with event: EventProtocol, completionOnMain: @escaping () -> Void) { DispatchQueue.main.async(execute: completionOnMain) }
    func add(observer: EventVisitorProtocol, dispatchIn: DispatchQueue?) {}
    func remove(observer: EventVisitorProtocol) {}
}

private final class DetailAssets: AssetManagerProtocol {
    static var networkAssets: [AssetInfo] = []
    let assets = [AssetInfo(id: WalletAssetId.xor.rawValue, symbol: "XOR", chainId: "", precision: 18, icon: nil, displayName: "SORA", visible: true),
        AssetInfo(id: WalletAssetId.val.rawValue, symbol: "VAL", chainId: "", precision: 18, icon: nil, displayName: "Validator", visible: true),
        AssetInfo(id: WalletAssetId.pswap.rawValue, symbol: "PSWAP", chainId: "", precision: 18, icon: nil, displayName: "Zero asset", visible: false),
        AssetInfo(id: "custom-unknown", symbol: "UNKNOWN", chainId: "", precision: 18, icon: nil, displayName: "Unread asset", visible: false)]
    var saved: [[AssetInfo]] = []
    func assetInfo(for identifier: String) -> AssetInfo? { assets.first { $0.identifier == identifier } }
    func getAssetList() -> [AssetInfo]? { assets }
    func updateAssetList(_ list: [AssetInfo]) {}
    func saveAssetList(_ list: [AssetInfo]) { saved.append(list) }
    func sortedAssets(_ list: [WalletAsset], onlyVisible: Bool) -> [WalletAsset] { list }
    func visibleCount() -> UInt { 2 }
    func setup(for accountSettings: SelectedWalletSettings) {}
}


private final class DetailBalances: AssetProviderProtocol {
    var balances: [BalanceData] = []; var unavailable: Set<String> = []; var additions = 0
    func getBalances(with assetIds: [String]) -> [BalanceData] { balances.filter { assetIds.contains($0.identifier) } }
    func unavailableBalanceAssetIds(among assetIds: [String]) -> Set<String> { unavailable.intersection(assetIds) }
    func add(observer: AssetProviderObserverProtocol) { additions += 1 }
    func remove(observer: AssetProviderObserverProtocol) {}
}

private final class DetailPools: PoolsServiceInputProtocol {
    let state = PoolNetworkState(isPresented: false, isEnabled: false)
    var pool: PoolInfo? = nil

    func loadAccountPools() {}
    func getAccountPools() -> [PoolInfo] { pool.map { [$0] } ?? [] }
    var saved: [[PoolInfo]] = []
    func updatePools(_ pools: [PoolInfo]) { saved.append(pools) }
    func getPool(by _: String) -> PoolInfo? { pool }
    func getPool(by _: String, targetAssetId _: String) async -> PoolInfo? { pool }
    func loadPool(by _: String, targetAssetId _: String) async -> PoolInfo? { pool }
    func loadPairState(baseAssetId _: String, targetAssetId _: String) async throws -> PoolNetworkState { state }
    func loadPools(currentAsset _: AssetInfo) -> [PoolInfo] { pool.map { [$0] } ?? [] }
    func loadTargetPools(for _: String) -> [PoolInfo] { [] }
    func appendDelegate(delegate _: PoolsServiceOutput) {}
}


private final class DetailReferrals: ReferralsOperationFactoryProtocol {
    private let readLock = NSLock(); private var readCount = 0
    var reads: Int { readLock.lock(); defer { readLock.unlock() }; return readCount }
    func createReferrerBalancesOperation() -> JSONRPCListOperation<JSONScaleDecodable<SoraPassport.Balance>>? { readLock.lock(); readCount += 1; readLock.unlock(); return nil }
    func createExtrinsicSetReferrerOperation(with _: String) -> BaseOperation<String> {
        ClosureOperation { "" }
    }
    func createExtrinsicReserveReferralBalanceOperation(with _: BigUInt) -> BaseOperation<String> {
        ClosureOperation { "" }
    }
    func createExtrinsicUnreserveReferralBalanceOperation(with _: BigUInt) -> BaseOperation<String> {
        ClosureOperation { "" }
    }
    func createReferrerOperation() -> JSONRPCListOperation<String?>? { nil }
}
