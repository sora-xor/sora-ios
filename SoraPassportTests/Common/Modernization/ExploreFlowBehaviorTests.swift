// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause
import Combine
import SoraFoundation
import SoraKeystore
import SoraUIKit
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class ExploreFlowBehaviorTests: XCTestCase {
    private var language = "en"
    private var enabled = false
    private var animations = true
    override func setUp() {
        super.setUp()
        language = LocalizationManager.shared.selectedLocalization
        LocalizationManager.shared.selectedLocalization = "en"
        enabled = SettingsManager.shared.polkamarktEnabled
        animations = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
    }
    override func tearDown() {
        LocalizationManager.shared.selectedLocalization = language
        SettingsManager.shared.polkamarktEnabled = enabled
        UIView.setAnimationsEnabled(animations)
        super.tearDown()
    }
    private func views<T: UIView>(_ type: T.Type, in view: UIView) -> [T] {
        ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { views(type, in: $0) }
    }
    private func screen() -> (ExploreViewController, [ExploreFlowPage], ExploreFlowPage, ExploreFlowRoute) {
        let pages = (0..<3).map { _ in ExploreFlowPage() }
        let search = ExploreFlowPage()
        let route = ExploreFlowRoute()
        let screen = ExploreViewController(viewModels: pages, searchViewModel: search)
        screen.wireframe = route
        screen.loadViewIfNeeded()
        screen.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        screen.view.layoutIfNeeded()
        return (screen, pages, search, route)
    }
    private func trigger(_ button: UIBarButtonItem?) throws {
        let button = try XCTUnwrap(button)
        XCTAssertTrue(UIApplication.shared.sendAction(try XCTUnwrap(button.action), to: button.target, from: button, for: nil))
    }
    func testExploreBuildsThreeIndependentPagesAndSearch() {
        let (screen, pages, search, _) = screen()
        XCTAssertEqual(pages.map(\.setups), [1, 1, 1])
        XCTAssertEqual(search.setups, 1)
        XCTAssertEqual(views(ExplorePageView.self, in: screen.view).count, 4)
        XCTAssertEqual(views(ExplorePageView.self, in: screen.view).filter(\.isHidden).count, 1)
        screen.applyLocalization()
        XCTAssertNotNil(screen.navigationItem.title)
        XCTAssertNotNil(screen.navigationItem.searchController?.searchBar.placeholder)
    }
    func testSearchPresentationRestoresTheCatalogWhenDismissed() throws {
        let (screen, _, _, _) = screen()
        let search = try XCTUnwrap(screen.navigationItem.searchController)
        let pages = views(ExplorePageView.self, in: screen.view)
        let searchPage = try XCTUnwrap(pages.first { $0.isHidden })
        let segment = try XCTUnwrap(views(TitleSegmentControl.self, in: screen.view).first)
        screen.willPresentSearchController(search)
        XCTAssertFalse(searchPage.isHidden)
        XCTAssertTrue(segment.isHidden)
        screen.willDismissSearchController(search)
        XCTAssertTrue(searchPage.isHidden)
        XCTAssertFalse(segment.isHidden)
    }
    func testSearchDebouncesToTheLatestText() async throws {
        let (screen, _, model, _) = screen()
        let search = try XCTUnwrap(screen.navigationItem.searchController)
        search.searchBar.text = "Old"
        screen.updateSearchResults(for: search)
        search.searchBar.text = "XOR"
        screen.updateSearchResults(for: search)
        for _ in 0..<150 where model.queries.isEmpty { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertEqual(model.queries, ["xor"])
    }
    func testCreatePoolButtonRoutesFromTheCurrentScreen() throws {
        let (screen, _, _, route) = screen()
        try trigger(screen.navigationItem.rightBarButtonItem)
        XCTAssertTrue(route.liquidityController === screen)
    }
    func testPredictionMarketActionRechecksFeatureAdmission() throws {
        SettingsManager.shared.polkamarktEnabled = true
        let (screen, _, _, _) = screen()
        var opened = 0
        screen.showPredictionMarkets = { opened += 1 }
        let retained = try XCTUnwrap(screen.navigationItem.leftBarButtonItem)
        try trigger(retained)
        XCTAssertEqual(opened, 1)
        SettingsManager.shared.polkamarktEnabled = false
        try trigger(retained)
        XCTAssertEqual(opened, 1)
        screen.beginAppearanceTransition(true, animated: false)
        screen.endAppearanceTransition()
        XCTAssertNil(screen.navigationItem.leftBarButtonItem)
    }
    func testSegmentSelectionAndScrollingKeepExactlyOneSelectedTab() throws {
        let model = TitleSegmentControlViewModel()
        let delegate = ExploreFlowSegmentDelegate()
        model.delegate = delegate
        model.setup()
        func selected() -> [ExploreTabs] {
            model.snapshot.itemIdentifiers.compactMap { if case let .segment(item) = $0, item.isSelected { return item.tab }; return nil }
        }
        XCTAssertEqual(selected(), [.assets])
        model.didSelect(number: 2)
        XCTAssertEqual(selected(), [.farms])
        XCTAssertEqual(delegate.pages, [2])
        model.changeCurrentPage(to: 1)
        XCTAssertEqual(selected(), [.pools])
        XCTAssertEqual(delegate.pages, [2])
        let scroll = UIScrollView(frame: CGRect(x: 0, y: 0, width: 390, height: 500))
        let bridge = ExploreScrollViewDelegate(); bridge.delegate = model
        scroll.contentOffset.x = 780
        bridge.scrollViewDidScroll(scroll)
        XCTAssertEqual(selected(), [.farms])
        scroll.frame.size.width = 0
        bridge.scrollViewDidScroll(scroll)
        XCTAssertEqual(selected(), [.farms])
    }
    func testBouncingPastTheLastPageKeepsAValidSelectedTab() {
        let model = TitleSegmentControlViewModel(); model.setup(); model.didSelect(number: 2)
        let bridge = ExploreScrollViewDelegate(); bridge.delegate = model
        let scroll = UIScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 500))
        scroll.contentOffset.x = 275
        bridge.scrollViewDidScroll(scroll)
        let selected = model.snapshot.itemIdentifiers.compactMap { if case let .segment(item) = $0, item.isSelected { return item.tab }; return nil }
        XCTAssertEqual(selected, [.farms])
    }
    func testFallbackAssetsPublishTheSameRowsReturnedToThePage() async {
        let manager = ExploreFlowAssets()
        let prices = ExploreFlowPrices()
        let service = ExploreAssetViewModelService(marketCapService: ExploreFlowMarket(), fiatService: nil,
            itemFactory: ExploreItemFactory(assetManager: manager), assetInfos: manager.assets, priceInfoService: prices)
        let result = await service.setup()
        XCTAssertEqual(result.map(\.assetId), ["xor", "val"])
        XCTAssertEqual(service.viewModels, result)
        XCTAssertEqual(prices.requests, [["val", "xor"]])
        XCTAssertEqual(result.map(\.serialNumber), ["1", "2"])
        XCTAssertTrue(result.allSatisfy { $0.price == "" && $0.marketCap.value == nil })
    }
    func testPartialMarketDataDoesNotRemoveAnAssetFromExplore() async throws {
        let manager = ExploreFlowAssets()
        let prices = ExploreFlowPrices()
        prices.value = PriceInfo(fiatData: [PIExactFiatData(id: "val", priceUsd: try PIQuantity("3"))],
            marketCapInfo: [MarketCapInfo(assetId: "val", hourDelta: 1, liquidity: 100)])
        let service = ExploreAssetViewModelService(marketCapService: ExploreFlowMarket(), fiatService: nil,
            itemFactory: ExploreItemFactory(assetManager: manager), assetInfos: manager.assets, priceInfoService: prices)
        let rows = await service.setup()
        XCTAssertEqual(rows.map(\.assetId), ["val", "xor"])
        XCTAssertEqual(rows.map(\.serialNumber), ["1", "2"])
        XCTAssertEqual(rows.first?.price, "$3")
        XCTAssertEqual(rows.first?.marketCap.value, "$300")
        XCTAssertEqual(rows.last?.price, "")
        XCTAssertNil(rows.last?.marketCap.value)
    }
    func testFarmListSortsByValueAndPreservesUnknownPricing() async throws {
        let source = ExploreFlowFarms()
        let manager = ExploreFlowAssets()
        source.farms = [Farm(id: "unknown", name: "Unknown", baseAsset: manager.assets[0], poolAsset: nil,
                             rewardAsset: nil, tvl: 0, apr: 0, depositFee: 0, tvlIsKnown: false, aprIsKnown: false),
                        Farm(id: "known", name: "Known", baseAsset: manager.assets[0], poolAsset: manager.assets[1],
                             rewardAsset: manager.assets[0], tvl: 1200, apr: Decimal(string: "0.25")!, depositFee: 0)]
        let service = ExploreFarmsViewModelService(demeterFarmingService: source)
        service.setup()
        for _ in 0..<100 where service.viewModels.first?.farmId == nil { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertEqual(service.viewModels.map(\.farmId), ["known", "unknown"])
        XCTAssertEqual(service.viewModels.map(\.serialNumber), ["1", "2"])
        XCTAssertEqual(service.viewModels.last?.tvl, "")
        XCTAssertEqual(service.viewModels.last?.apr, "")
        XCTAssertEqual(service.viewModels.first?.apr, "25% APR")
        XCTAssertEqual(service.getFarm(with: "known")?.name, "Known")
    }
    func testFarmLoadingFailureEndsPlaceholders() async throws {
        let source = ExploreFlowFarms(); source.fails = true
        let service = ExploreFarmsViewModelService(demeterFarmingService: source)
        service.setup()
        for _ in 0..<100 where !service.viewModels.isEmpty { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertTrue(service.viewModels.isEmpty)
    }
}

private final class ExploreFlowPage: ExplorePageViewModelProtocol {
    @Published var snapshot = ExplorePageSnapshot()
    var snapshotPublisher: Published<ExplorePageSnapshot>.Publisher { $snapshot }
    var isNeedHeaders: Bool { false }
    var setups = 0
    var queries: [String] = []
    func setup() { setups += 1 }
    func didSelect(with item: ExplorePageSectionItem?) {}
    func searchTextChanged(with text: String) { queries.append(text) }
}
private final class ExploreFlowRoute: ExploreWireframeProtocol {
    weak var liquidityController: UIViewController?
    func showAssetDetails(on viewController: UIViewController?, assetId: String) {}
    func showAccountPoolDetails(on viewController: UIViewController?, poolInfo: PoolInfo) {}
    func showLiquidity(on controller: UIViewController?) { liquidityController = controller }
    func showFarmDetails(on viewController: UIViewController?, farm: Farm) {}
}
private final class ExploreFlowSegmentDelegate: TitleSegmentControlViewModelDelegate {
    var pages: [Int] = []
    func changeCurrentPage(to number: Int) { pages.append(number) }
}
private final class ExploreFlowAssets: AssetManagerProtocol {
    static var networkAssets: [AssetInfo] = []
    let assets = [AssetInfo(id: "val", symbol: "VAL", chainId: "", precision: 18, icon: nil, displayName: "Validator", visible: true),
                  AssetInfo(id: "xor", symbol: "XOR", chainId: "", precision: 18, icon: nil, displayName: "SORA", visible: true)]
    func assetInfo(for identifier: String) -> AssetInfo? { assets.first { $0.assetId == identifier } }
    func getAssetList() -> [AssetInfo]? { assets }
    func updateAssetList(_ list: [AssetInfo]) {}
    func saveAssetList(_ list: [AssetInfo]) {}
    func sortedAssets(_ list: [WalletAsset], onlyVisible: Bool) -> [WalletAsset] { list }
    func visibleCount() -> UInt { UInt(assets.count) }
    func setup(for accountSettings: SelectedWalletSettings) {}
}
private final class ExploreFlowPrices: PriceInfoServiceProtocol {
    var value = PriceInfo(fiatData: [], marketCapInfo: [])
    var requests: [[String]] = []
    func getPriceInfo(for assetIds: [String]) async -> PriceInfo { requests.append(assetIds); return value }
}
private final class ExploreFlowMarket: MarketCapServiceProtocol {
    func getMarketCap(for assets: [String]) async -> Set<MarketCapInfo> { [] }
}
private final class ExploreFlowFarms: DemeterFarmingServiceProtocol {
    var farms: [Farm] = []
    var fails = false
    func getUserFarmInfos(baseAssetId: String?, targetAssetId: String?) async -> [UserFarm] { [] }
    func loadUserFarmInfos(baseAssetId: String?, targetAssetId: String?, accountId: Data) async throws -> [UserFarm] { [] }
    func getAllFarms() async throws -> [Farm] { if fails { throw NSError(domain: "fixture", code: 1) }; return farms }
    func getFarm(with id: String) -> Farm? { farms.first { $0.id == id } }
    func getFarmDetails(baseAssetId: String, poolAssetId: String, rewardAssetId: String) async throws -> [Farm] { [] }
    func getSingleSidedXorFarmedPools(completion: @escaping ([UserFarmInfo]) -> Void) { completion([]) }
}
