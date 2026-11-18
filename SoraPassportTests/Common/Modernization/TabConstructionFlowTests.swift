// SPDX-License-Identifier: Apache-2.0
import UIKit
import BigInt
import Foundation
import IrohaCrypto
import RobinHood
import SoraFoundation
import SoraUIKit
import SSFUtils
import XCTest
@testable import SoraPassport

@MainActor
final class TabConstructionFlowTests: XCTestCase {
    func testWalletTabBuildsTheDashboardInsideNavigation() throws {
        let f = try TabFactoryFixture(); let nav = try XCTUnwrap(f.wallet() as? UINavigationController)
        XCTAssertEqual(nav.viewControllers.count, 1); XCTAssertTrue(nav.viewControllers.first is RedesignWalletViewController)
        XCTAssertEqual(nav.tabBarItem.title, R.string.localizable.walletTitle(preferredLanguages: ["en"]))
        XCTAssertNotNil(nav.tabBarItem.image); XCTAssertTrue(nav.navigationBar.isHidden)
    }
    func testWalletTabUsesSelectedLocalizationAndUpdatesIt() throws {
        let f = try TabFactoryFixture(); let nav = try XCTUnwrap(f.wallet())
        f.language.selectedLocalization = "ja"
        XCTAssertEqual(nav.tabBarItem.title, R.string.localizable.walletTitle(preferredLanguages: ["ja"]))
    }
    func testWalletTabConfiguresAPYWithItsOwnConnection() throws {
        let f = try TabFactoryFixture(); _ = f.wallet()
        XCTAssertEqual(f.apyFactories.count, 1); XCTAssertTrue(f.apyFactories.first?.engine === f.engine)
    }
    func testWalletTabRequiresConnectionBeforeConstructingServices() throws {
        let f = try TabFactoryFixture(); XCTAssertNil(f.wallet(missing: .connection)); XCTAssertTrue(f.apyFactories.isEmpty)
    }
    func testWalletTabRequiresRuntimeBeforeConstructingServices() throws {
        let f = try TabFactoryFixture(); XCTAssertNil(f.wallet(missing: .runtime)); XCTAssertTrue(f.apyFactories.isEmpty)
    }
    func testWalletTabRequiresSelectedAccountBeforeConstructingServices() throws {
        let f = try TabFactoryFixture(); XCTAssertNil(f.wallet(missing: .account)); XCTAssertTrue(f.apyFactories.isEmpty)
    }
    func testWalletReconstructionBuildsAnIndependentController() throws {
        let f = try TabFactoryFixture(); let first = try XCTUnwrap(f.wallet() as? UINavigationController)
        let second = try XCTUnwrap(f.wallet() as? UINavigationController)
        XCTAssertFalse(first === second); XCTAssertFalse(first.viewControllers.first === second.viewControllers.first)
    }
    func testMoreTabBuildsTheMoreMenuWithCorrectTitle() throws {
        let f = try TabFactoryFixture(); let nav = try XCTUnwrap(f.more() as? UINavigationController)
        XCTAssertTrue(nav.viewControllers.first is MoreMenuViewController); XCTAssertEqual(nav.viewControllers.count, 1)
        XCTAssertEqual(nav.tabBarItem.title, R.string.localizable.commonMore(preferredLanguages: ["en"]))
        XCTAssertTrue(nav.navigationBar.prefersLargeTitles); XCTAssertNotNil(nav.tabBarItem.image)
    }
    func testMoreTabInitialTitleUsesTheSuppliedLocale() throws {
        let f = try TabFactoryFixture(); f.language.selectedLocalization = "ja"
        let nav = try XCTUnwrap(f.more())
        XCTAssertEqual(nav.tabBarItem.title, R.string.localizable.commonMore(preferredLanguages: ["ja"]))
    }
    func testMoreTabKeepsItsMeaningWhenTheLanguageChanges() throws {
        let f = try TabFactoryFixture(); let nav = try XCTUnwrap(f.more())
        f.language.selectedLocalization = "ja"
        XCTAssertEqual(nav.tabBarItem.title, R.string.localizable.commonMore(preferredLanguages: ["ja"]))
        f.language.selectedLocalization = "en"
        XCTAssertEqual(nav.tabBarItem.title, R.string.localizable.commonMore(preferredLanguages: ["en"]))
    }
    func testMoreTabRejectsMissingSelectedAccount() throws {
        let f = try TabFactoryFixture(); XCTAssertNil(f.more(missingAccount: true))
    }
    func testExploreTabBuildsAllThreePagesAndSearch() throws {
        let f = try TabFactoryFixture(); let nav = try XCTUnwrap(f.explore())
        let root = try XCTUnwrap(nav.viewControllers.first as? ExploreViewController)
        XCTAssertEqual(root.viewModels.count, 3)
        XCTAssertTrue(root.viewModels[0] is ExploreAssetsPageViewModel)
        XCTAssertTrue(root.viewModels[1] is ExplorePoolsPageViewModel)
        XCTAssertTrue(root.viewModels[2] is ExploreFarmsPageViewModel)
        XCTAssertTrue(root.searchViewModel is ExploreSearchPageViewModel)
        XCTAssertNotNil(root.wireframe); XCTAssertNotNil(root.showPredictionMarkets)
        XCTAssertNotNil(nav.tabBarItem.image)
    }
    func testExploreTabRequiresConnection() throws { let f = try TabFactoryFixture(); XCTAssertNil(f.explore(missing: .connection)) }
    func testExploreTabRequiresRuntime() throws { let f = try TabFactoryFixture(); XCTAssertNil(f.explore(missing: .runtime)) }
    func testExploreTabRequiresAccount() throws { let f = try TabFactoryFixture(); XCTAssertNil(f.explore(missing: .account)) }
    func testSwapTabRequiresConnection() throws {
        let f = try TabFactoryFixture()
        XCTAssertNil(MainTabBarViewFactory.createSwapController(walletContext: f.context, assetManager: f.assets, assetsProvider: f.balances, localizationManager: f.language, connection: nil, fiatService: TabFiat(), marketCapService: TabMarket()))
    }
    func testSwapTabConstructsTheRealSwapScreen() throws {
        let f = try TabFactoryFixture()
        let root = try XCTUnwrap(MainTabBarViewFactory.createSwapController(walletContext: f.context, assetManager: f.assets, assetsProvider: f.balances, localizationManager: f.language, connection: f.engine, fiatService: TabFiat(), marketCapService: TabMarket()))
        XCTAssertTrue(root is BlurViewController)
        let navigation = try XCTUnwrap(root.children.first as? UINavigationController)
        XCTAssertTrue(navigation.viewControllers.first is PolkaswapViewController)
        f.language.selectedLocalization = "ja"
        XCTAssertEqual(root.tabBarItem.title, R.string.localizable.commonAssets(preferredLanguages: ["ja"]))
    }
    func testDisclaimerIsContainedInAFullScreenBlurPresentation() throws {
        var proceeded = false
        let root = try XCTUnwrap(MainTabBarViewFactory.swapDisclamerController { proceeded = true })
        XCTAssertTrue(root is BlurViewController); XCTAssertEqual(root.modalPresentationStyle, .overFullScreen)
        let child = try XCTUnwrap(root.children.first as? SwapDisclaimerViewController)
        XCTAssertTrue(child.parent === root); XCTAssertFalse(proceeded)
        let viewModel = try XCTUnwrap(child.viewModel as? SwapDisclaimerViewModel)
        XCTAssertTrue(viewModel.view === child); XCTAssertNotNil(viewModel.completion)
    }
    func testDisclaimerBuildsOneConsentRowWithoutAdvancingAutomatically() throws {
        let model = SwapDisclaimerViewModel(); let view = TabDisclaimerView()
        model.view = view; var completed = 0; model.completion = { completed += 1 }
        var items = [SoramitsuTableViewItemProtocol](); model.setupItems = { items = $0 }
        model.viewDidLoad(); XCTAssertEqual(items.count, 1); XCTAssertEqual(completed, 0)
        let item = try XCTUnwrap(items.first as? SwapDisclaimerItem)
        item.closeButtonHandler?(); XCTAssertEqual(view.dismissals, 1); XCTAssertEqual(completed, 1)
    }
    func testDisclaimerCallbackDoesNotRetainItsViewModel() throws {
        var model: SwapDisclaimerViewModel? = SwapDisclaimerViewModel(); weak var weakModel = model
        var items = [SoramitsuTableViewItemProtocol](); model?.setupItems = { items = $0 }
        model?.viewDidLoad(); model = nil
        XCTAssertNil(weakModel); (items.first as? SwapDisclaimerItem)?.closeButtonHandler?()
    }
}

