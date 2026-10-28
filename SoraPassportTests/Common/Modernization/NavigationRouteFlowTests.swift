// SPDX-License-Identifier: BSD-4-Clause
import BigInt
import Foundation
import IrohaCrypto
import RobinHood
import SoraFoundation
import SoraUIKit
import SSFUtils
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class NavigationRouteFlowTests: XCTestCase {
    private var selected: AccountItem?
    override func setUp() { super.setUp(); selected = SelectedWalletSettings.shared.currentAccount }
    override func tearDown() { SelectedWalletSettings.shared.commitInternalValue(selected); super.tearDown() }
    private func make() throws -> RouteFixture { let f = try RouteFixture(); SelectedWalletSettings.shared.commitInternalValue(f.account); return f }
    private func screen<T: UIViewController>(_ type: T.Type, host: RouteHost) throws -> T {
        let container = try XCTUnwrap(host.shown.last as? BlurViewController)
        XCTAssertEqual(container.modalPresentationStyle, .overFullScreen)
        let nav = try XCTUnwrap(container.children.first as? UINavigationController)
        XCTAssertEqual(nav.viewControllers.count, 1)
        return try XCTUnwrap(nav.viewControllers.first as? T)
    }
    func testAssetReceiveOpensAReceiveControllerInANavigationContainer() throws {
        let f = try make(); let route = f.assetRoute(); route.showReceive()
        let view = try screen(ReceiveViewController.self, host: f.host)
        XCTAssertNotNil(view.viewModel); XCTAssertTrue(view.parent is UINavigationController)
    }
    func testAssetReceiveUsesTheBoundWalletAndAssetEvenAfterSelectionChanges() async throws {
        let f = try make(); let route = f.assetRoute(); SelectedWalletSettings.shared.commitInternalValue(nil); route.showReceive()
        let view = try screen(ReceiveViewController.self, host: f.host); view.loadViewIfNeeded()
        for _ in 0..<100 { if !f.encoder.infos.isEmpty { break }; try? await Task.sleep(nanoseconds: 10_000_000) }
        let info = try XCTUnwrap(f.encoder.infos.first); XCTAssertEqual(info.accountId, f.account.publicKeyData.toHex()); XCTAssertEqual(info.assetId, WalletAssetId.val.rawValue)
    }
    func testFrozenBalanceOpensOnlyTheRequestedDetails() throws {
        let f = try make(); let route = f.assetRoute()
        let row = BalanceDetailViewModel(title: .init(text: "Locked", fontData: FontType.textS, textColor: .fgPrimary), amount: .init(text: "3 VAL", fontData: FontType.textS, textColor: .fgPrimary), fiatAmount: .init(text: "$6", fontData: FontType.textS, textColor: .fgPrimary))
        route.showFrozenBalance(frozenDetailViewModels: [row])
        let container = try XCTUnwrap(f.host.shown.last as? BlurViewController)
        let view = try XCTUnwrap(container.children.first as? BalanceDetailsViewController); view.loadViewIfNeeded()
        XCTAssertEqual(container.modalPresentationStyle, .overFullScreen)
        let labels = descendants(UILabel.self, view.view).compactMap(\.text)
        XCTAssertTrue(labels.contains("Locked")); XCTAssertTrue(labels.contains("3 VAL")); XCTAssertTrue(labels.contains("$6"))
    }
    func testEmptyFrozenBalanceDoesNotInventRows() throws {
        let f = try make(); f.assetRoute().showFrozenBalance(frozenDetailViewModels: [])
        let view = try XCTUnwrap(f.host.shown.last?.children.first as? BalanceDetailsViewController); view.loadViewIfNeeded()
        XCTAssertTrue(descendants(BalanceDetailView.self, view.view).isEmpty)
    }
    func testAssetPoolDetailsRequiresItsNetworkFactory() throws {
        let f = try make(); f.assetRoute(network: false).showPoolDetails(poolInfo: f.pool, poolsService: f.pools)
        XCTAssertTrue(f.host.shown.isEmpty)
    }
    func testAssetPoolDetailsOpensThePoolDetailsDestination() throws {
        let f = try make(); f.assetRoute().showPoolDetails(poolInfo: f.pool, poolsService: f.pools)
        let view = try screen(PoolDetailsViewController.self, host: f.host); XCTAssertTrue(view.viewModel is PoolDetailsViewModel)
    }
    func testAssetSwapOpensTheSwapDestination() throws {
        let f = try make(); f.assetRoute().showSwap()
        let view = try screen(PolkaswapViewController.self, host: f.host); XCTAssertNotNil(view.viewModel)
    }
    func testFarmStakeRoutePassesTheExactFarmAndPoolToTheEditor() throws {
        let f = try make(); f.farmRoute.showStakeDetails(on: f.host, farm: f.farm, poolInfo: f.pool, assetsProvider: f.balances, detailsFactory: f.details)
        let view = try screen(EditFarmViewController.self, host: f.host); let model = try XCTUnwrap(view.viewModel as? EditFarmViewModel)
        XCTAssertEqual(model.farm.id, f.farm.id); XCTAssertEqual(model.poolInfo.identifier, f.pool.identifier); XCTAssertTrue(model.view === view)
    }
    func testFarmStakeRouteDoesNotOpenAnEditorWithoutPoolState() throws {
        let f = try make(); f.farmRoute.showStakeDetails(on: f.host, farm: f.farm, poolInfo: nil, assetsProvider: f.balances, detailsFactory: f.details)
        XCTAssertTrue(f.host.shown.isEmpty)
    }
    func testFarmClaimRoutePassesTheExactFarmAndPoolToConfirmation() throws {
        let f = try make(); f.farmRoute.showClaimRewards(on: f.host, farm: f.farm, poolInfo: f.pool, fiatService: f.fiat, assetsProvider: f.balances, detailsFactory: f.details)
        let view = try screen(ClaimRewardsViewController.self, host: f.host); let model = try XCTUnwrap(view.viewModel as? ClaimRewardsViewModel)
        XCTAssertEqual(model.farm.id, f.farm.id); XCTAssertEqual(model.poolInfo.identifier, f.pool.identifier); XCTAssertTrue(model.view === view)
    }
    func testFarmClaimRouteDoesNotOpenConfirmationWithoutPoolState() throws {
        let f = try make(); f.farmRoute.showClaimRewards(on: f.host, farm: f.farm, poolInfo: nil, fiatService: f.fiat, assetsProvider: f.balances, detailsFactory: f.details)
        XCTAssertTrue(f.host.shown.isEmpty)
    }
    func testFarmPoolRouteOpensPoolDetailsWhenDependenciesArePresent() throws {
        let f = try make(); f.showFarmPool(); _ = try screen(PoolDetailsViewController.self, host: f.host)
    }
    func testFarmPoolRouteRequiresPoolState() throws { let f = try make(); f.showFarmPool(missing: .pool); XCTAssertTrue(f.host.shown.isEmpty) }
    func testFarmPoolRouteRequiresPoolService() throws { let f = try make(); f.showFarmPool(missing: .pools); XCTAssertTrue(f.host.shown.isEmpty) }
    func testFarmPoolRouteRequiresAssetBalances() throws { let f = try make(); f.showFarmPool(missing: .balances); XCTAssertTrue(f.host.shown.isEmpty) }
    func testFarmPoolRouteRequiresFiatService() throws { let f = try make(); f.showFarmPool(missing: .fiat); XCTAssertTrue(f.host.shown.isEmpty) }
    func testFarmPoolRouteRequiresNetworkFactory() throws { let f = try make(); f.showFarmPool(missing: .network); XCTAssertTrue(f.host.shown.isEmpty) }
    func testPoolFarmRoutePassesTheSelectedFarmToItsDetailsScreen() throws {
        let f = try make(); f.poolRoute.showFarmDetails(on: f.host, poolsService: f.pools, fiatService: f.fiat, assetManager: f.assets, farmingService: f.farms, poolInfo: f.pool, farm: f.farm)
        let view = try screen(FarmDetailsViewController.self, host: f.host); let model = try XCTUnwrap(view.viewModel as? FarmDetailsViewModel)
        XCTAssertEqual(model.farm.id, f.farm.id); XCTAssertEqual(model.poolInfo?.identifier, f.pool.identifier); XCTAssertTrue(model.view === view)
    }
    func testPoolFactoryWiresTheDismissCallbackToItsModel() throws {
        let f = try make(); var dismissals = 0
        let view = try XCTUnwrap(PoolDetailsViewFactory.createView(poolInfo: f.pool, assetManager: f.assets, fiatService: f.fiat, poolsService: f.pools, providerFactory: f.provider, operationFactory: f.network, assetsProvider: f.balances, marketCapService: f.market, farmingService: f.farms, feeProvider: f.fees, dismissHandler: { dismissals += 1 }))
        let model = try XCTUnwrap(view.viewModel as? PoolDetailsViewModel); model.dismissed(); XCTAssertEqual(dismissals, 1); XCTAssertTrue(model.view === view)
    }
    func testRoutesHoldTheirPresentingControllerWeakly() throws {
        let f = try make(); let route = f.assetRoute(); var host: RouteHost? = RouteHost(); weak var observed = host
        route.controller = host; host = nil; XCTAssertNil(observed)
        route.showReceive(); XCTAssertTrue(f.host.shown.isEmpty)
    }
    func testWalletPoolRouteOpensTheRequestedPool() throws {
        let f = try make(); f.walletRoute.showPoolDetails(on: f.host, poolInfo: f.pool, assetManager: f.assets, fiatService: f.fiat, poolsService: f.pools, providerFactory: f.provider, operationFactory: f.network, assetsProvider: f.balances, marketCapService: f.market, farmingService: f.farms)
        let view = try screen(PoolDetailsViewController.self, host: f.host); XCTAssertTrue(view.viewModel is PoolDetailsViewModel)
    }
    func testWalletAssetListRouteBindsTheListModelToItsController() throws {
        let f = try make(); f.showAssetList()
        let view = try screen(ProductListViewController.self, host: f.host); let model = try XCTUnwrap(view.viewModel as? ManageAssetListViewModel); XCTAssertTrue(model.view === view)
    }
    func testWalletPoolListRouteBindsTheListModelToItsController() throws {
        let f = try make(); f.showPoolList()
        let view = try screen(ProductListViewController.self, host: f.host); let model = try XCTUnwrap(view.viewModel as? PoolListViewModel); XCTAssertTrue(model.view === view); XCTAssertEqual(f.pools.delegates, 1)
    }
    func testWalletQRRouteWiresItsCloseCallback() throws {
        let f = try make(); var closes = 0; f.showQR { closes += 1 }
        let view = try screen(GenerateQRViewController.self, host: f.host); view.viewModel.closeHadler?(); XCTAssertEqual(closes, 1)
    }
    func testQRAssetSelectionPreservesTheAllowedAssetIdentifiers() throws {
        let f = try make(); let route = GenerateQRWireframe(controller: f.host)
        route.showAssetSelection(assetManager: f.assets, fiatService: f.fiat, assetViewModelFactory: f.assetFactory, assetsProvider: f.balances, assetIds: [WalletAssetId.val.rawValue], marketCapService: f.market) { _ in }
        let view = try screen(ProductListViewController.self, host: f.host); let model = try XCTUnwrap(view.viewModel as? SelectAssetViewModel)
        XCTAssertEqual(model.assetIds, [WalletAssetId.val.rawValue])
    }
    func testQRAssetSelectionHandsTheSelectedTokenBackToItsCaller() throws {
        let f = try make(); var selected: String?; GenerateQRWireframe(controller: f.host).showAssetSelection(assetManager: f.assets, fiatService: f.fiat, assetViewModelFactory: f.assetFactory, assetsProvider: f.balances, assetIds: [WalletAssetId.val.rawValue], marketCapService: f.market) { selected = $0 }
        let view = try screen(ProductListViewController.self, host: f.host); let model = try XCTUnwrap(view.viewModel as? SelectAssetViewModel); model.selectionCompletion?(WalletAssetId.val.rawValue); XCTAssertEqual(selected, WalletAssetId.val.rawValue)
    }
    func testQRReceiveRoutePushesTheExactRequestedAmount() async throws {
        let f = try make(); let nav = UINavigationController(rootViewController: f.host)
        GenerateQRWireframe(controller: f.host).showReceive(selectedAsset: f.assets.assets[1], accountId: f.account.publicKeyData.toHex(), address: f.account.address, amount: AmountDecimal(string: "1.000000000000000001"), qrEncoder: f.encoder, sharingFactory: RouteShare(), fiatService: f.fiat, assetProvider: f.balances, assetManager: f.assets)
        let view = try XCTUnwrap(nav.topViewController as? ReceiveViewController); view.loadViewIfNeeded()
        for _ in 0..<100 { if !f.encoder.infos.isEmpty { break }; try? await Task.sleep(nanoseconds: 10_000_000) }
        let info = try XCTUnwrap(f.encoder.infos.first); XCTAssertEqual(info.amount?.decimalValue, Decimal(string: "1.000000000000000001")); XCTAssertEqual(info.assetId, WalletAssetId.val.rawValue)
    }
    func testQRReceiveRouteDoesNotPresentWithoutANavigationStack() throws {
        let f = try make(); GenerateQRWireframe(controller: f.host).showReceive(selectedAsset: f.assets.assets[1], accountId: f.account.publicKeyData.toHex(), address: f.account.address, amount: nil, qrEncoder: f.encoder, sharingFactory: RouteShare(), fiatService: f.fiat, assetProvider: f.balances, assetManager: f.assets)
        XCTAssertTrue(f.host.shown.isEmpty)
    }
    func testQRScannerDoesNotOpenAfterSelectedWalletIsRemoved() throws {
        let f = try make(); SelectedWalletSettings.shared.commitInternalValue(nil)
        GenerateQRWireframe(controller: f.host).showScanQR(on: f.host, networkFacade: f.network, assetManager: f.assets, qrEncoder: f.encoder, sharingFactory: RouteShare(), assetsProvider: f.balances, providerFactory: f.provider, feeProvider: f.fees, marketCapService: f.market) { _ in XCTFail("No scan expected") }
        XCTAssertTrue(f.host.shown.isEmpty)
    }
    func testQRFeeFailurePresentsCancelAndExplicitRetry() throws {
        let f = try make(); var retries = 0; GenerateQRWireframe(controller: f.host).showFeeEstimationError(on: f.host) { retries += 1 }
        let alert = try XCTUnwrap(f.host.shown.last as? UIAlertController); XCTAssertEqual(alert.preferredStyle, .alert); XCTAssertEqual(alert.actions.map(\.style), [.cancel, .default]); XCTAssertFalse(try XCTUnwrap(alert.message).isEmpty); XCTAssertEqual(retries, 0)
    }
    func testPoolAddLiquidityBuildsTheSupplyEditorWithTheRequestedPool() throws {
        let f = try make()
        f.poolRoute.showLiquidity(on: f.host, poolInfo: f.pool, farms: [], type: .add, assetManager: f.assets, poolsService: f.pools, fiatService: f.fiat, farmingService: f.farms, completionHandler: nil)
        let view = try screen(PolkaswapViewController.self, host: f.host)
        let model = try XCTUnwrap(view.viewModel as? SupplyLiquidityViewModel)
        XCTAssertTrue(model.view === view)
    }
    func testPoolLiquidityRouteRequiresBothPoolAndFiatServices() throws {
        let f = try make()
        for missingPool in [false, true] {
            f.poolRoute.showLiquidity(on: f.host, poolInfo: f.pool, farms: [], type: .add, assetManager: f.assets, poolsService: missingPool ? nil : f.pools, fiatService: missingPool ? f.fiat : nil, farmingService: f.farms, completionHandler: nil)
        }
        XCTAssertTrue(f.host.shown.isEmpty)
    }
    func testScanFactoryBuildsTheScannerForEachEntryPointWithoutStartingCapture() throws {
        let f = try make()
        for generated in [false, true] {
            let view = try XCTUnwrap(ScanQRViewFactory.createView(assetManager: f.assets, currentUser: f.account, networkFacade: f.network, qrEncoder: f.encoder, sharingFactory: RouteShare(), assetsProvider: generated ? f.balances : nil, isGeneratedQRCodeScreenShown: generated, providerFactory: f.provider, feeProvider: f.fees, marketCapService: f.market, completion: nil) as? ScanQRViewController)
            let model = try XCTUnwrap(view.viewModel as? ScanQRViewModel)
            XCTAssertTrue(model.view === view)
            XCTAssertTrue(f.encoder.infos.isEmpty)
        }
    }
    private func descendants<T: UIView>(_ type: T.Type, _ root: UIView) -> [T] { ((root as? T).map { [$0] } ?? []) + root.subviews.flatMap { descendants(type, $0) } }
}
@MainActor
private final class RouteFixture {
    enum Missing { case pool, pools, balances, fiat, network }
    let account: AccountItem
    let host = RouteHost(), assets = RouteAssets(), balances = RouteBalances(), pools = RoutePools(), farms = RouteFarms(), fees = RouteFees(), engine = RouteEngine(), fiat = RouteFiat(), market = RouteMarket(), network = WalletNetworkOperationFactoryProtocolMock(), encoder = RouteEncoder()
    let provider: BalanceProviderFactory
    var pool: PoolInfo { .init(baseAssetId: WalletAssetId.xor.rawValue, targetAssetId: WalletAssetId.val.rawValue, poolId: "public-pool", accountId: account.address, baseAssetPooledByAccount: 10, targetAssetPooledByAccount: 20, accountPoolBalance: 5) }
    var farm: Farm { .init(id: "public-farm", name: "XOR-VAL", baseAsset: assets.assets[0], poolAsset: assets.assets[1], rewardAsset: assets.assets[0], tvl: 100, apr: 12, depositFee: 0) }
    var walletRoute: RedesignWalletWireframe { .init(feeProvider: fees) }
    var assetFactory: AssetViewModelFactory { .init(walletAssets: assets.assets, assetManager: assets, fiatService: fiat) }
    var poolFactory: PoolViewModelFactory { .init(walletAssets: assets.assets, assetManager: assets, fiatService: fiat) }
    func showAssetList() {
        walletRoute.showFullListAssets(on: host, assetManager: assets, fiatService: fiat, assetViewModelFactory: assetFactory, providerFactory: provider, poolsService: pools, networkFacade: network, accountId: account.publicKeyData.toHex(), address: account.address, polkaswapNetworkFacade: PolkaswapNetworkOperationFactory(engine: engine), qrEncoder: encoder, sharingFactory: RouteShare(), referralFactory: RouteReferrals(), assetsProvider: balances, marketCapService: market, farmingService: farms, updateHandler: nil)
    }
    func showPoolList() {
        walletRoute.showFullListPools(on: host, poolsService: pools, networkFacade: network, polkaswapNetworkFacade: PolkaswapNetworkOperationFactory(engine: engine), assetManager: assets, fiatService: fiat, poolViewModelFactory: poolFactory, providerFactory: provider, operationFactory: network, assetsProvider: balances, marketCapService: market, farmingService: farms, updateHandler: nil)
    }
    func showQR(close: (() -> Void)? = nil) {
        walletRoute.showGenerateQR(on: host, accountId: account.publicKeyData.toHex(), address: account.address, username: account.username, qrEncoder: encoder, sharingFactory: RouteShare(), assetManager: assets, assetsProvider: balances, networkFacade: network, providerFactory: provider, isScanQRShown: false, marketCapService: market, closeHandler: close)
    }
    var details: DetailViewModelFactory { .init(assetManager: assets) }
    var farmRoute: FarmDetailsWireframe { .init(feeProvider: fees, walletService: WalletService(operationFactory: network), assetManager: assets) }
    var poolRoute: PoolDetailsWireframe { .init(feeProvider: fees, providerFactory: provider, operationFactory: network, assetsProvider: balances, marketCapService: market) }
    init() throws {
        let key = Data(repeating: 0x42, count: 32)
        account = AccountItem(address: try SS58AddressFactory().addressFromAccountId(data: key, type: SoraPassport.Chain.sora.addressType()), cryptoType: .sr25519, networkType: SoraPassport.Chain.sora.addressType(), username: "Fixture", publicKeyData: key, settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0, isSelected: true)
        provider = BalanceProviderFactory(accountId: key.toHex(), cacheFacade: CoreDataCacheFacade.shared, networkOperationFactory: network, identifierFactory: SingleProviderIdentifierFactory())
    }
    func assetRoute(network available: Bool = true) -> AssetDetailsWireframe {
        let route = AssetDetailsWireframe(accountId: account.publicKeyData.toHex(), address: account.address, assetManager: assets, fiatService: fiat, eventCenter: RouteEvents(), assetInfo: assets.assets[1], providerFactory: provider, networkFacade: available ? network : nil, polkaswapNetworkFacade: PolkaswapNetworkOperationFactory(engine: engine), assetsProvider: balances, marketCapService: market, qrEncoder: encoder, sharingFactory: RouteShare(), farmingService: farms, feeProvider: fees)
        route.controller = host; return route
    }
    func showFarmPool(missing: Missing? = nil) {
        farmRoute.showPoolDetails(on: host, poolInfo: missing == .pool ? nil : pool, fiatService: missing == .fiat ? nil : fiat, poolsService: missing == .pools ? nil : pools, providerFactory: provider, operationFactory: missing == .network ? nil : network, assetsProvider: missing == .balances ? nil : balances, marketCapService: market, farmingService: farms)
    }
}
private final class RouteHost: UIViewController {
    var shown = [UIViewController]()
    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) { shown.append(viewControllerToPresent); completion?() }
}
private final class RouteEncoder: WalletQREncoderProtocol {
    private let lock = NSLock(); private var values = [ReceiveInfo]()
    var infos: [ReceiveInfo] { lock.lock(); defer { lock.unlock() }; return values }
    func encode(receiverInfo: ReceiveInfo) throws -> Data { lock.lock(); values.append(receiverInfo); lock.unlock(); return Data("public-qr-fixture".utf8) }
}
private final class RouteShare: AccountShareFactoryProtocol { func createSources(for receiveInfo: ReceiveInfo, qrImage: UIImage) -> [Any] { [] } }
private final class RouteEvents: EventCenterProtocol {
    func notify(with event: EventProtocol) {}
    func notify(with event: EventProtocol, completionOnMain: @escaping () -> Void) { DispatchQueue.main.async(execute: completionOnMain) }
    func add(observer: EventVisitorProtocol, dispatchIn: DispatchQueue?) {}
    func remove(observer: EventVisitorProtocol) {}
}
private final class RouteFees: FeeProviderProtocol {
    func getFee(for type: TransactionType, completion: @escaping (Decimal) -> Void) { completion(1) }
    func getFee(for type: InputRewardAmountType, completion: @escaping (Decimal) -> Void) { completion(1) }
    func getFee(for call: any RuntimeCallable) async -> Decimal { 1 }
    func getFee(for type: TransactionType) async -> Decimal { 1 }
}
private final class RouteAssets: AssetManagerProtocol {
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

private actor RouteFiat: FiatServiceProtocol { func getFiat() async -> [PIExactFiatData] { [] } }

private final class RouteMarket: MarketCapServiceProtocol { func getMarketCap(for assets: [String]) async -> Set<MarketCapInfo> { [] } }

private final class RouteBalances: AssetProviderProtocol {
    var balances: [BalanceData] = []; var unavailable: Set<String> = []; var additions = 0
    func getBalances(with assetIds: [String]) -> [BalanceData] { balances.filter { assetIds.contains($0.identifier) } }
    func unavailableBalanceAssetIds(among assetIds: [String]) -> Set<String> { unavailable.intersection(assetIds) }
    func add(observer: AssetProviderObserverProtocol) { additions += 1 }
    func remove(observer: AssetProviderObserverProtocol) {}
}

private final class RoutePools: PoolsServiceInputProtocol {
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
    var delegates = 0
    func appendDelegate(delegate _: PoolsServiceOutput) { delegates += 1 }
}

private final class RouteFarms: DemeterFarmingServiceProtocol {
    func getUserFarmInfos(baseAssetId _: String?, targetAssetId _: String?) async -> [UserFarm] { [] }
    func loadUserFarmInfos(baseAssetId _: String?, targetAssetId _: String?, accountId _: Data) async throws -> [UserFarm] { [] }
    func getAllFarms() async throws -> [Farm] { [] }
    func getFarm(with _: String) -> Farm? { nil }
    func getFarmDetails(baseAssetId _: String, poolAssetId _: String, rewardAssetId _: String) async throws -> [Farm] { [] }
    func getSingleSidedXorFarmedPools(completion: @escaping ([UserFarmInfo]) -> Void) { completion([]) }
}

private final class RouteEngine: JSONRPCEngine {
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

private final class RouteReferrals: ReferralsOperationFactoryProtocol {
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
