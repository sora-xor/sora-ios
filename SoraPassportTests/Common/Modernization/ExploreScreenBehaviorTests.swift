// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0
import Combine
import SoraFoundation
import SoraUIKit
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class ExploreScreenBehaviorTests: XCTestCase {
    private var previousLanguage = "en"
    override func setUp() { super.setUp(); previousLanguage = LocalizationManager.shared.selectedLocalization; LocalizationManager.shared.selectedLocalization = "en" }
    override func tearDown() { LocalizationManager.shared.selectedLocalization = previousLanguage; super.tearDown() }
    private var xor: ExploreAssetViewModel {
        ExploreAssetViewModel(assetId: "xor", symbol: "XOR", title: "SORA", price: "$2", serialNumber: "1", marketCap: .loaded("$200"), deltaPrice: .error)
    }
    private var val: ExploreAssetViewModel {
        ExploreAssetViewModel(assetId: "val", symbol: "VAL", title: "Validator", price: "$3", serialNumber: "2", marketCap: .error, deltaPrice: .error)
    }
    private var pool: ExplorePoolViewModel {
        ExplorePoolViewModel(poolId: "xor-val", title: "XOR-VAL", tvl: "$400", serialNumber: "1", apy: "4% APY", baseAssetId: "xor", targetAssetId: "val")
    }
    private var farm: ExploreFarmViewModel {
        ExploreFarmViewModel(farmId: "xor-demeter", title: "XOR Demeter", tvl: "$500 TVL", serialNumber: "1", apr: "5% APR")
    }
    private func search() -> (ExploreSearchPageViewModel, ExplorationRoute) {
        let factory = ExploreItemFactory(assetManager: ExplorationAssets())
        let assets = ExploreAssetViewModelService(marketCapService: ExplorationMarket(), fiatService: nil, itemFactory: factory, assetInfos: [])
        let pools = ExplorePoolsViewModelService(itemFactory: factory, poolsService: ExplorationPools(), apyService: ExplorationAPY())
        let farms = ExploreFarmsViewModelService(demeterFarmingService: ExplorationFarms())
        assets.viewModels = [xor, val]; pools.viewModels = [pool]; farms.viewModels = [farm]
        let route = ExplorationRoute()
        return (ExploreSearchPageViewModel(wireframe: route, assetViewModelsService: assets, poolViewModelsService: pools, farmsViewModelsService: farms), route)
    }
    private func snapshot(_ groups: [[ExplorePageSectionItem]]) -> ExplorePageSnapshot {
        var result = ExplorePageSnapshot()
        for items in groups { let section = ExplorePageSection(items: items); result.appendSections([section]); result.appendItems(items, toSection: section) }
        return result
    }
    private func views<T: UIView>(_ type: T.Type, in view: UIView) -> [T] {
        ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { views(type, in: $0) }
    }
    private func settle() async { try? await Task.sleep(nanoseconds: 40_000_000) }
    private func texts(_ view: UIView) -> [String] { views(UILabel.self, in: view).compactMap { $0.text ?? $0.attributedText?.string } }

    func testSearchSetupDisplaysAlreadyLoadedCatalog() {
        let (model, _) = search()
        model.setup()
        XCTAssertEqual(model.snapshot.numberOfSections, 3)
        XCTAssertEqual(model.snapshot.numberOfItems, 4)
    }
    func testSearchNormalizesWhitespaceAndCaseAcrossAllKinds() {
        let (model, _) = search(); model.setup()
        model.searchTextChanged(with: "  XOR  ")
        XCTAssertEqual(model.snapshot.numberOfSections, 3)
        XCTAssertEqual(model.snapshot.numberOfItems, 3)
        model.searchTextChanged(with: "VALIDATOR")
        XCTAssertEqual(model.snapshot.numberOfItems, 1)
        model.searchTextChanged(with: "no match")
        XCTAssertEqual(model.snapshot.numberOfSections, 0)
        model.searchTextChanged(with: "")
        XCTAssertEqual(model.snapshot.numberOfItems, 4)
    }
    func testRefreshingPricesPreservesTheCurrentSearchFilter() {
        let (model, _) = search(); model.setup(); model.searchTextChanged(with: "validator")
        XCTAssertEqual(model.snapshot.numberOfItems, 1)
        var updated = xor; updated.price = "$8"
        model.assetViewModelsService.viewModels = [updated, val]
        XCTAssertEqual(model.snapshot.numberOfItems, 1)
        guard case let .asset(item)? = model.snapshot.itemIdentifiers.first else { return XCTFail("Expected the matching asset") }
        XCTAssertEqual(item.assetViewModel.assetId, "val")
        model.poolViewModelsService.viewModels = []
        XCTAssertEqual(model.snapshot.numberOfItems, 1)
    }
    func testRepeatedSetupKeepsOnlyOneCatalogSubscription() {
        let (model, _) = search(); model.setup(); model.setup()
        var deliveries = 0
        let sink = model.snapshotPublisher.dropFirst().sink { _ in deliveries += 1 }
        model.assetViewModelsService.viewModels = [val]
        XCTAssertEqual(deliveries, 1)
        withExtendedLifetime(sink) {}
    }
    func testSearchRoutesAssetAndPoolSelectionsAndIgnoresPlaceholders() {
        let (model, route) = search()
        model.didSelect(with: .asset(ExploreAssetItem(serialNumber: "1", assetViewModel: xor)))
        model.didSelect(with: .asset(ExploreAssetItem(serialNumber: "2", assetViewModel: ExploreAssetViewModel())))
        model.didSelect(with: .pool(ExplorePoolItem(serialNumber: "1", poolViewModel: pool)))
        model.didSelect(with: .farm(ExploreFarmItem(serialNumber: "1", farmViewModel: farm)))
        model.didSelect(with: nil)
        XCTAssertEqual(route.assets, ["xor"])
        XCTAssertEqual(route.pools.map(\.poolId), ["xor-val"])
        XCTAssertTrue(route.farms.isEmpty)
    }
    func testExplorePageRendersHeaderAssetPoolAndFarmCells() async throws {
        let model = ExplorationPage(headers: false)
        model.snapshot = snapshot([[
            .header(HeaderItem(titleText: "Markets", subTitleText: "Browse fixtures")),
            .asset(ExploreAssetItem(serialNumber: "1", assetViewModel: xor)),
            .pool(ExplorePoolItem(serialNumber: "1", poolViewModel: pool)),
            .farm(ExploreFarmItem(serialNumber: "1", farmViewModel: farm))]])
        let page = ExplorePageView(); page.viewModel = model
        await settle()
        XCTAssertEqual(page.tableView.numberOfRows(inSection: 0), 4)
        let cells = (0..<4).compactMap { page.tableView.dataSource?.tableView(page.tableView, cellForRowAt: IndexPath(row: $0, section: 0)) }
        XCTAssertEqual(cells.count, 4)
        XCTAssertTrue(texts(cells[0]).contains("Browse fixtures"))
        XCTAssertTrue(texts(cells[1]).contains("SORA"))
        XCTAssertTrue(texts(cells[2]).contains("XOR-VAL"))
        XCTAssertTrue(texts(cells[3]).contains("XOR Demeter"))
        XCTAssertTrue(page.emptyListLabel.isHidden)
        page.tableView(page.tableView, didSelectRowAt: IndexPath(row: 1, section: 0))
        XCTAssertEqual(model.selected.count, 1)
        model.snapshot = ExplorePageSnapshot()
        await settle()
        XCTAssertFalse(page.emptyListLabel.isHidden)
    }
    func testReplacingPageModelStopsOldPublisherFromOverwritingNewResults() async {
        let first = ExplorationPage(headers: true)
        first.snapshot = snapshot([[.asset(ExploreAssetItem(serialNumber: "1", assetViewModel: xor))]])
        let second = ExplorationPage(headers: true)
        second.snapshot = snapshot([[.pool(ExplorePoolItem(serialNumber: "1", poolViewModel: pool))]])
        let page = ExplorePageView(); page.viewModel = first; await settle()
        page.viewModel = second; await settle()
        first.snapshot = ExplorePageSnapshot(); await settle()
        XCTAssertEqual(page.tableView.numberOfSections, 1)
        XCTAssertTrue(page.emptyListLabel.isHidden)
        page.tableView(page.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
        guard case .pool? = second.selected.first else { return XCTFail("Old publisher replaced the new page") }
        XCTAssertTrue(first.selected.isEmpty)
    }
    func testFilteredSectionHeadersDescribeTheirActualItems() async throws {
        let model = ExplorationPage(headers: true)
        let page = ExplorePageView(); page.viewModel = model
        for (item, title) in [(ExplorePageSectionItem.pool(ExplorePoolItem(serialNumber: "1", poolViewModel: pool)), "Pools"),
                              (.farm(ExploreFarmItem(serialNumber: "1", farmViewModel: farm)), "Farms"),
                              (.asset(ExploreAssetItem(serialNumber: "1", assetViewModel: xor)), "Assets")] {
            model.snapshot = snapshot([[item]]); await settle()
            let header = try XCTUnwrap(page.tableView(page.tableView, viewForHeaderInSection: 0))
            XCTAssertTrue(texts(header).contains(title.uppercased()), "Expected \(title), received \(texts(header))")
        }
    }
    func testChangingToHeaderedPageRestoresHeaderHeight() async {
        let page = ExplorePageView()
        page.viewModel = ExplorationPage(headers: false)
        await settle()
        XCTAssertEqual(page.tableView.sectionHeaderHeight, 0)
        page.viewModel = ExplorationPage(headers: true)
        await settle()
        XCTAssertNotEqual(page.tableView.sectionHeaderHeight, 0)
    }
    func testLoadingToUnavailableAssetStateHasDifferentDiffableIdentity() {
        var loading = xor; loading.marketCap = .loading
        var unavailable = loading; unavailable.marketCap = .error
        XCTAssertNotEqual(loading, unavailable)
        var deltaLoading = xor; deltaLoading.deltaPrice = .loading
        var deltaUnavailable = deltaLoading; deltaUnavailable.deltaPrice = .error
        XCTAssertNotEqual(deltaLoading, deltaUnavailable)
        XCTAssertEqual(Set([loading, unavailable]).count, 2)
        XCTAssertEqual(Set([deltaLoading, deltaUnavailable]).count, 2)
    }
}

private final class ExplorationPage: ExplorePageViewModelProtocol {
    @Published var snapshot = ExplorePageSnapshot()
    var snapshotPublisher: Published<ExplorePageSnapshot>.Publisher { $snapshot }
    let isNeedHeaders: Bool
    var selected: [ExplorePageSectionItem] = []
    init(headers: Bool) { isNeedHeaders = headers }
    func setup() {}
    func didSelect(with item: ExplorePageSectionItem?) { if let item { selected.append(item) } }
    func searchTextChanged(with text: String) {}
}
private final class ExplorationRoute: ExploreWireframeProtocol {
    var assets: [String] = []; var pools: [PoolInfo] = []; var farms: [Farm] = []
    func showAssetDetails(on viewController: UIViewController?, assetId: String) { assets.append(assetId) }
    func showAccountPoolDetails(on viewController: UIViewController?, poolInfo: PoolInfo) { pools.append(poolInfo) }
    func showLiquidity(on controller: UIViewController?) {}
    func showFarmDetails(on viewController: UIViewController?, farm: Farm) { farms.append(farm) }
}
private final class ExplorationAssets: AssetManagerProtocol {
    static var networkAssets: [AssetInfo] = []
    func assetInfo(for identifier: String) -> AssetInfo? { nil }
    func getAssetList() -> [AssetInfo]? { [] }
    func updateAssetList(_ list: [AssetInfo]) {}
    func saveAssetList(_ list: [AssetInfo]) {}
    func sortedAssets(_ list: [WalletAsset], onlyVisible: Bool) -> [WalletAsset] { list }
    func visibleCount() -> UInt { 0 }
    func setup(for accountSettings: SelectedWalletSettings) {}
}
private final class ExplorationMarket: MarketCapServiceProtocol {
    func getMarketCap(for assets: [String]) async -> Set<MarketCapInfo> { [] }
}
private final class ExplorationPools: ExplorePoolsServiceInputProtocol {
    func getPools(with fiat: [PIExactFiatData]) async throws -> [ExplorePool] { [] }
}
private actor ExplorationAPY: APYServiceProtocol {
    func getApy(for baseAssetId: String, targetAssetId: String) async -> Decimal? { nil }
    func setup(factory: PolkaswapNetworkOperationFactoryProtocol) {}
}
private final class ExplorationFarms: DemeterFarmingServiceProtocol {
    func getUserFarmInfos(baseAssetId: String?, targetAssetId: String?) async -> [UserFarm] { [] }
    func loadUserFarmInfos(baseAssetId: String?, targetAssetId: String?, accountId: Data) async throws -> [UserFarm] { [] }
    func getAllFarms() async throws -> [Farm] { [] }
    func getFarm(with id: String) -> Farm? { nil }
    func getFarmDetails(baseAssetId: String, poolAssetId: String, rewardAssetId: String) async throws -> [Farm] { [] }
    func getSingleSidedXorFarmedPools(completion: @escaping ([UserFarmInfo]) -> Void) { completion([]) }
}