@MainActor
private final class TabFactoryFixture {
    enum Missing { case connection, runtime, account }
    let context = WalletContextMock(), assets = TabAssets(), balances = TabBalances(), pools = TabPools(), farms = TabFarms(), engine = TabEngine(), runtime = TabRuntime(), edit = TabEdit(), fees = TabFees()
    let language = LocalizationManager(localization: "en")!
    let account: AccountItem
    let accountSettings: WalletAccountSettings
    let items: PoolsItemService
    var apyFactories = [PolkaswapNetworkOperationFactory]()
    init() throws {
        let key = Data(repeating: 0x42, count: 32)
        account = AccountItem(address: try SS58AddressFactory().addressFromAccountId(data: key, type: SoraPassport.Chain.sora.addressType()), cryptoType: .sr25519, networkType: SoraPassport.Chain.sora.addressType(), username: "Public fixture", publicKeyData: key, settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0, isSelected: true)
        accountSettings = WalletAccountSettings(accountId: key.toHex(), assets: [WalletAsset(identifier: WalletAssetId.xor.rawValue, name: LocalizableResource { _ in "XOR" }, symbol: "XOR", precision: 18)])
        items = PoolsItemService(marketCapService: TabMarket(), fiatService: TabFiat(), poolViewModelsFactory: PoolViewModelFactory(walletAssets: assets.assets, assetManager: assets, fiatService: TabFiat()))
    }
    func wallet(missing: Missing? = nil) -> UIViewController? {
        MainTabBarViewFactory.createWalletRedesignController(walletContext: context, assetManager: assets, poolsService: pools, assetsProvider: balances, poolsViewModelService: items, editViewService: edit, accountSettings: accountSettings, farmingService: farms, feeProvider: fees, localizationManager: language, connection: missing == .connection ? nil : engine, runtimeRegistry: missing == .runtime ? nil : runtime, fiatService: TabFiat(), marketCapService: TabMarket(), selectedAccount: missing == .account ? nil : account, configureAPY: { [weak self] in self?.apyFactories.append($0) })
    }
    func more(missingAccount: Bool = false) -> UIViewController? {
        MainTabBarViewFactory.createMoreMenuController(for: language, walletContext: context, assetsProvider: balances, accountSettings: accountSettings, assetManager: assets, fiatService: TabFiat(), selectedAccount: missingAccount ? nil : account)
    }
    func explore(missing: Missing? = nil) -> UINavigationController? {
        MainTabBarViewFactory.createInvestController(walletContext: context, assetManager: assets, networkFacade: context.networkOperationFactory, polkaswapNetworkFacade: PolkaswapNetworkOperationFactory(engine: engine), poolsService: pools, accountSettings: accountSettings, assetsProvider: balances, farmingService: farms, feeProvider: fees, walletAssets: assets.assets, connection: missing == .connection ? nil : engine, runtimeRegistry: missing == .runtime ? nil : runtime, fiatService: TabFiat(), marketCapService: TabMarket(), selectedAccount: missing == .account ? nil : account)
    }
}
private final class TabFees: FeeProviderProtocol {
    func getFee(for type: TransactionType, completion: @escaping (Decimal) -> Void) { completion(1) }
    func getFee(for type: InputRewardAmountType, completion: @escaping (Decimal) -> Void) { completion(1) }
    func getFee(for call: any RuntimeCallable) async -> Decimal { 1 }
    func getFee(for type: TransactionType) async -> Decimal { 1 }
}
private final class TabRuntime: RuntimeProviderProtocol {
    let chainId = PIIndexerClient.soraMainnetGenesis
    var snapshot: RuntimeSnapshot? { nil }
    func setup() {}
    func setupHot() {}
    func replaceTypesUsage(_ usage: SoraPassport.ChainModel.TypesUsage) {}
    func cleanup() {}
    func fetchCoderFactoryOperation(with timeout: TimeInterval, closure: SoraPassport.RuntimeMetadataClosure?) -> BaseOperation<RuntimeCoderFactoryProtocol> { ClosureOperation { throw CancellationError() } }
}
private final class TabDisclaimerView: UIViewController, SwapDisclaimerViewProtocol {
    var dismissals = 0
    func dismissDisclaimer(completion: (() -> Void)?) { dismissals += 1; completion?() }
}

