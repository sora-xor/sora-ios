// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0
import BigInt
import RobinHood
import SoraFoundation
import SoraUIKit
import SSFUtils
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class ProductListBehaviorTests: XCTestCase {
    private var language = "en"
    private let manager = ProductAssets()
    private let fiat = ProductFiat()
    private let provider = ProductBalances()
    private let prices = ProductPrices()
    private var shown: [SoramitsuTableViewItemProtocol] = []
    override func setUp() { super.setUp(); language = LocalizationManager.shared.selectedLocalization; LocalizationManager.shared.selectedLocalization = "en" }
    override func tearDown() { LocalizationManager.shared.selectedLocalization = language; super.tearDown() }
    private func item(_ asset: AssetInfo, balance: Decimal = 1, unavailable: Bool = false) -> AssetListItem {
        let result = AssetListItem(assetInfo: asset,
            assetViewModel: AssetViewModel(identifier: asset.identifier, title: asset.name, subtitle: asset.symbol,
                fiatText: unavailable ? WalletUX.balanceUnavailableText : "$2", mode: .selection, isFavorite: asset.visible), balance: balance)
        result.balanceUnavailable = unavailable; return result
    }
    private func selection() -> SelectAssetViewModel {
        let model = SelectAssetViewModel(assetViewModelFactory: AssetViewModelFactory(walletAssets: manager.assets, assetManager: manager, fiatService: fiat),
            fiatService: fiat, assetManager: manager, assetsProvider: provider, assetIds: manager.assets.map(\.identifier), marketCapService: ProductMarket(), priceInfoService: prices)
        model.setupItems = { [weak self] in self?.shown = $0 }
        return model
    }
    private var identifiers: [String] { shown.compactMap { ($0 as? AssetListItem)?.assetInfo.identifier } }
    private func manage() -> ManageAssetListViewModel {
        let network = WalletNetworkOperationFactoryProtocolMock()
        let model = ManageAssetListViewModel(assetViewModelFactory: AssetViewModelFactory(walletAssets: manager.assets, assetManager: manager, fiatService: fiat),
            fiatService: fiat, assetManager: manager,
            providerFactory: BalanceProviderFactory(accountId: "", cacheFacade: CoreDataCacheFacade.shared, networkOperationFactory: network, identifierFactory: SingleProviderIdentifierFactory()),
            poolsService: ProductPools(), networkFacade: network, accountId: "", address: "",
            polkaswapNetworkFacade: PolkaswapNetworkOperationFactory(engine: ProductEngine()), qrEncoder: ProductQR(), sharingFactory: ProductShare(),
            referralFactory: ProductReferrals(), assetsProvider: provider, marketCapService: ProductMarket(), farmingService: ProductFarms(),
            wireframe: ProductRoute(), updateHandler: nil, priceInfoService: prices)
        model.setupItems = { [weak self] in self?.shown = $0 }; return model
    }
    func testSelectionSearchMatchesSymbolIdentifierAndDisplayNameIgnoringCase() {
        let model = selection(); model.assetItems = manager.assets.map { item($0) }; model.isActiveSearch = true
        for query in ["vAl", manager.assets[1].identifier.uppercased(), "VALIDATOR"] {
            model.searchText = query
            XCTAssertEqual(identifiers, [manager.assets[1].identifier], query)
        }
    }
    func testSelectionStartsSearchWithTheCurrentCatalog() {
        let model = selection(); model.assetItems = manager.assets.map { item($0) }; model.isActiveSearch = true
        XCTAssertEqual(identifiers, manager.assets.map(\.identifier))
    }
    func testSelectionNormalizesPastedSearchWhitespace() {
        let model = selection(); model.assetItems = manager.assets.map { item($0) }; model.isActiveSearch = true; model.searchText = "  VAL\n"
        XCTAssertEqual(identifiers, [manager.assets[1].identifier])
    }
    func testSelectionKeepsSearchAppliedWhenBalancesReplaceRows() {
        let model = selection(); model.assetItems = manager.assets.map { item($0) }; model.isActiveSearch = true; model.searchText = "VAL"
        model.assetItems = manager.assets.map { item($0, balance: 9) }
        XCTAssertEqual(identifiers, [manager.assets[1].identifier])
        XCTAssertEqual((shown.first as? AssetListItem)?.balance, 9)
    }
    func testClearingSelectionSearchDoesNotRestoreStaleQueryOnReopen() {
        let model = selection(); model.assetItems = manager.assets.map { item($0) }; model.isActiveSearch = true; model.searchText = "VAL"; model.searchText = ""
        model.isActiveSearch = false; model.isActiveSearch = true
        XCTAssertEqual(identifiers, manager.assets.map(\.identifier))
    }
    func testSelectionPriceFailureLeavesUnknownBalanceTextIntact() async {
        let model = selection(); let unknown = item(manager.assets[1], unavailable: true); model.assetItems = [unknown]
        model.priceInfo = PriceInfo(fiatData: [], marketCapInfo: [])
        await Task.yield()
        XCTAssertEqual(unknown.assetViewModel.fiatText, WalletUX.balanceUnavailableText)
        XCTAssertNil(unknown.assetViewModel.deltaPriceText)
    }
    func testManageHidesOnlyNonfavoriteKnownZeroBalances() {
        let model = manage()
        model.assetItems = [item(manager.assets[0], balance: 0), item(manager.assets[1], balance: 0), item(manager.assets[2], balance: 0), item(manager.assets[3], balance: 0, unavailable: true)]
        XCTAssertEqual(identifiers, [manager.assets[0].identifier, manager.assets[1].identifier, manager.assets[3].identifier])
        XCTAssertEqual(shown.compactMap { $0 as? ZeroBalanceItem }.count, 1)
    }
    func testManageShowZeroToggleCanExpandAndCollapseRepeatedly() throws {
        let model = manage(); model.assetItems = [item(manager.assets[0]), item(manager.assets[2], balance: 0)]
        try XCTUnwrap(shown.compactMap { $0 as? ZeroBalanceItem }.first).buttonHandler?()
        XCTAssertEqual(identifiers, [manager.assets[0].identifier, manager.assets[2].identifier])
        try XCTUnwrap(shown.compactMap { $0 as? ZeroBalanceItem }.first).buttonHandler?()
        XCTAssertEqual(identifiers, [manager.assets[0].identifier])
    }
    func testManageEditingExposesZeroRowsAndUpdatesEveryRowMode() {
        let model = manage(); model.assetItems = manager.assets.map { item($0, balance: 0) }; model.mode = .edit
        XCTAssertEqual(identifiers, manager.assets.map(\.identifier)); XCTAssertFalse(shown.contains { $0 is ZeroBalanceItem })
        XCTAssertTrue(model.assetItems.allSatisfy { $0.assetViewModel.mode == .edit })
    }
    func testManageSavingPreservesNewWalletAssetsWithoutRows() {
        let model = manage(); model.assetItems = [item(manager.assets[1]), item(manager.assets[0])]; model.mode = .edit; model.mode = .view
        XCTAssertEqual(manager.saved.last?.map(\.identifier), [manager.assets[1], manager.assets[0], manager.assets[2], manager.assets[3]].map(\.identifier))
    }
    func testManageSearchStartsWithAllAssetsIncludingZeroRows() {
        let model = manage(); model.assetItems = manager.assets.map { item($0, balance: 0) }; model.isActiveSearch = true
        XCTAssertEqual(identifiers, manager.assets.map(\.identifier)); XCTAssertFalse(shown.contains { $0 is ZeroBalanceItem })
    }
    func testManageSearchRemainsAppliedAfterBalanceRefresh() {
        let model = manage(); model.assetItems = manager.assets.map { item($0) }; model.isActiveSearch = true; model.searchText = "VAL"
        model.assetItems = manager.assets.map { item($0, balance: 9) }
        XCTAssertEqual(identifiers, [manager.assets[1].identifier]); XCTAssertEqual((shown.first as? AssetListItem)?.balance, 9)
    }
    func testManageSearchMatchesHumanNameAndTrimsWhitespace() {
        let model = manage(); model.assetItems = manager.assets.map { item($0) }; model.isActiveSearch = true; model.searchText = "  validator \n"
        XCTAssertEqual(identifiers, [manager.assets[1].identifier])
    }
    func testManageClearedQueryStaysClearedWhenModeChanges() {
        let model = manage(); model.assetItems = manager.assets.map { item($0) }; model.isActiveSearch = true; model.searchText = "VAL"; model.searchText = ""; model.mode = .edit
        XCTAssertEqual(identifiers, manager.assets.map(\.identifier))
    }
    private func settleRows(_ model: SelectAssetViewModel) async {
        for _ in 0..<100 where model.assetItems.isEmpty { try? await Task.sleep(nanoseconds: 10_000_000) }
    }
    func testSelectionLoadsKnownAndUnavailableBalancesBeforePricesAndChoosesCurrentAsset() async throws {
        provider.balances = [BalanceData(identifier: manager.assets[0].identifier, balance: AmountDecimal(value: 3))]
        provider.unavailable = [manager.assets[1].identifier]
        let model = selection(); var selected: [String] = []; var dismissals: [Bool] = []
        model.selectionCompletion = { selected.append($0) }; model.dismiss = { dismissals.append($0) }
        model.viewDidLoad(); await settleRows(model)
        let row = try XCTUnwrap(model.assetItems.first { $0.assetInfo.identifier == manager.assets[1].identifier })
        XCTAssertTrue(row.balanceUnavailable); XCTAssertEqual(row.assetViewModel.subtitle, WalletUX.balanceUnavailableText)
        XCTAssertEqual(row.assetViewModel.fiatText, "")
        row.itemActionTap(with: nil)
        XCTAssertEqual(selected, [manager.assets[1].identifier]); XCTAssertEqual(dismissals, [true])
    }
    func testSelectionLoadsThroughInjectedPriceServiceAndPublishesOnMainThread() async {
        provider.balances = [BalanceData(identifier: manager.assets[0].identifier, balance: AmountDecimal(value: 3))]
        let model = selection(); let updated = expectation(description: "Rows priced")
        model.reloadItems = { _ in XCTAssertTrue(Thread.isMainThread); updated.fulfill() }
        model.setupItems = { _ in XCTAssertTrue(Thread.isMainThread) }
        model.viewDidLoad(); await fulfillment(of: [updated], timeout: 2)
        XCTAssertEqual(prices.calls, 1)
    }
    func testManagedInitialLoadDoesNotFetchPricesTwice() async {
        provider.balances = [BalanceData(identifier: manager.assets[0].identifier, balance: AmountDecimal(value: 3))]
        let model = manage(); model.viewDidLoad()
        for _ in 0..<100 where prices.calls == 0 { try? await Task.sleep(nanoseconds: 10_000_000) }
        try? await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(prices.calls, 1); XCTAssertEqual(provider.additions, 1)
        XCTAssertFalse(model.assetItems.isEmpty)
    }
    func testManagedBalanceObserverRetainsCurrentSearchAndIgnoresOtherWalletAssets() async {
        provider.balances = [BalanceData(identifier: manager.assets[1].identifier, balance: AmountDecimal(value: 3))]
        let model = manage(); model.assetItems = manager.assets.map { item($0) }; model.isActiveSearch = true; model.searchText = "VAL"
        model.processBalance(data: provider.balances + [BalanceData(identifier: "unrelated", balance: AmountDecimal(value: 99))])
        for _ in 0..<100 where (model.assetItems.first { $0.assetInfo.identifier == manager.assets[1].identifier })?.balance != 3 { try? await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertEqual(identifiers, [manager.assets[1].identifier]); XCTAssertEqual((shown.first as? AssetListItem)?.balance, 3)
        XCTAssertFalse(model.assetItems.contains { $0.assetInfo.identifier == "unrelated" })
    }
    func testManagedLoadedRowFavoriteActionIsPersistedWhenEditingEnds() async throws {
        provider.balances = [BalanceData(identifier: manager.assets[2].identifier, balance: AmountDecimal(value: 3))]
        let model = manage(); model.processBalance(data: provider.balances)
        for _ in 0..<100 where model.assetItems.isEmpty { try? await Task.sleep(nanoseconds: 10_000_000) }
        let row = try XCTUnwrap(model.assetItems.first { $0.assetInfo.identifier == manager.assets[2].identifier })
        XCTAssertFalse(row.assetInfo.visible); row.favoriteHandle?(row); XCTAssertTrue(row.assetInfo.visible)
        model.mode = .edit; model.mode = .view
        XCTAssertEqual(manager.saved.last?.first { $0.identifier == manager.assets[2].identifier }?.visible, true)
    }
    private func poolModel() -> (PoolListViewModel, ProductPools) {
        let network = WalletNetworkOperationFactoryProtocolMock(); let pools = ProductPools()
        let model = PoolListViewModel(poolsService: pools, assetManager: manager, fiatService: fiat,
            poolViewModelFactory: PoolViewModelFactory(walletAssets: manager.assets, assetManager: manager, fiatService: fiat),
            providerFactory: BalanceProviderFactory(accountId: "", cacheFacade: CoreDataCacheFacade.shared, networkOperationFactory: network, identifierFactory: SingleProviderIdentifierFactory()),
            operationFactory: network, assetsProvider: provider, marketCapService: ProductMarket(), farmingService: ProductFarms(),
            feeProvider: FeeProvider(account: nil), updateHandler: nil)
        model.setupItems = { [weak self] in self?.shown = $0 }; return (model, pools)
    }
    private func poolRow(_ id: String, _ title: String) -> PoolListItem {
        PoolListItem(poolInfo: PoolInfo(baseAssetId: WalletAssetId.xor.rawValue, targetAssetId: WalletAssetId.val.rawValue, poolId: id, accountId: ""),
            poolViewModel: PoolViewModel(identifier: id, title: title, subtitle: "1 XOR - 2 VAL", fiatText: "$3"))
    }
    private var poolIds: [String] { shown.compactMap { ($0 as? PoolListItem)?.poolViewModel.identifier } }
    func testPoolSearchStartsWithCurrentRows() {
        let (model, _) = poolModel(); model.poolItems = [poolRow("one", "XOR-VAL"), poolRow("two", "XOR-PSWAP")]; model.isActiveSearch = true
        XCTAssertEqual(poolIds, ["one", "two"])
    }
    func testPoolSearchMatchesCaseAndPastedWhitespace() {
        let (model, _) = poolModel(); model.poolItems = [poolRow("one", "XOR-VAL"), poolRow("two", "XOR-PSWAP")]; model.isActiveSearch = true; model.searchText = "  vAl\n"
        XCTAssertEqual(poolIds, ["one"])
    }
    func testPoolRefreshKeepsTheActiveQuery() {
        let (model, _) = poolModel(); model.poolItems = [poolRow("one", "XOR-VAL"), poolRow("two", "XOR-PSWAP")]; model.isActiveSearch = true; model.searchText = "VAL"
        model.poolItems = [poolRow("new", "XOR-VAL"), poolRow("two", "XOR-PSWAP")]
        XCTAssertEqual(poolIds, ["new"])
    }
    func testPoolClearedQuerySurvivesEditModeAndSearchReentry() {
        let (model, _) = poolModel(); model.poolItems = [poolRow("one", "XOR-VAL"), poolRow("two", "XOR-PSWAP")]; model.isActiveSearch = true; model.searchText = "VAL"; model.searchText = ""
        model.mode = .edit; XCTAssertEqual(poolIds, ["one", "two"])
        model.isActiveSearch = false; model.isActiveSearch = true; XCTAssertEqual(poolIds, ["one", "two"])
    }
    func testPoolEditingSavesTheCurrentOrderAndRowModes() {
        let (model, pools) = poolModel(); model.poolItems = [poolRow("two", "XOR-PSWAP"), poolRow("one", "XOR-VAL")]; model.mode = .edit
        XCTAssertTrue(model.poolItems.allSatisfy { $0.poolViewModel.mode == .edit })
        model.mode = .view; XCTAssertEqual(pools.saved.last?.map(\.poolId), ["two", "one"])
    }
    func testPoolDismissalRequiresAnActuallyEmptyCatalog() {
        let (model, _) = poolModel(); var dismissals = 0; model.dismiss = { force in XCTAssertFalse(force); dismissals += 1 }
        model.poolItems = [poolRow("one", "XOR-VAL")]; model.dismissIfNeeded(); XCTAssertEqual(dismissals, 0)
        model.poolItems = []; model.dismissIfNeeded(); XCTAssertEqual(dismissals, 1)
    }
    func testPoolCellRebindsCurrentPairAndAmounts() throws {
        let cell = PoolListCell(style: .default, reuseIdentifier: nil)
        cell.set(item: poolRow("one", "XOR-VAL"), context: nil); cell.set(item: poolRow("two", "XOR-PSWAP"), context: nil)
        let view = try XCTUnwrap(descendants(PoolView.self, in: cell).first)
        XCTAssertEqual(view.titleLabel.text, "XOR-PSWAP"); XCTAssertEqual(view.amountUpLabel.text, "$3")
    }
    private func descendants<T: UIView>(_ type: T.Type, in view: UIView) -> [T] {
        ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { descendants(type, in: $0) }
    }
    private func screen() -> (ProductListViewController, ProductScreenModel) {
        let model = ProductScreenModel(); let screen = ProductListViewController(viewModel: model); screen.loadViewIfNeeded()
        screen.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844); screen.view.layoutIfNeeded(); return (screen, model)
    }
    func testProductScreenBuildsSearchAndForwardsInitialLoad() throws {
        let (screen, model) = screen(); XCTAssertEqual(model.loads, 1)
        XCTAssertEqual(screen.navigationItem.title, "Choose asset")
        XCTAssertEqual(screen.navigationItem.searchController?.searchBar.placeholder, "Search assets")
        XCTAssertNotNil(screen.navigationItem.leftBarButtonItem); XCTAssertNotNil(screen.navigationItem.rightBarButtonItem)
    }
    func testProductScreenEditAndDoneUpdateModelAndDragCapability() throws {
        let (screen, model) = screen(); let table = try XCTUnwrap(descendants(SoramitsuTableView.self, in: screen.view).first)
        screen.editTapped(); XCTAssertEqual(model.mode, .edit); XCTAssertTrue(table.dragInteractionEnabled); XCTAssertNil(screen.navigationItem.rightBarButtonItem)
        screen.doneTapped(); XCTAssertEqual(model.mode, .view); XCTAssertFalse(table.dragInteractionEnabled); XCTAssertNotNil(screen.navigationItem.rightBarButtonItem)
    }
    func testProductScreenSelectionModeOmitsEditingAction() {
        let (screen, model) = screen(); model.mode = .selection
        XCTAssertNil(screen.navigationItem.leftBarButtonItem); XCTAssertNotNil(screen.navigationItem.rightBarButtonItem)
    }
    func testProductScreenForwardsSearchPresentationAndText() throws {
        let (screen, model) = screen(); let search = try XCTUnwrap(screen.navigationItem.searchController)
        screen.willPresentSearchController(search); XCTAssertTrue(model.isActiveSearch)
        search.searchBar.text = "VAL"; screen.updateSearchResults(for: search); XCTAssertEqual(model.searchText, "VAL")
        screen.willDismissSearchController(search); XCTAssertFalse(model.isActiveSearch)
        screen.crossButtonTapped(); XCTAssertEqual(model.dismissals, 1)
    }
    func testProductScreenShowsEmptyStateOnlyDuringAnEmptySearch() async throws {
        let (screen, model) = screen(); model.isActiveSearch = true; model.setupItems?([])
        try await Task.sleep(nanoseconds: 20_000_000)
        let label = try XCTUnwrap(descendants(SoramitsuLabel.self, in: screen.view).first { !($0.text ?? "").isEmpty })
        XCTAssertFalse(label.isHidden)
        model.isActiveSearch = false; model.setupItems?([]); try await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertTrue(label.isHidden)
    }
    func testAssetListCellRebindsItsTitleAndFavoritePermission() throws {
        let cell = AssetListCell(style: .default, reuseIdentifier: nil)
        cell.set(item: item(manager.assets[1]), context: nil)
        let view = try XCTUnwrap(descendants(AssetView.self, in: cell).first)
        XCTAssertEqual(view.titleLabel.text, "Validator"); XCTAssertTrue(view.favoriteButton.isEnabled)
        cell.set(item: item(manager.assets[0]), context: nil)
        XCTAssertEqual(view.titleLabel.text, "XOR"); XCTAssertFalse(view.favoriteButton.isEnabled)
    }
    func testZeroBalanceCellUsesOnlyTheLatestToggleHandler() throws {
        let cell = ZeroBalanceCell(style: .default, reuseIdentifier: nil); let first = ZeroBalanceItem(isShown: false); let second = ZeroBalanceItem(isShown: true)
        var old = 0; var current = 0; first.buttonHandler = { old += 1 }; second.buttonHandler = { current += 1 }
        cell.set(item: first, context: nil); cell.set(item: second, context: nil)
        try XCTUnwrap(descendants(SoramitsuButton.self, in: cell).first).sendActions(for: .touchUpInside)
        XCTAssertEqual(old, 0); XCTAssertEqual(current, 1)
    }
}
private final class ProductAssets: AssetManagerProtocol {
    static var networkAssets: [AssetInfo] = []
    let assets = [AssetInfo(id: WalletAssetId.xor.rawValue, symbol: "XOR", chainId: "", precision: 18, icon: nil, displayName: "SORA", visible: true),
        AssetInfo(id: WalletAssetId.val.rawValue, symbol: "VAL", chainId: "", precision: 18, icon: nil, displayName: "Validator", visible: true),
        AssetInfo(id: "custom-zero", symbol: "ZERO", chainId: "", precision: 18, icon: nil, displayName: "Zero asset", visible: false),
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
private actor ProductFiat: FiatServiceProtocol { func getFiat() async -> [PIExactFiatData] { [] } }
private final class ProductMarket: MarketCapServiceProtocol { func getMarketCap(for assets: [String]) async -> Set<MarketCapInfo> { [] } }
private final class ProductPrices: PriceInfoServiceProtocol {
    private let lock = NSLock(); private var count = 0
    var calls: Int { lock.lock(); defer { lock.unlock() }; return count }
    func getPriceInfo(for assets: [String]) async -> PriceInfo { lock.lock(); count += 1; lock.unlock(); return PriceInfo(fiatData: [], marketCapInfo: []) }
}
private final class ProductBalances: AssetProviderProtocol {
    var balances: [BalanceData] = []; var unavailable: Set<String> = []; var additions = 0
    func getBalances(with assetIds: [String]) -> [BalanceData] { balances.filter { assetIds.contains($0.identifier) } }
    func unavailableBalanceAssetIds(among assetIds: [String]) -> Set<String> { unavailable.intersection(assetIds) }
    func add(observer: AssetProviderObserverProtocol) { additions += 1 }
    func remove(observer: AssetProviderObserverProtocol) {}
}
private final class ProductScreenModel: Produtable {
    var searchBarPlaceholder: String { "Search assets" }; var navigationTitle: String { "Choose asset" }
    var searchText = ""; var isActiveSearch = false
    var mode: WalletViewMode = .view { didSet { setupNavigationBar?(mode) } }
    var setupNavigationBar: ((WalletViewMode) -> Void)?
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var dismiss: ((Bool) -> Void)?
    var loads = 0; var dismissals = 0
    func viewDidLoad() { loads += 1; setupNavigationBar?(mode) }
    func viewdismissed() { dismissals += 1 }
}

private final class ProductQR: WalletQREncoderProtocol {
    func encode(receiverInfo _: ReceiveInfo) throws -> Data {
        Data("substrate:test".utf8)
    }
}
private struct ProductShare: AccountShareFactoryProtocol {
    func createSources(for _: ReceiveInfo, qrImage _: UIImage) -> [Any] { [] }
}
private final class ProductPools: PoolsServiceInputProtocol {
    let state = PoolNetworkState(isPresented: false, isEnabled: false)
    let pool: PoolInfo? = nil

    func loadAccountPools() {}
    func getAccountPools() -> [PoolInfo] { pool.map { [$0] } ?? [] }
    var saved: [[PoolInfo]] = []
    func updatePools(_ pools: [PoolInfo]) { saved.append(pools) }
    func getPool(by _: String) -> PoolInfo? { pool }
    func getPool(by _: String, targetAssetId _: String) async -> PoolInfo? { pool }
    func loadPool(by _: String, targetAssetId _: String) async -> PoolInfo? { pool }
    func loadPairState(baseAssetId _: String, targetAssetId _: String) async throws -> PoolNetworkState { state }
    func loadPools(currentAsset _: AssetInfo) -> [PoolInfo] { [] }
    func loadTargetPools(for _: String) -> [PoolInfo] { [] }
    func appendDelegate(delegate _: PoolsServiceOutput) {}
}
private final class ProductFarms: DemeterFarmingServiceProtocol {
    func getUserFarmInfos(baseAssetId _: String?, targetAssetId _: String?) async -> [UserFarm] { [] }
    func loadUserFarmInfos(baseAssetId _: String?, targetAssetId _: String?, accountId _: Data) async throws -> [UserFarm] { [] }
    func getAllFarms() async throws -> [Farm] { [] }
    func getFarm(with _: String) -> Farm? { nil }
    func getFarmDetails(baseAssetId _: String, poolAssetId _: String, rewardAssetId _: String) async throws -> [Farm] { [] }
    func getSingleSidedXorFarmedPools(completion: @escaping ([UserFarmInfo]) -> Void) { completion([]) }
}
private final class ProductRoute: AssetListWireframeProtocol {
    func showAssetDetails(on viewController: UIViewController?,
                          assetInfo: AssetInfo,
                          assetManager: AssetManagerProtocol,
                          fiatService: FiatServiceProtocol,
                          assetViewModelFactory: AssetViewModelFactory,
                          poolsService: PoolsServiceInputProtocol,
                          poolViewModelsFactory: PoolViewModelFactory,
                          providerFactory: BalanceProviderFactory,
                          networkFacade: WalletNetworkOperationFactoryProtocol?,
                          accountId: String,
                          address: String,
                          polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
                          qrEncoder: WalletQREncoderProtocol,
                          sharingFactory: AccountShareFactoryProtocol,
                          referralFactory: ReferralsOperationFactoryProtocol,
                          assetsProvider: AssetProviderProtocol?,
                          marketCapService: MarketCapServiceProtocol,
                          farmingService: DemeterFarmingServiceProtocol) {}
}
private final class ProductReferrals: ReferralsOperationFactoryProtocol {
    func createReferrerBalancesOperation() -> JSONRPCListOperation<JSONScaleDecodable<SoraPassport.Balance>>? { nil }
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
private final class ProductEngine: JSONRPCEngine {
    var url: URL?; var pendingEngineRequests: [JSONRPCRequest] { [] }
    func callMethod<P: Codable, T: Decodable>(_ method: String, params: P?, options: JSONRPCOptions, completion closure: ((Result<T, Error>) -> Void)?) throws -> UInt16 { XCTFail("Unexpected network request"); throw CancellationError() }
    func subscribe<P: Codable, T: Decodable>(_ method: String, params: P?, updateClosure: @escaping (T) -> Void, failureClosure: @escaping (Error, Bool) -> Void) throws -> UInt16 { XCTFail("Unexpected subscription"); throw CancellationError() }
    func cancelForIdentifier(_ identifier: UInt16) {}
    func generateRequestId() -> UInt16 { 1 }
    func addSubscription(_ subscription: JSONRPCSubscribing) {}
    func connectIfNeeded() {}
    func disconnectIfNeeded() {}
    func unsubsribe(_ identifier: UInt16) throws {}
}