private final class TabEdit: EditViewServiceProtocol { var viewModels: [EnabledViewModel] = []; var completion: ((Bool) -> Void)?; func loadModels(completion: ((Bool) -> Void)?) { self.completion = completion }; func loaded(pools: [PoolInfo]) {} }

private final class TabAssets: AssetManagerProtocol {
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

private actor TabFiat: FiatServiceProtocol { func getFiat() async -> [PIExactFiatData] { [] } }

private final class TabMarket: MarketCapServiceProtocol { func getMarketCap(for assets: [String]) async -> Set<MarketCapInfo> { [] } }

private final class TabBalances: AssetProviderProtocol {
    var balances: [BalanceData] = []; var unavailable: Set<String> = []; var additions = 0
    func getBalances(with assetIds: [String]) -> [BalanceData] { balances.filter { assetIds.contains($0.identifier) } }
    func unavailableBalanceAssetIds(among assetIds: [String]) -> Set<String> { unavailable.intersection(assetIds) }
    func add(observer: AssetProviderObserverProtocol) { additions += 1 }
    func remove(observer: AssetProviderObserverProtocol) {}
}

private final class TabPools: PoolsServiceInputProtocol {
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
    func loadPools(currentAsset _: AssetInfo) -> [PoolInfo] { [] }
    func loadTargetPools(for _: String) -> [PoolInfo] { [] }
    func appendDelegate(delegate _: PoolsServiceOutput) {}
}

private final class TabFarms: DemeterFarmingServiceProtocol {
    func getUserFarmInfos(baseAssetId _: String?, targetAssetId _: String?) async -> [UserFarm] { [] }
    func loadUserFarmInfos(baseAssetId _: String?, targetAssetId _: String?, accountId _: Data) async throws -> [UserFarm] { [] }
    func getAllFarms() async throws -> [Farm] { [] }
    func getFarm(with _: String) -> Farm? { nil }
    func getFarmDetails(baseAssetId _: String, poolAssetId _: String, rewardAssetId _: String) async throws -> [Farm] { [] }
    func getSingleSidedXorFarmedPools(completion: @escaping ([UserFarmInfo]) -> Void) { completion([]) }
}

private final class TabEngine: JSONRPCEngine {
    var url: URL?; var pendingEngineRequests: [JSONRPCRequest] { [] }
    func callMethod<P: Codable, T: Decodable>(_ method: String, params: P?, options: JSONRPCOptions, completion closure: ((Result<T, Error>) -> Void)?) throws -> UInt16 { if method.contains("submit") { XCTFail("No transport is permitted during tab construction") }; throw URLError(.notConnectedToInternet) }
    func subscribe<P: Codable, T: Decodable>(_ method: String, params: P?, updateClosure: @escaping (T) -> Void, failureClosure: @escaping (Error, Bool) -> Void) throws -> UInt16 { throw URLError(.notConnectedToInternet) }
    func cancelForIdentifier(_ identifier: UInt16) {}
    func generateRequestId() -> UInt16 { 1 }
    func addSubscription(_ subscription: JSONRPCSubscribing) {}
    func connectIfNeeded() {}
    func disconnectIfNeeded() {}
    func unsubsribe(_ identifier: UInt16) throws {}
}
