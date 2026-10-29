// SPDX-License-Identifier: Apache-2.0
import BigInt
import Combine
import Foundation
import IrohaCrypto
import RobinHood
import SoraFoundation
import SoraKeystore
import SoraUIKit
import SSFUtils
import SSFCloudStorage
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
    var assets = [AssetInfo(id: WalletAssetId.xor.rawValue, symbol: "XOR", chainId: "", precision: 18, icon: nil, displayName: "SORA", visible: true),
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

@MainActor
final class ExplorePageCoverageTests: XCTestCase {
    private var previousAccount: AccountItem?
    override func setUp() { super.setUp(); previousAccount = SelectedWalletSettings.shared.currentAccount }
    override func tearDown() { SelectedWalletSettings.shared.commitInternalValue(previousAccount); super.tearDown() }
    private func make() throws -> ExplorePageFixture {
        let fixture = try ExplorePageFixture()
        SelectedWalletSettings.shared.commitInternalValue(fixture.route.account)
        return fixture
    }
    private func waitUntil(_ predicate: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<100 { if predicate() { return }; try? await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertTrue(predicate(), file: file, line: line)
    }
    private func assets(_ snapshot: ExplorePageSnapshot) -> [ExploreAssetViewModel] {
        snapshot.itemIdentifiers.compactMap { if case .asset(let item) = $0 { return item.assetViewModel }; return nil }
    }
    private func pools(_ snapshot: ExplorePageSnapshot) -> [ExplorePoolViewModel] {
        snapshot.itemIdentifiers.compactMap { if case .pool(let item) = $0 { return item.poolViewModel }; return nil }
    }
    private func farms(_ snapshot: ExplorePageSnapshot) -> [ExploreFarmViewModel] {
        snapshot.itemIdentifiers.compactMap { if case .farm(let item) = $0 { return item.farmViewModel }; return nil }
    }
    func testAssetPageStartsWithTwentyNumberedPlaceholdersAndAHeader() throws {
        let f = try make(); let model = f.assetPage(); model.setup()
        XCTAssertFalse(model.isNeedHeaders); XCTAssertEqual(model.snapshot.numberOfSections, 2)
        XCTAssertEqual(assets(model.snapshot).map(\.serialNumber), (1...20).map(String.init))
        XCTAssertTrue(assets(model.snapshot).allSatisfy { $0.assetId == nil })
        guard case let .header(header) = model.snapshot.itemIdentifiers[0] else { return XCTFail("Missing asset header") }
        XCTAssertFalse(header.titleText.isEmpty); XCTAssertFalse(header.subTitleText.isEmpty)
    }
    func testAssetPageReplacesPlaceholdersWithTheActualCatalog() async throws {
        let f = try make(); let model = f.assetPage(); var sizes: [Int] = []
        let token = model.snapshotPublisher.sink { sizes.append($0.numberOfItems) }; model.setup()
        await waitUntil { self.assets(model.snapshot).first?.assetId != nil }
        XCTAssertEqual(Set(assets(model.snapshot).compactMap(\.assetId)), Set(f.route.assets.assets.map(\.assetId)))
        XCTAssertEqual(assets(model.snapshot).map(\.serialNumber), ["1", "2", "3", "4"])
        XCTAssertTrue(sizes.contains(21)); XCTAssertEqual(sizes.last, 5); withExtendedLifetime(token) {}
    }
    func testAssetPageWithoutCatalogKeepsLoadingRowsInsteadOfInventingTokens() async throws {
        let f = try make(); let service = ExploreAssetViewModelService(marketCapService: f.route.market, fiatService: f.route.fiat, itemFactory: f.factory, assetInfos: [], priceInfoService: f.prices)
        let model = ExploreAssetsPageViewModel(wireframe: f.wireframe, assetViewModelsService: service); model.setup()
        await waitUntil { service.viewModels.isEmpty }
        XCTAssertEqual(assets(model.snapshot).count, 20); XCTAssertTrue(assets(model.snapshot).allSatisfy { $0.assetId == nil })
    }
    func testAssetPagePriceNotificationReloadsOnceAfterRepeatedSetup() async throws {
        let f = try make(); let model = f.assetPage(); model.setup(); await waitUntil { f.prices.calls == 1 }; model.setup(); await waitUntil { f.prices.calls == 2 }
        NotificationCenter.default.post(name: PICatalogs.pricesDidChange, object: nil)
        await waitUntil { f.prices.calls == 3 }; try? await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertEqual(f.prices.calls, 3)
    }
    func testReleasedAssetPageUnsubscribesFromPriceRefreshes() async throws {
        let f = try make(); var model: ExploreAssetsPageViewModel? = f.assetPage(); weak var reference = model
        model?.setup(); await waitUntil { model?.snapshot.numberOfItems == 5 }; model = nil
        XCTAssertNil(reference); let before = f.prices.calls
        NotificationCenter.default.post(name: PICatalogs.pricesDidChange, object: nil); try? await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(f.prices.calls, before)
    }
    func testAssetSelectionUsesTheItemIdentifierAndPresentingController() throws {
        let f = try make(); let model = f.assetPage(); let host = ExplorePageHost(); model.view = host
        model.didSelect(with: .asset(ExploreAssetItem(serialNumber: "7", assetViewModel: ExploreAssetViewModel(assetId: "selected-token"))))
        XCTAssertEqual(f.wireframe.assets, ["selected-token"]); XCTAssertTrue(f.wireframe.controllers.last! === host.controller)
    }
    func testAssetSelectionIgnoresHeadersNilAndUnresolvedRows() throws {
        let f = try make(); let model = f.assetPage()
        model.didSelect(with: nil); model.didSelect(with: .header(HeaderItem(titleText: "Assets", subTitleText: "")))
        model.didSelect(with: .asset(ExploreAssetItem(serialNumber: "1", assetViewModel: ExploreAssetViewModel())))
        model.searchTextChanged(with: "ignored"); XCTAssertTrue(f.wireframe.assets.isEmpty)
    }
    func testPoolPagePublishesLoadedPoolIdentityAndApy() async throws {
        let f = try make(); let model = f.poolPage(); model.setup()
        XCTAssertEqual(pools(model.snapshot).count, 20); XCTAssertFalse(model.isNeedHeaders)
        await waitUntil { self.pools(model.snapshot).first?.apy != nil }
        let row = try XCTUnwrap(pools(model.snapshot).first); XCTAssertEqual(row.poolId, "catalog-pool"); XCTAssertEqual(row.baseAssetId, WalletAssetId.xor.rawValue); XCTAssertEqual(row.targetAssetId, WalletAssetId.val.rawValue)
        XCTAssertEqual(model.snapshot.numberOfSections, 2); XCTAssertEqual(pools(model.snapshot).count, 1)
    }
    func testPoolPageRefreshPreservesItsHeaderAndReplacesRows() async throws {
        let f = try make(); let model = f.poolPage(); model.setup(); await waitUntil { self.pools(model.snapshot).first?.apy != nil }
        f.poolModels.viewModels = [ExplorePoolViewModel(poolId: "replacement", serialNumber: "1")]
        await waitUntil { self.pools(model.snapshot).first?.poolId == "replacement" }
        XCTAssertEqual(model.snapshot.numberOfItems, 2)
        f.poolModels.viewModels = []; await waitUntil { self.pools(model.snapshot).count == 20 }
    }
    func testPoolSelectionUsesAccountPositionWhenAvailable() throws {
        let f = try make(); f.route.pools.pool = f.route.pool; let model = f.poolPage()
        model.didSelect(with: f.poolItem)
        XCTAssertEqual(f.wireframe.pools.first?.identifier, f.route.pool.identifier)
        XCTAssertEqual(f.wireframe.pools.first?.accountPoolBalance, f.route.pool.accountPoolBalance)
    }
    func testPoolSelectionBuildsAnUnfundedPositionForTheSelectedAccount() throws {
        let f = try make(); let model = f.poolPage(); model.didSelect(with: f.poolItem)
        let pool = try XCTUnwrap(f.wireframe.pools.first)
        XCTAssertEqual(pool.poolId, "catalog-pool"); XCTAssertEqual(pool.baseAssetId, WalletAssetId.xor.rawValue)
        XCTAssertEqual(pool.accountId, f.route.account.publicKeyData.toHex(includePrefix: true))
    }
    func testPoolSelectionWithoutAccountDoesNotBorrowAnotherIdentity() throws {
        let f = try make(); SelectedWalletSettings.shared.commitInternalValue(nil); f.poolPage().didSelect(with: f.poolItem)
        XCTAssertEqual(f.wireframe.pools.first?.accountId, "")
    }
    func testPoolPageIgnoresUnrelatedSelectionAndSearch() throws {
        let f = try make(); let model = f.poolPage(); model.didSelect(with: nil); model.didSelect(with: .header(HeaderItem(titleText: "Pools", subTitleText: ""))); model.searchTextChanged(with: "ignored")
        XCTAssertTrue(f.wireframe.pools.isEmpty)
    }
    func testFarmPageReplacesPlaceholdersWithCatalogSortedByTvl() async throws {
        let f = try make(); let model = f.farmPage(); model.setup()
        XCTAssertFalse(model.isNeedHeaders); XCTAssertEqual(farms(model.snapshot).count, 20)
        await waitUntil { self.farms(model.snapshot).first?.farmId != nil }
        XCTAssertEqual(farms(model.snapshot).map(\.farmId), ["public-farm"]); XCTAssertEqual(farms(model.snapshot).first?.serialNumber, "1")
        XCTAssertEqual(model.snapshot.numberOfSections, 2)
    }
    func testFarmCatalogRefreshReplacesRowsAndRestoresLoadingIfEmpty() async throws {
        let f = try make(); let model = f.farmPage(); model.setup(); await waitUntil { self.farms(model.snapshot).first?.farmId != nil }
        f.farmModels.viewModels = [ExploreFarmViewModel(farmId: "new", serialNumber: "1")]
        await waitUntil { self.farms(model.snapshot).first?.farmId == "new" }
        f.farmModels.viewModels = []; await waitUntil { self.farms(model.snapshot).count == 20 }
    }
    func testFarmSelectionResolvesTheCurrentFarmAndController() throws {
        let f = try make(); let model = f.farmPage(); let host = ExplorePageHost(); model.view = host; model.didSelect(with: f.farmItem)
        XCTAssertEqual(f.wireframe.farms.first?.id, f.route.farm.id); XCTAssertTrue(f.wireframe.controllers.last! === host.controller)
    }
    func testFarmSelectionIgnoresMissingDeletedAndOtherItems() throws {
        let f = try make(); let model = f.farmPage(); model.didSelect(with: nil); model.didSelect(with: f.poolItem)
        model.didSelect(with: .farm(ExploreFarmItem(serialNumber: "1", farmViewModel: ExploreFarmViewModel(serialNumber: "1"))))
        model.didSelect(with: .farm(ExploreFarmItem(serialNumber: "1", farmViewModel: ExploreFarmViewModel(farmId: "deleted", serialNumber: "1"))))
        model.searchTextChanged(with: "ignored"); XCTAssertTrue(f.wireframe.farms.isEmpty)
    }
    func testSearchSelectionResolvesExistingAccountPoolAndFarm() throws {
        let f = try make(); f.route.pools.pool = f.route.pool; let model = f.searchPage(); model.accountPoolsService = f.route.pools
        model.didSelect(with: f.poolItem); model.didSelect(with: f.farmItem)
        XCTAssertEqual(f.wireframe.pools.first?.identifier, f.route.pool.identifier); XCTAssertEqual(f.wireframe.farms.first?.id, f.route.farm.id)
    }
    func testPageSectionsHaveStableIdentityIndependentOfContents() {
        let a = ExplorePageSection(items: []), b = ExplorePageSection(items: [])
        XCTAssertNotEqual(a, b); XCTAssertEqual(Set([a, a, b]).count, 2)
        b.id = a.id; XCTAssertEqual(a, b); XCTAssertEqual(Set([a, b]).count, 1)
    }
}

@MainActor
private final class ExplorePageFixture {
    let route: RouteFixture
    let wireframe = ExplorePageRoute()
    let prices = ExplorePagePrices()
    let factory: ExploreItemFactory
    let assetModels: ExploreAssetViewModelService
    let poolModels: ExplorePoolsViewModelService
    let farmModels: ExploreFarmsViewModelService
    init() throws {
        route = try RouteFixture(); factory = ExploreItemFactory(assetManager: route.assets)
        assetModels = ExploreAssetViewModelService(marketCapService: route.market, fiatService: route.fiat, itemFactory: factory, assetInfos: route.assets.assets, priceInfoService: prices)
        poolModels = ExplorePoolsViewModelService(itemFactory: factory, poolsService: ExplorePagePools(), apyService: ExplorePageApy(), fiatService: route.fiat)
        farmModels = ExploreFarmsViewModelService(demeterFarmingService: ExplorePageFarms(farm: route.farm))
    }
    var poolItem: ExplorePageSectionItem { .pool(ExplorePoolItem(serialNumber: "1", poolViewModel: ExplorePoolViewModel(poolId: "catalog-pool", serialNumber: "1", baseAssetId: WalletAssetId.xor.rawValue, targetAssetId: WalletAssetId.val.rawValue))) }
    var farmItem: ExplorePageSectionItem { .farm(ExploreFarmItem(serialNumber: "1", farmViewModel: ExploreFarmViewModel(farmId: route.farm.id, serialNumber: "1"))) }
    func assetPage() -> ExploreAssetsPageViewModel { ExploreAssetsPageViewModel(wireframe: wireframe, assetViewModelsService: assetModels) }
    func poolPage() -> ExplorePoolsPageViewModel { ExplorePoolsPageViewModel(wireframe: wireframe, poolViewModelsService: poolModels, accountPoolsService: route.pools) }
    func farmPage() -> ExploreFarmsPageViewModel { ExploreFarmsPageViewModel(wireframe: wireframe, farmsViewModelsService: farmModels, accountPoolsService: route.pools) }
    func searchPage() -> ExploreSearchPageViewModel { ExploreSearchPageViewModel(wireframe: wireframe, assetViewModelsService: assetModels, poolViewModelsService: poolModels, farmsViewModelsService: farmModels) }
}
private final class ExplorePageHost: UIViewController, ControllerBackedProtocol {}
private final class ExplorePageRoute: ExploreWireframeProtocol {
    var assets: [String] = [], pools: [PoolInfo] = [], farms: [Farm] = [], controllers: [UIViewController?] = []
    func showAssetDetails(on controller: UIViewController?, assetId: String) { assets.append(assetId); controllers.append(controller) }
    func showAccountPoolDetails(on controller: UIViewController?, poolInfo: PoolInfo) { pools.append(poolInfo); controllers.append(controller) }
    func showFarmDetails(on controller: UIViewController?, farm: Farm) { farms.append(farm); controllers.append(controller) }
    func showLiquidity(on controller: UIViewController?) { XCTFail("Page selection must not start liquidity submission") }
}
private final class ExplorePagePrices: PriceInfoServiceProtocol {
    private let lock = NSLock(); private var count = 0
    var calls: Int { lock.lock(); defer { lock.unlock() }; return count }
    private func record() { lock.lock(); count += 1; lock.unlock() }
    func getPriceInfo(for assetIds: [String]) async -> PriceInfo { record(); return PriceInfo(fiatData: [], marketCapInfo: []) }
}
private final class ExplorePagePools: ExplorePoolsServiceInputProtocol {
    func getPools(with fiatData: [PIExactFiatData]) async throws -> [ExplorePool] { [ExplorePool(id: "catalog-pool", baseAssetId: WalletAssetId.xor.rawValue, targetAssetId: WalletAssetId.val.rawValue, tvl: 100, apy: nil)] }
}
private actor ExplorePageApy: APYServiceProtocol {
    func getApy(for baseAssetId: String, targetAssetId: String) async -> Decimal? { Decimal(string: "0.05") }
    func setup(factory: PolkaswapNetworkOperationFactoryProtocol) {}
}
private final class ExplorePageFarms: DemeterFarmingServiceProtocol {
    let farm: Farm
    init(farm: Farm) { self.farm = farm }
    func getUserFarmInfos(baseAssetId: String?, targetAssetId: String?) async -> [UserFarm] { [] }
    func loadUserFarmInfos(baseAssetId: String?, targetAssetId: String?, accountId: Data) async throws -> [UserFarm] { [] }
    func getAllFarms() async throws -> [Farm] { [farm] }
    func getFarm(with id: String) -> Farm? { id == farm.id ? farm : nil }
    func getFarmDetails(baseAssetId: String, poolAssetId: String, rewardAssetId: String) async throws -> [Farm] { [farm] }
    func getSingleSidedXorFarmedPools(completion: @escaping ([UserFarmInfo]) -> Void) { completion([]) }
}

@MainActor
final class EditFlowCoverageTests: XCTestCase {
    private var previousAccount: AccountItem?
    private var previousCards: Any?
    override func setUp() {
        super.setUp(); previousAccount = SelectedWalletSettings.shared.currentAccount
        previousCards = UserDefaults.standard.object(forKey: "enabledCardIdentifiers")
    }
    override func tearDown() {
        UserDefaults.standard.set(previousCards, forKey: "enabledCardIdentifiers")
        SelectedWalletSettings.shared.commitInternalValue(previousAccount); super.tearDown()
    }
    private func make() throws -> (RouteFixture, EditViewService, EditViewModel) {
        let f = try RouteFixture(); SelectedWalletSettings.shared.commitInternalValue(f.account)
        ApplicationConfig.shared.updateAvailableApplicationSections(cards: [Cards.referralProgram.id, Cards.pooledAssets.id])
        let service = EditViewService(poolsService: f.pools)
        service.viewModels = Cards.allCases.map { EnabledViewModel(id: $0.id, title: $0.title, state: .selected) }
        return (f, service, EditViewModel(editViewService: service, completion: nil))
    }
    private func item(_ model: EditViewModel) throws -> EnabledItem {
        guard case let .enabled(item)? = model.snapshot.itemIdentifiers.first else { throw NSError(domain: "Missing edit item", code: 1) }; return item
    }
    func testEditReloadCreatesOneRowWithTheAvailableCardModels() throws {
        let (_, service, model) = try make(); model.reloadView()
        XCTAssertEqual(model.snapshot.numberOfSections, 1); XCTAssertEqual(model.snapshot.numberOfItems, 1)
        XCTAssertEqual(try item(model).enabledViewModels.map(\.id), service.viewModels.map(\.id))
    }
    func testDisablingOneCardPersistsOnlyTheRemainingCards() throws {
        let (_, service, model) = try make(); model.reloadView(); try item(model).onTap?(Cards.referralProgram.id)
        XCTAssertEqual(service.viewModels[0].state, .disabled)
        XCTAssertEqual(ApplicationConfig.shared.getAvailableApplicationSections(), [Cards.pooledAssets.id])
        XCTAssertEqual(try item(model).enabledViewModels[1].state, .selected)
    }
    func testReenablingACardRestoresItOnceAndReusesTheDisplayedRow() throws {
        let (_, _, model) = try make(); model.reloadView(); let row = try item(model)
        row.onTap?(Cards.referralProgram.id); row.onTap?(Cards.referralProgram.id)
        XCTAssertEqual(ApplicationConfig.shared.getAvailableApplicationSections().filter { $0 == Cards.referralProgram.id }.count, 1)
        XCTAssertTrue(try item(model) === row); XCTAssertEqual(row.enabledViewModels[0].state, .selected)
    }
    func testDisablingDuplicatePreferenceRemovesEveryCopyOfTheCard() throws {
        let (_, _, model) = try make(); ApplicationConfig.shared.updateAvailableApplicationSections(cards: [1, 1, 3]); model.reloadView(); try item(model).onTap?(1)
        XCTAssertEqual(ApplicationConfig.shared.getAvailableApplicationSections(), [3])
    }
    func testUnknownCardTapDoesNotChangePreferencesOrPublishAnotherSnapshot() throws {
        let (_, _, model) = try make(); model.reloadView(); var publishes = 0
        let token = model.snapshotPublisher.dropFirst().sink { _ in publishes += 1 }; try item(model).onTap?(999)
        XCTAssertEqual(publishes, 0); XCTAssertEqual(ApplicationConfig.shared.getAvailableApplicationSections(), [1, 3]); withExtendedLifetime(token) {}
    }
    func testExplicitSectionIsPreservedWithoutRebuildingTheServiceRows() throws {
        let (_, _, model) = try make(); let row = EnabledItem(); let section = EnabledSection(items: [.enabled(row)])
        model.reloadView(with: section); XCTAssertTrue(model.snapshot.sectionIdentifiers[0] === section); XCTAssertTrue(try item(model) === row)
    }
    func testEmptyCardCatalogStillProvidesAnEditableEmptyRow() throws {
        let (_, service, model) = try make(); service.viewModels = []; model.reloadView()
        XCTAssertTrue(try item(model).enabledViewModels.isEmpty); XCTAssertEqual(model.snapshot.numberOfItems, 1)
    }
    func testCardTogglePreservesOtherAccountsPreferences() throws {
        let (f, _, model) = try make(); UserDefaults.standard.set([f.account.address: [1, 3], "another-account": [3]], forKey: "enabledCardIdentifiers")
        model.reloadView(); try item(model).onTap?(1)
        let configs = UserDefaults.standard.dictionary(forKey: "enabledCardIdentifiers")
        XCTAssertEqual(configs?["another-account"] as? [Int], [3]); XCTAssertEqual(configs?[f.account.address] as? [Int], [3])
    }
    func testCardCallbackDoesNotRetainReleasedRowOrModel() throws {
        let (_, service, _) = try make(); var model: EditViewModel? = EditViewModel(editViewService: service, completion: nil)
        model?.reloadView(); weak var weakModel = model; weak var weakRow = try item(model!); let callback = weakRow?.onTap
        model = nil; XCTAssertNil(weakModel); XCTAssertNil(weakRow); callback?(1)
        XCTAssertEqual(ApplicationConfig.shared.getAvailableApplicationSections(), [1, 3])
    }
    func testPoolAvailabilityCompletesOnceAndReleasesItsCallback() throws {
        let (f, service, _) = try make(); var results: [Bool] = []; service.loadModels { results.append($0) }
        service.loaded(pools: [f.pool]); service.loaded(pools: []); XCTAssertEqual(results, [true]); XCTAssertNil(service.completion)
    }
    func testEmptyPoolAvailabilityIsReportedAsFalse() throws {
        let (_, service, _) = try make(); var results: [Bool] = []; service.loadModels { results.append($0) }; service.loaded(pools: [])
        XCTAssertEqual(results, [false]); XCTAssertNil(service.completion)
    }
    func testNewPoolAvailabilityRequestReplacesThePreviousCallback() throws {
        let (_, service, _) = try make(); var first = 0, second = 0
        service.loadModels { _ in first += 1 }; service.loadModels { _ in second += 1 }; service.loaded(pools: [])
        XCTAssertEqual(first, 0); XCTAssertEqual(second, 1)
    }
    func testEditFactoryBindsControllerModelServiceAndCompletion() throws {
        let (f, service, _) = try make(); var completions = 0
        let view = EditViewFactory.createView(poolsService: f.pools, editViewService: service) { completions += 1 }
        let model = try XCTUnwrap(view.viewModel as? EditViewModel)
        XCTAssertTrue(model.view === view); XCTAssertTrue(model.editViewService === service)
        model.completion?(); XCTAssertEqual(completions, 1); view.loadViewIfNeeded(); XCTAssertEqual(model.snapshot.numberOfItems, 1)
    }
    func testSectionsUseIdentitySoEqualCardContentsRemainSeparate() {
        let row = EnabledItem(); let a = EnabledSection(items: [.enabled(row)]), b = EnabledSection(items: [.enabled(row)])
        XCTAssertNotEqual(a, b); XCTAssertEqual(Set([a, a, b]).count, 2); b.id = a.id; XCTAssertEqual(a, b)
        XCTAssertTrue(row.cellType == EnabledCell.self); XCTAssertFalse(row.clipsToBounds); _ = row.backgroundColor
    }
}

@MainActor
final class PresentationRouteCoverageTests: XCTestCase {
    private var previousAccount: AccountItem?
    override func setUp() { super.setUp(); previousAccount = SelectedWalletSettings.shared.currentAccount }
    override func tearDown() { SelectedWalletSettings.shared.commitInternalValue(previousAccount); super.tearDown() }
    private func make() throws -> RouteFixture { let f = try RouteFixture(); SelectedWalletSettings.shared.commitInternalValue(f.account); return f }
    private func presented<T: UIViewController>(_ type: T.Type, _ f: RouteFixture) throws -> T {
        let container = try XCTUnwrap(f.host.shown.last as? BlurViewController)
        XCTAssertEqual(container.modalPresentationStyle, .overFullScreen)
        let navigation = try XCTUnwrap(container.children.first as? UINavigationController)
        return try XCTUnwrap(navigation.viewControllers.first as? T)
    }
    private func transaction() -> Transaction {
        SetReferrerTransaction(base: TransactionBase(txHash: "route-hash", blockHash: "route-block", fee: Amount(value: 1), status: .success, timestamp: "1700000000"), who: "referrer-address", isMyReferrer: true, tokenId: WalletAssetId.xor.rawValue)
    }
    func testAmountAssetPickerContainsExactlyTheAllowedIdentifiers() throws {
        let f = try make(); var selected: String?
        InputAssetAmountWireframe().showChoiceBaseAsset(on: f.host, assetManager: f.assets, fiatService: f.fiat, assetViewModelFactory: f.assetFactory, assetsProvider: f.balances, assetIds: [WalletAssetId.val.rawValue], marketCapService: f.market) { selected = $0 }
        let view = try presented(ProductListViewController.self, f); let model = try XCTUnwrap(view.viewModel as? SelectAssetViewModel)
        XCTAssertEqual(model.assetIds, [WalletAssetId.val.rawValue]); XCTAssertNil(selected)
        model.selectionCompletion?(WalletAssetId.val.rawValue); XCTAssertEqual(selected, WalletAssetId.val.rawValue)
    }
    func testAmountConfirmationPushesTheExactReviewedAmountRecipientAndFee() throws {
        let f = try make(); let nav = UINavigationController(rootViewController: f.host); let amount = try XCTUnwrap(Decimal(string: "1.000000000000000001"))
        InputAssetAmountWireframe().showConfirmSendingAsset(on: nav, assetId: WalletAssetId.val.rawValue, walletService: WalletService(operationFactory: f.network), assetManager: f.assets, fiatService: f.fiat, recipientAddress: "recipient-address", firstAssetAmount: amount, fee: Decimal(string: "0.002")!, assetsProvider: f.balances)
        let view = try XCTUnwrap(nav.topViewController as? ConfirmViewController); let model = try XCTUnwrap(view.viewModel as? ConfirmSendingViewModel)
        XCTAssertEqual(model.assetId, WalletAssetId.val.rawValue); XCTAssertEqual(model.firstAssetAmount, amount); XCTAssertEqual(model.recipientAddress, "recipient-address"); XCTAssertEqual(model.fee, Decimal(string: "0.002")); XCTAssertTrue(model.view === view)
        XCTAssertEqual(nav.viewControllers.count, 2); XCTAssertTrue(f.host.shown.isEmpty)
    }
    func testQRScannerRouteBuildsTheScannerWithoutStartingCapture() throws {
        let f = try make(); var received = false
        GenerateQRWireframe(controller: f.host).showScanQR(on: f.host, networkFacade: f.network, assetManager: f.assets, qrEncoder: f.encoder, sharingFactory: RouteShare(), assetsProvider: f.balances, providerFactory: f.provider, feeProvider: f.fees, marketCapService: f.market) { _ in received = true }
        let container = try XCTUnwrap(f.host.shown.last as? BlurViewController)
        let view = try XCTUnwrap(container.children.first as? ScanQRViewController); let model = try XCTUnwrap(view.viewModel as? ScanQRViewModel)
        XCTAssertTrue(model.view === view); XCTAssertFalse(received); XCTAssertTrue(f.encoder.infos.isEmpty)
    }
    func testQRScannerRouteRequiresASelectedWallet() throws {
        let f = try make(); SelectedWalletSettings.shared.commitInternalValue(nil)
        GenerateQRWireframe(controller: f.host).showScanQR(on: f.host, networkFacade: f.network, assetManager: f.assets, qrEncoder: f.encoder, sharingFactory: RouteShare(), assetsProvider: f.balances, providerFactory: f.provider, feeProvider: f.fees, marketCapService: f.market) { _ in XCTFail("No scan was started") }
        XCTAssertTrue(f.host.shown.isEmpty)
    }
    func testQRSendRouteDoesNotOpenWithoutASelectedWallet() throws {
        let f = try make(); SelectedWalletSettings.shared.commitInternalValue(nil)
        GenerateQRWireframe(controller: f.host).showSend(on: f.host, selectedTokenId: WalletAssetId.val.rawValue, selectedAddress: "recipient", fiatService: f.fiat, assetManager: f.assets, providerFactory: f.provider, networkFacade: f.network, assetsProvider: f.balances, qrEncoder: f.encoder, sharingFactory: RouteShare(), marketCapService: f.market)
        XCTAssertTrue(f.host.shown.isEmpty)
    }
    func testLiquidityAssetPickerKeepsAllowedTokensAndSelectionCallback() throws {
        let f = try make(); var selected: String?
        LiquidityWireframe().showChoiсeBaseAsset(on: f.host, assetManager: f.assets, fiatService: f.fiat, assetViewModelFactory: f.assetFactory, assetsProvider: f.balances, assetIds: [WalletAssetId.xor.rawValue, WalletAssetId.val.rawValue], marketCapService: f.market) { selected = $0 }
        let view = try presented(ProductListViewController.self, f); let model = try XCTUnwrap(view.viewModel as? SelectAssetViewModel)
        XCTAssertEqual(model.assetIds, [WalletAssetId.xor.rawValue, WalletAssetId.val.rawValue]); model.selectionCompletion?(WalletAssetId.val.rawValue); XCTAssertEqual(selected, WalletAssetId.val.rawValue)
    }
    func testLiquiditySlippageRouteKeepsTheReviewedToleranceUntilDone() throws {
        let f = try make(); let nav = UINavigationController(rootViewController: f.host); var selected: PolkaswapSlippage?
        let expected = try XCTUnwrap(PolkaswapSlippage(basisPoints: 125))
        LiquidityWireframe().showSlippageTolerance(on: nav, currentLocale: expected) { selected = $0 }
        let view = try XCTUnwrap(nav.topViewController as? SlippageToleranceViewController)
        let model = try XCTUnwrap(view.viewModel as? SlippageToleranceViewModel)
        XCTAssertEqual(model.currentValue, expected); XCTAssertTrue(model.view === view); XCTAssertNil(selected)
        model.doneButtonTapped(); XCTAssertEqual(selected, expected)
    }
    func testLiquidityMarketRoutePreservesAllowedMarketsAndSelection() throws {
        let f = try make(); let nav = UINavigationController(rootViewController: f.host); var selected: LiquiditySourceType?
        LiquidityWireframe().showChoiсeMarket(on: nav, selectedMarket: .xyk, markets: [.xyk, .smart]) { selected = $0 }
        let view = try XCTUnwrap(nav.topViewController as? ChoiceMarketViewController); let model = try XCTUnwrap(view.viewModel as? ChoiceMarketViewModel)
        XCTAssertEqual(model.markets, [.xyk, .smart]); XCTAssertEqual(model.selectedMarket, .xyk); XCTAssertTrue(model.view === view)
        model.selectedMarket = .smart; XCTAssertEqual(selected, .smart)
    }
    func testSupplyConfirmationPreservesBothExactAmountsAndFeeReviewCallback() throws {
        let f = try make(); let nav = UINavigationController(rootViewController: f.host); var changes = 0
        let first = Decimal(string: "1.000000000000000001")!, second = Decimal(string: "2.000000000000000003")!
        LiquidityWireframe().showSupplyLiquidityConfirmation(on: nav, baseAssetId: WalletAssetId.xor.rawValue, targetAssetId: WalletAssetId.val.rawValue, fiatService: f.fiat, poolsService: f.pools, assetManager: f.assets, firstAssetAmount: first, secondAssetAmount: second, slippageTolerance: .defaultValue, details: [], transactionType: .liquidityAdd, fee: 3, operationFactory: f.network) { changes += 1 }
        let view = try XCTUnwrap(nav.topViewController as? ConfirmViewController); let model = try XCTUnwrap(view.viewModel as? ConfirmSupplyLiquidityViewModel)
        XCTAssertEqual(model.firstAssetAmount, first); XCTAssertEqual(model.secondAssetAmount, second); XCTAssertEqual(model.fee, 3); XCTAssertEqual(model.transactionType, .liquidityAdd); XCTAssertEqual(model.baseAssetId, WalletAssetId.xor.rawValue); XCTAssertTrue(model.view === view)
        XCTAssertEqual(changes, 0); model.feeChangeHandler(); XCTAssertEqual(changes, 1)
    }
    func testRemovalConfirmationPreservesPoolAndCompletionCallbacks() throws {
        let f = try make(); let nav = UINavigationController(rootViewController: f.host); var changes = 0, completions = 0
        LiquidityWireframe().showRemoveLiquidityConfirmation(on: nav, poolInfo: f.pool, poolsService: f.pools, assetManager: f.assets, firstAssetAmount: 2, secondAssetAmount: 4, slippageTolerance: .defaultValue, details: [], fee: 3, operationFactory: f.network, feeChangeHandler: { changes += 1 }, completionHandler: { completions += 1 })
        let view = try XCTUnwrap(nav.topViewController as? ConfirmViewController); let model = try XCTUnwrap(view.viewModel as? ConfirmRemoveLiquidityViewModel)
        XCTAssertEqual(model.poolInfo.identifier, f.pool.identifier); XCTAssertEqual(model.firstAssetAmount, 2); XCTAssertEqual(model.secondAssetAmount, 4); XCTAssertEqual(model.fee, 3); XCTAssertTrue(model.view === view)
        XCTAssertEqual(completions, 0); model.feeChangeHandler(); model.completionHandler?(); XCTAssertEqual(changes, 1); XCTAssertEqual(completions, 1)
    }
    func testReferrerFactoryBindsThePresenterToItsView() throws {
        let view = try XCTUnwrap(ReferralViewFactory.createReferrerView(with: "referrer-address") as? YourReferrerViewController)
        let presenter = try XCTUnwrap(view.presenter as? YourReferrerPresenter); XCTAssertTrue(presenter.view === view)
    }
    func testFriendsReferrerRoutePushesOnlyWhenNavigationExists() throws {
        let f = try make(); let route = FriendsWireframe(walletContext: WalletContextMock(), assetManager: f.assets)
        route.showReferrerScreen(from: f.host, referrer: "referrer-address"); XCTAssertTrue(f.host.shown.isEmpty)
        let nav = UINavigationController(rootViewController: f.host); route.showReferrerScreen(from: f.host, referrer: "referrer-address")
        XCTAssertTrue(nav.topViewController is YourReferrerViewController); XCTAssertEqual(nav.viewControllers.count, 2)
    }
    func testFriendsStackReplacementDropsStaleInputControllers() throws {
        let f = try make(); let stale = UIViewController(); let nav = RouteStackNavigationController(rootViewController: f.host); nav.pushViewController(stale, animated: false)
        FriendsWireframe(walletContext: WalletContextMock(), assetManager: f.assets).setViewControllers(from: stale, currentController: f.host, referrer: "referrer-address")
        XCTAssertEqual(nav.requestedAnimation, true)
        XCTAssertEqual(nav.viewControllers.count, 2); XCTAssertTrue(nav.viewControllers.first === f.host); XCTAssertTrue(nav.topViewController is YourReferrerViewController); XCTAssertFalse(nav.viewControllers.contains(stale))
    }
    func testFriendsStackReplacementRequiresTheExistingFriendsScreen() throws {
        let f = try make(); let nav = UINavigationController(rootViewController: f.host)
        FriendsWireframe(walletContext: WalletContextMock(), assetManager: f.assets).setViewControllers(from: f.host, currentController: nil, referrer: "referrer-address")
        XCTAssertEqual(nav.viewControllers.count, 1)
    }
    func testFriendsSharingPresentsTheSystemShareSheetWithExcludedTargets() throws {
        let f = try make(); FriendsWireframe(walletContext: WalletContextMock(), assetManager: f.assets).showActivityViewController(from: f.host, shareText: "Public referral link")
        let view = try XCTUnwrap(f.host.shown.last as? UIActivityViewController)
        XCTAssertEqual(view.excludedActivityTypes, [.airDrop, .postToFacebook])
    }
    func testReferralActivityFactoryBindsTheModelAndCompletion() throws {
        let f = try make(); var closes = 0
        let view = try XCTUnwrap(ReferralViewFactory.createActivityDetailsView(assetManager: f.assets, model: transaction(), completion: { closes += 1 }) as? ActivityDetailsViewController)
        let model = try XCTUnwrap(view.viewModel as? ActivityDetailsViewModel); XCTAssertTrue(model.view === view)
        model.completion?(); XCTAssertEqual(closes, 1)
    }
    func testReferralActivityFactoryRequiresASelectedWallet() throws {
        let f = try make(); SelectedWalletSettings.shared.commitInternalValue(nil)
        XCTAssertNil(ReferralViewFactory.createActivityDetailsView(assetManager: f.assets, model: transaction(), completion: nil))
    }
    func testFriendsActivityRoutePassesDismissalToBothContainerAndModel() throws {
        let f = try make(); var closes = 0
        FriendsWireframe(walletContext: WalletContextMock(), assetManager: f.assets).showActivityDetails(from: f.host, model: transaction(), completion: { closes += 1 })
        let container = try XCTUnwrap(f.host.shown.last as? BlurViewController); let view = try XCTUnwrap(container.children.first as? ActivityDetailsViewController)
        XCTAssertNotNil((view.viewModel as? ActivityDetailsViewModel)?.completion); container.completionHandler?(); XCTAssertEqual(closes, 1)
    }
    func testFriendsActivityRouteWithoutHostDoesNotPresentElsewhere() throws {
        let f = try make(); FriendsWireframe(walletContext: WalletContextMock(), assetManager: f.assets).showActivityDetails(from: nil, model: transaction(), completion: nil)
        XCTAssertTrue(f.host.shown.isEmpty)
    }
}

extension RouteHost: RedesignWalletViewProtocol {}

@MainActor
final class AdditionalRouteCoverageTests: XCTestCase {
    private var previous: AccountItem?
    override func setUp() { super.setUp(); previous = SelectedWalletSettings.shared.currentAccount }
    override func tearDown() { SelectedWalletSettings.shared.commitInternalValue(previous); super.tearDown() }
    private func make() throws -> RouteFixture { let f = try RouteFixture(); SelectedWalletSettings.shared.commitInternalValue(f.account); return f }
    private func contacts(_ f: RouteFixture, completion: ((ScanQRResult) -> Void)? = nil) {
        let provider = SingleValueProvider<[SearchData]>(targetIdentifier: "route-contacts", source: AnySingleValueProviderSource { CompoundOperationWrapper(targetOperation: ClosureOperation<[SearchData]?> { [] }) }, repository: AnyDataProviderRepository(RouteContactsCache()), updateTrigger: DataProviderEventTrigger.onInitialization)
        InputAssetAmountWireframe().showSelectAddress(on: f.host, assetId: WalletAssetId.val.rawValue, dataProvider: provider, walletService: WalletService(operationFactory: f.network), networkFacade: f.network, assetManager: f.assets, qrEncoder: f.encoder, sharingFactory: RouteShare(), assetsProvider: f.balances, providerFactory: f.provider, feeProvider: f.fees, marketCapService: f.market, completion: completion)
    }
    private func screen<T: UIViewController>(_ type: T.Type, _ f: RouteFixture) throws -> T {
        let container = try XCTUnwrap(f.host.shown.last as? BlurViewController)
        XCTAssertEqual(container.modalPresentationStyle, .overFullScreen)
        let nav = try XCTUnwrap(container.children.first as? UINavigationController)
        return try XCTUnwrap(nav.viewControllers.first as? T)
    }
    func testAddressPickerBindsItsControllerAndPassesTheChosenContactBack() throws {
        let f = try make(); var result: ScanQRResult?; contacts(f) { result = $0 }
        let view = try screen(ContactsViewController.self, f); let model = try XCTUnwrap(view.viewModel as? ContactsViewModel)
        XCTAssertTrue(model.view === view); XCTAssertNil(result)
        model.completion?(ScanQRResult(firstName: "Chosen contact")); XCTAssertEqual(result?.firstName, "Chosen contact")
    }
    func testAddressPickerRequiresASelectedAccount() throws {
        let f = try make(); SelectedWalletSettings.shared.commitInternalValue(nil); contacts(f)
        XCTAssertTrue(f.host.shown.isEmpty)
    }
    func testWalletEditRoutePreservesTheSharedServiceAndCompletion() throws {
        let f = try make(); let service = EditViewService(poolsService: f.pools); var done = 0
        f.walletRoute.showEditView(from: f.host, poolsService: f.pools, editViewService: service, completion: { done += 1 })
        let view = try screen(EditViewController.self, f); let model = try XCTUnwrap(view.viewModel as? EditViewModel)
        XCTAssertTrue(model.editViewService === service); XCTAssertTrue(model.view === view); XCTAssertEqual(done, 0)
        model.completion?(); XCTAssertEqual(done, 1)
    }
    func testWalletEditRouteWithNoHostDoesNotPresentElsewhere() throws {
        let f = try make(); f.walletRoute.showEditView(from: nil, poolsService: f.pools, editViewService: EditViewService(poolsService: f.pools), completion: nil)
        XCTAssertTrue(f.host.shown.isEmpty)
    }
    func testAssetActivityRouteBindsDetailsForTheSelectedWallet() throws {
        let f = try make(); let transaction = SetReferrerTransaction(base: TransactionBase(txHash: "route-activity", blockHash: "block", fee: Amount(value: 1), status: .success, timestamp: "1700000000"), who: "referrer", isMyReferrer: true, tokenId: WalletAssetId.xor.rawValue)
        f.assetRoute().showActivityDetails(model: transaction)
        let container = try XCTUnwrap(f.host.shown.last as? BlurViewController); let view = try XCTUnwrap(container.children.first as? ActivityDetailsViewController)
        XCTAssertTrue((view.viewModel as? ActivityDetailsViewModel)?.view === view); XCTAssertEqual(container.modalPresentationStyle, .overFullScreen)
    }
    func testAssetActivityRouteRequiresASelectedWallet() throws {
        let f = try make(); SelectedWalletSettings.shared.commitInternalValue(nil)
        f.assetRoute().showActivityDetails(model: SetReferrerTransaction(base: TransactionBase(txHash: "route-activity", blockHash: "block", fee: Amount(value: 1), status: .success, timestamp: "1700000000"), who: "referrer", isMyReferrer: true, tokenId: WalletAssetId.xor.rawValue))
        XCTAssertTrue(f.host.shown.isEmpty)
    }
}

private final class RouteContactsCache: DataProviderRepositoryProtocol {
    typealias Model = SingleValueProviderObject
    func fetchAllOperation(with _: RepositoryFetchOptions) -> BaseOperation<[Model]> { ClosureOperation { [] } }
    func saveOperation(_ updates: @escaping () throws -> [Model], _ deletions: @escaping () throws -> [String]) -> BaseOperation<Void> { ClosureOperation { _ = try updates(); _ = try deletions() } }
    func saveBatchOperation(_ updates: @escaping () throws -> [Model], _ deletions: @escaping () throws -> [String]) -> BaseOperation<Void> { saveOperation(updates, deletions) }
    func fetchOperation(by ids: @escaping () throws -> [String], options _: RepositoryFetchOptions) -> BaseOperation<[Model]> { ClosureOperation { _ = try ids(); return [] } }
    func fetchOperation(by id: @escaping () throws -> String, options _: RepositoryFetchOptions) -> BaseOperation<Model?> { ClosureOperation { _ = try id(); return nil } }
    func fetchOperation(by _: RepositorySliceRequest, options: RepositoryFetchOptions) -> BaseOperation<[Model]> { fetchAllOperation(with: options) }
    func replaceOperation(_ models: @escaping () throws -> [Model]) -> BaseOperation<Void> { saveOperation(models, { [] }) }
    func deleteAllOperation() -> BaseOperation<Void> { ClosureOperation {} }
    func fetchCountOperation() -> BaseOperation<Int> { ClosureOperation { 0 } }
}

@MainActor
final class TransactionResultRouteCoverageTests: XCTestCase {
    private var previous: AccountItem?
    private var previousWindow: UIWindow?
    override func setUp() {
        super.setUp(); previous = SelectedWalletSettings.shared.currentAccount
        previousWindow = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first { $0.isKeyWindow }
    }
    override func tearDown() { SelectedWalletSettings.shared.commitInternalValue(previous); previousWindow?.makeKeyAndVisible(); super.tearDown() }
    private func make() throws -> RouteFixture { let f = try RouteFixture(); SelectedWalletSettings.shared.commitInternalValue(f.account); return f }
    private var transaction: Transaction { SetReferrerTransaction(base: TransactionBase(txHash: "confirmed-route", blockHash: "block", fee: Amount(value: 1), status: .success, timestamp: "1700000000"), who: "referrer", isMyReferrer: true, tokenId: WalletAssetId.xor.rawValue) }
    private func assertDetails(_ f: RouteFixture) throws -> (BlurViewController, ActivityDetailsViewModel) {
        let container = try XCTUnwrap(f.host.shown.last as? BlurViewController)
        let view = try XCTUnwrap(container.children.first as? ActivityDetailsViewController)
        let model = try XCTUnwrap(view.viewModel as? ActivityDetailsViewModel)
        XCTAssertTrue(model.view === view); XCTAssertEqual(container.modalPresentationStyle, .overFullScreen)
        return (container, model)
    }
    func testOrdinaryConfirmationDetailsCarryBothDismissalCallbacks() throws {
        let f = try make(); var done = 0
        ConfirmWireframe().showActivityDetails(on: f.host, model: transaction, assetManager: f.assets, completion: { done += 1 })
        let (container, model) = try assertDetails(f); XCTAssertEqual(done, 0); model.completion?(); container.completionHandler?(); XCTAssertEqual(done, 2)
    }
    func testClaimConfirmationDetailsCarryBothDismissalCallbacks() throws {
        let f = try make(); var done = 0
        ConfirmTransactionWireframe().showActivityDetails(on: f.host, model: transaction, assetManager: f.assets, completion: { done += 1 })
        let (container, model) = try assertDetails(f); XCTAssertEqual(done, 0); model.completion?(); container.completionHandler?(); XCTAssertEqual(done, 2)
    }
    func testOrdinaryConfirmationDetailsRequireASelectedWallet() throws {
        let f = try make(); SelectedWalletSettings.shared.commitInternalValue(nil)
        ConfirmWireframe().showActivityDetails(on: f.host, model: transaction, assetManager: f.assets, completion: nil)
        XCTAssertTrue(f.host.shown.isEmpty)
    }
    func testClaimConfirmationDetailsRequireASelectedWallet() throws {
        let f = try make(); SelectedWalletSettings.shared.commitInternalValue(nil)
        ConfirmTransactionWireframe().showActivityDetails(on: f.host, model: transaction, assetManager: f.assets, completion: nil)
        XCTAssertTrue(f.host.shown.isEmpty)
    }
    func testOrdinaryProgressWindowAppearsAboveTheWalletThenIsReleased() throws {
        let route = ConfirmWireframe(); defer { route.hideActivityIndicator() }
        route.showActivityIndicator(); let window = try XCTUnwrap(route.activityIndicatorWindow)
        XCTAssertEqual(window.windowLevel, .alert); XCTAssertFalse(window.isHidden); XCTAssertTrue(window.rootViewController is ActivityIndicatorViewController)
        route.hideActivityIndicator(); XCTAssertNil(route.activityIndicatorWindow); XCTAssertTrue(window.isHidden)
    }
    func testClaimProgressWindowAppearsAboveTheWalletThenIsReleased() throws {
        let route = ConfirmTransactionWireframe(); defer { route.hideActivityIndicator() }
        route.showActivityIndicator(); let window = try XCTUnwrap(route.activityIndicatorWindow)
        XCTAssertEqual(window.windowLevel, .alert); XCTAssertFalse(window.isHidden); XCTAssertTrue(window.rootViewController is ActivityIndicatorViewController)
        route.hideActivityIndicator(); XCTAssertNil(route.activityIndicatorWindow); XCTAssertTrue(window.isHidden)
    }
    func testOrdinaryProgressCanBeClosedBeforeItWasShown() { let route = ConfirmWireframe(); route.hideActivityIndicator(); XCTAssertNil(route.activityIndicatorWindow) }
    func testClaimProgressCanBeClosedBeforeItWasShown() { let route = ConfirmTransactionWireframe(); route.hideActivityIndicator(); XCTAssertNil(route.activityIndicatorWindow) }
}

extension RouteHost: AccountCreateViewProtocol {
    func set(mnemonic: [String]) {}
    func set(backupDerivationPath: String) {}
    func showLoading() {}
    func hideLoading() {}
}

@MainActor
final class CreationRouteCoverageTests: XCTestCase {
    private var previous: AccountItem?
    override func setUp() { super.setUp(); previous = SelectedWalletSettings.shared.currentAccount; SelectedWalletSettings.shared.commitInternalValue(nil) }
    override func tearDown() { SelectedWalletSettings.shared.commitInternalValue(previous); super.tearDown() }
    private var words: [String] { Array(repeating: "abandon", count: 11) + ["about"] }
    private var request: AccountCreationRequest { .init(username: "Public fixture", type: .sora, derivationPath: "//fixture", cryptoType: .sr25519) }
    private func metadata(valid: Bool = true) -> AccountCreationMetadata { .init(mnemonic: valid ? words : ["invalid"], availableNetworks: [.sora], defaultNetwork: .sora, availableCryptoTypes: [.sr25519], defaultCryptoType: .sr25519) }
    func testNewAccountConfirmationPushesTheExactMnemonicQuiz() throws {
        let host = RouteHost(); let nav = UINavigationController(rootViewController: host)
        AccountCreateWireframe().confirm(from: host, request: request, metadata: metadata())
        let view = try XCTUnwrap(nav.topViewController as? ConfirmPassphraseViewController); let model = try XCTUnwrap(view.viewModel as? ConfirmPassphraseViewModel)
        XCTAssertEqual(model.mnemonic, words); XCTAssertTrue(model.view === view); XCTAssertTrue(model.interactor is AccountConfirmInteractor)
    }
    func testAddAccountConfirmationPreservesNameAndCompletionPolicy() throws {
        let host = RouteHost(); let nav = UINavigationController(rootViewController: host); let route = AddCreationWireframe(); var done = 0
        route.isNeedSetupName = false; route.endAddingBlock = { done += 1 }; route.confirm(from: host, request: request, metadata: metadata())
        let view = try XCTUnwrap(nav.topViewController as? ConfirmPassphraseViewController); let model = try XCTUnwrap(view.viewModel as? ConfirmPassphraseViewModel)
        let destination = try XCTUnwrap(model.wireframe as? ConfirmPassphraseWireframe)
        XCTAssertEqual(model.mnemonic, words); XCTAssertTrue(model.interactor is AddAccountConfirmInteractor); XCTAssertFalse(destination.isNeedSetupName); XCTAssertEqual(done, 0)
        destination.endAddingBlock?(); XCTAssertEqual(done, 1)
    }
    func testInvalidNewAccountMnemonicDoesNotLeaveTheCreationScreen() {
        let host = RouteHost(); let nav = UINavigationController(rootViewController: host)
        AccountCreateWireframe().confirm(from: host, request: request, metadata: metadata(valid: false))
        XCTAssertEqual(nav.viewControllers.count, 1)
    }
    func testInvalidAddAccountMnemonicDoesNotLeaveTheCreationScreen() {
        let host = RouteHost(); let nav = UINavigationController(rootViewController: host)
        AddCreationWireframe().confirm(from: host, request: request, metadata: metadata(valid: false))
        XCTAssertEqual(nav.viewControllers.count, 1)
    }
    func testNewAccountBackupPasswordRouteBindsItsPresenterWithoutCreatingAnAccount() throws {
        let host = RouteHost(); let nav = UINavigationController(rootViewController: host); let mnemonic = try IRMnemonicCreator().mnemonic(fromList: words.joined(separator: " "))
        AccountCreateWireframe().setupBackupAccountPassword(on: host, account: OpenBackupAccount(name: "Public fixture", address: "public-address"), createAccountRequest: request, createAccountService: RouteNoAccountCreation(), mnemonic: mnemonic)
        let view = try XCTUnwrap(nav.topViewController as? SetupPasswordViewController); let model = try XCTUnwrap(view.viewModel as? SetupPasswordPresenter)
        XCTAssertTrue(model.view === view); XCTAssertTrue(model.wireframe is SetupPasswordWireframe)
    }
    func testAddAccountBackupPasswordRouteBindsItsPresenterWithoutCreatingAnAccount() throws {
        let host = RouteHost(); let nav = UINavigationController(rootViewController: host); let mnemonic = try IRMnemonicCreator().mnemonic(fromList: words.joined(separator: " "))
        AddCreationWireframe().setupBackupAccountPassword(on: host, account: OpenBackupAccount(name: "Public fixture", address: "public-address"), createAccountRequest: request, createAccountService: RouteNoAccountCreation(), mnemonic: mnemonic)
        let view = try XCTUnwrap(nav.topViewController as? SetupPasswordViewController); let model = try XCTUnwrap(view.viewModel as? SetupPasswordPresenter)
        XCTAssertTrue(model.view === view); XCTAssertTrue(model.wireframe is SetupPasswordWireframe)
    }
    func testNewAccountPinSetupIsPresentedAsANonClosableModal() throws {
        let host = RouteHost(); AccountCreateWireframe().proceed(on: host)
        let container = try XCTUnwrap(host.shown.last as? BlurViewController); XCTAssertFalse(container.isClosable)
        XCTAssertEqual(container.modalPresentationStyle, .overFullScreen); let pin = try XCTUnwrap(container.children.first as? PincodeViewController)
        XCTAssertTrue(pin.presenter is SetupPincodePresenter)
    }
    func testAddingWithoutAnExistingCompletionPresentsPinSetup() throws {
        let host = RouteHost(); AddCreationWireframe().proceed(on: host)
        let container = try XCTUnwrap(host.shown.last as? BlurViewController); XCTAssertEqual(container.modalPresentationStyle, .overFullScreen)
        XCTAssertTrue(container.children.first is PincodeViewController)
    }
    func testFinishingAccountAdditionDismissesTheFlowAndInvokesCompletionOnce() {
        let host = RouteHost(); let nav = RouteDismissNavigationController(rootViewController: host); let route = AddCreationWireframe(); var done = 0
        route.endAddingBlock = { done += 1 }; route.isNeedSetupName = true; route.proceed(on: host)
        XCTAssertEqual(nav.dismissals, 1); XCTAssertEqual(done, 1); XCTAssertTrue(host.shown.isEmpty)
    }
}
private final class RouteNoAccountCreation: CreateAccountServiceProtocol {
    func createAccount(request: AccountCreationRequest, mnemonic: IRMnemonicProtocol, completion: @escaping (Result<AccountItem, Swift.Error>?) -> Void) { XCTFail("Navigation must not create an account") }
}
private final class RouteDismissNavigationController: UINavigationController {
    var dismissals = 0
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) { dismissals += 1; completion?() }
}


@MainActor
final class SendPreflightRouteCoverageTests: XCTestCase {
    private var previous: AccountItem?
    override func setUp() { super.setUp(); previous = SelectedWalletSettings.shared.currentAccount }
    override func tearDown() { SelectedWalletSettings.shared.commitInternalValue(previous); super.tearDown() }
    private func make() throws -> RouteFixture { let f = try RouteFixture(); SelectedWalletSettings.shared.commitInternalValue(f.account); return f }
    private func send(_ route: RedesignWalletWireframe, _ f: RouteFixture) {
        route.showSend(on: f.host, selectedTokenId: WalletAssetId.val.rawValue, selectedAddress: "public-recipient", fiatService: f.fiat, assetManager: f.assets, providerFactory: f.provider, networkFacade: f.network, assetsProvider: f.balances, qrEncoder: f.encoder, sharingFactory: RouteShare(), marketCapService: f.market)
    }
    private func send(_ route: GenerateQRWireframe, _ f: RouteFixture) {
        route.showSend(on: f.host, selectedTokenId: WalletAssetId.val.rawValue, selectedAddress: "scanned-recipient", fiatService: f.fiat, assetManager: f.assets, providerFactory: f.provider, networkFacade: f.network, assetsProvider: f.balances, qrEncoder: f.encoder, sharingFactory: RouteShare(), marketCapService: f.market)
    }
    private func confirm(_ route: GenerateQRWireframe, _ f: RouteFixture) {
        route.showConfirmSendingAsset(on: f.host, assetId: WalletAssetId.val.rawValue, walletService: WalletService(operationFactory: f.network), assetManager: f.assets, fiatService: f.fiat, recipientAddress: "scanned-recipient", firstAssetAmount: Decimal(string: "1.000000000000000001")!, fee: Decimal(string: "0.002")!, assetsProvider: f.balances)
    }
    private func asset(_ f: RouteFixture, _ preflight: @escaping WalletAccountCapability.SendPreflight) -> AssetDetailsWireframe {
        let route = AssetDetailsWireframe(accountId: f.account.publicKeyData.toHex(), address: f.account.address, assetManager: f.assets, fiatService: f.fiat, eventCenter: RouteEvents(), assetInfo: f.assets.assets[1], providerFactory: f.provider, networkFacade: f.network, polkaswapNetworkFacade: PolkaswapNetworkOperationFactory(engine: f.engine), assetsProvider: f.balances, marketCapService: f.market, qrEncoder: f.encoder, sharingFactory: RouteShare(), farmingService: f.farms, feeProvider: f.fees, sendPreflight: preflight)
        route.controller = f.host; return route
    }
    private func screen<T: UIViewController>(_ type: T.Type, _ f: RouteFixture) throws -> T {
        let container = try XCTUnwrap(f.host.shown.last as? BlurViewController); XCTAssertEqual(container.modalPresentationStyle, .overFullScreen)
        let nav = try XCTUnwrap(container.children.first as? UINavigationController); return try XCTUnwrap(nav.viewControllers.first as? T)
    }
    func testWalletSendWaitsForCapabilityEvidenceBeforePresenting() throws {
        let f = try make(); let gate = RouteSendGate(); let route = RedesignWalletWireframe(feeProvider: f.fees, sendPreflight: gate.check)
        send(route, f); XCTAssertEqual(gate.calls, 1); XCTAssertTrue(gate.controller === f.host); XCTAssertNil(gate.expectedAddress); XCTAssertTrue(f.host.shown.isEmpty)
    }
    func testApprovedWalletSendPreservesTheRecipientAndBindsItsEditor() throws {
        let f = try make(); let gate = RouteSendGate(); let route = RedesignWalletWireframe(feeProvider: f.fees, sendPreflight: gate.check)
        send(route, f); gate.approve?()
        let view = try screen(InputAssetAmountViewController.self, f); let model = try XCTUnwrap(view.viewModel as? InputAssetAmountViewModel)
        XCTAssertEqual(model.selectedAddress, "public-recipient"); XCTAssertTrue(model.view === view)
    }
    func testAssetSendRequiresTheAddressBoundToTheDetailsScreen() throws {
        let f = try make(); let gate = RouteSendGate(); let route = asset(f, gate.check); route.showSend()
        XCTAssertEqual(gate.expectedAddress, f.account.address); XCTAssertTrue(gate.controller === f.host); XCTAssertTrue(f.host.shown.isEmpty)
    }
    func testApprovedAssetSendStartsWithNoUnrelatedRecipient() throws {
        let f = try make(); let gate = RouteSendGate(); let route = asset(f, gate.check); route.showSend(); gate.approve?()
        let view = try screen(InputAssetAmountViewController.self, f); let model = try XCTUnwrap(view.viewModel as? InputAssetAmountViewModel)
        XCTAssertNil(model.selectedAddress); XCTAssertTrue(model.view === view)
    }
    func testQRSendUsesTheRequestedHostForCapabilityChecks() throws {
        let f = try make(); let gate = RouteSendGate(); let route = GenerateQRWireframe(controller: nil, sendPreflight: gate.check)
        send(route, f); XCTAssertTrue(gate.controller === f.host); XCTAssertNil(gate.expectedAddress); XCTAssertTrue(f.host.shown.isEmpty)
    }
    func testApprovedQRSendPreservesTheScannedRecipient() throws {
        let f = try make(); let gate = RouteSendGate(); let route = GenerateQRWireframe(controller: f.host, sendPreflight: gate.check)
        send(route, f); gate.approve?()
        let view = try screen(InputAssetAmountViewController.self, f); let model = try XCTUnwrap(view.viewModel as? InputAssetAmountViewModel)
        XCTAssertEqual(model.selectedAddress, "scanned-recipient"); XCTAssertTrue(model.view === view)
    }
    func testQRConfirmationWaitsForCapabilityEvidence() throws {
        let f = try make(); let gate = RouteSendGate(); let route = GenerateQRWireframe(controller: f.host, sendPreflight: gate.check)
        confirm(route, f); XCTAssertEqual(gate.calls, 1); XCTAssertTrue(gate.controller === f.host); XCTAssertTrue(f.host.shown.isEmpty)
    }
    func testApprovedQRConfirmationKeepsExactAmountFeeAndAsset() throws {
        let f = try make(); let gate = RouteSendGate(); let route = GenerateQRWireframe(controller: f.host, sendPreflight: gate.check)
        confirm(route, f); gate.approve?()
        let view = try screen(ConfirmViewController.self, f); let model = try XCTUnwrap(view.viewModel as? ConfirmSendingViewModel)
        XCTAssertEqual(model.assetId, WalletAssetId.val.rawValue); XCTAssertEqual(model.recipientAddress, "scanned-recipient")
        XCTAssertEqual(model.firstAssetAmount, Decimal(string: "1.000000000000000001")); XCTAssertEqual(model.fee, Decimal(string: "0.002")); XCTAssertTrue(model.view === view)
    }
    func testTheDefaultWalletGateRefusesAnAbsentAccount() throws {
        let f = try make(); SelectedWalletSettings.shared.commitInternalValue(nil); send(RedesignWalletWireframe(feeProvider: f.fees), f)
        XCTAssertTrue(f.host.shown.isEmpty)
    }
    func testTheDefaultQRGateRefusesAnAbsentAccount() throws {
        let f = try make(); SelectedWalletSettings.shared.commitInternalValue(nil); let route = GenerateQRWireframe(controller: f.host)
        send(route, f); confirm(route, f); XCTAssertTrue(f.host.shown.isEmpty)
    }
    func testTheDefaultAssetGateRefusesSelectionChangesAwayFromItsBoundAccount() throws {
        let f = try make(); let route = f.assetRoute(); SelectedWalletSettings.shared.commitInternalValue(nil); route.showSend()
        XCTAssertTrue(f.host.shown.isEmpty)
    }
}

@MainActor
private final class RouteSendGate {
    var calls = 0; weak var controller: UIViewController?; var expectedAddress: String?; var approve: (@MainActor () -> Void)?
    func check(_ controller: UIViewController?, _ expectedAddress: String?, _ proceed: @escaping @MainActor () -> Void) {
        calls += 1; self.controller = controller; self.expectedAddress = expectedAddress; approve = proceed
    }
}

@MainActor
final class ReferralFactoryAssemblyCoverageTests: XCTestCase {
    private func dependencies(_ f: RouteFixture) -> ReferralAssemblyDependencies {
        .init(settings: InMemorySettingsManager(), keystore: InMemoryKeychain(), connection: { f.engine },
              runtime: { ReferralRouteRuntime() }, selectedAccount: { f.account }, assetManager: { f.assets })
    }
    private func reward(_ f: RouteFixture, _ output: ReferralRouteOutput, _ deps: ReferralAssemblyDependencies,
                        type: InputRewardAmountType = .bond) -> UIViewController? {
        ReferralViewFactory.createInputRewardAmountView(with: Decimal(string: "0.25")!, bondedAmount: Decimal(string: "2.6")!,
            type: type, walletContext: WalletContextMock(), delegate: output, dependencies: deps)
    }
    func testInputLinkFactoryBindsPresenterInteractorViewAndDelegate() throws {
        let f = try RouteFixture(), output = ReferralRouteOutput()
        let view = try XCTUnwrap(ReferralViewFactory.createInputLinkView(with: output, dependencies: dependencies(f)) as? InputLinkViewController)
        let presenter = try XCTUnwrap(view.presenter as? InputLinkPresenter)
        let interactor = try XCTUnwrap(presenter.interactor as? InputLinkInteractor)
        XCTAssertTrue(presenter.view === view); XCTAssertTrue(presenter.output === output); XCTAssertTrue(interactor.presenter === presenter)
        XCTAssertTrue(interactor.isCurrentUserAddress(with: f.account.address))
        XCTAssertEqual(interactor.getAccountId(from: f.account.address), f.account.publicKeyData)
        XCTAssertFalse(interactor.isCurrentUserAddress(with: "invalid-referrer"))
    }
    func testInputLinkFactoryRejectsAMissingConnection() throws {
        let f = try RouteFixture(); var deps = dependencies(f); deps.connection = { nil }
        XCTAssertNil(ReferralViewFactory.createInputLinkView(with: ReferralRouteOutput(), dependencies: deps))
    }
    func testInputLinkFactoryRejectsAMissingRuntime() throws {
        let f = try RouteFixture(); var deps = dependencies(f); deps.runtime = { nil }
        XCTAssertNil(ReferralViewFactory.createInputLinkView(with: ReferralRouteOutput(), dependencies: deps))
    }
    func testInputLinkFactoryRejectsAMissingAccount() throws {
        let f = try RouteFixture(); var deps = dependencies(f); deps.selectedAccount = { nil }
        XCTAssertNil(ReferralViewFactory.createInputLinkView(with: ReferralRouteOutput(), dependencies: deps))
    }
    func testInputLinkFactoryDoesNotRetainTheNavigationDelegate() throws {
        let f = try RouteFixture(); var output: ReferralRouteOutput? = ReferralRouteOutput()
        let view = try XCTUnwrap(ReferralViewFactory.createInputLinkView(with: XCTUnwrap(output), dependencies: dependencies(f)) as? InputLinkViewController)
        let presenter = try XCTUnwrap(view.presenter as? InputLinkPresenter); weak var weakOutput = output; output = nil
        XCTAssertNil(weakOutput); XCTAssertNil(presenter.output)
    }
    func testBondFactoryKeepsFeeAndStartsWithoutBondedInvitations() throws {
        let f = try RouteFixture(), output = ReferralRouteOutput()
        let view = try XCTUnwrap(reward(f, output, dependencies(f)) as? InputRewardAmountViewController)
        let presenter = try XCTUnwrap(view.presenter as? InputRewardAmountPresenter)
        XCTAssertTrue(presenter.view === view); XCTAssertTrue(presenter.output === output)
        presenter.received(100)
        let model = try XCTUnwrap(presenter.viewModel)
        XCTAssertEqual(model.fee, Decimal(string: "0.25")); XCTAssertEqual(model.feeSymbol, "XOR")
        XCTAssertEqual(model.bondedAmount, 0); XCTAssertEqual(model.buttonTitle, InputRewardAmountType.bond.buttonTitle)
        XCTAssertTrue(model.delegate === presenter)
    }
    func testUnbondFactoryKeepsOnlyCompletePreviouslyBondedInvitations() throws {
        let f = try RouteFixture(), output = ReferralRouteOutput()
        let view = try XCTUnwrap(reward(f, output, dependencies(f), type: .unbond) as? InputRewardAmountViewController)
        let presenter = try XCTUnwrap(view.presenter as? InputRewardAmountPresenter); presenter.received(100)
        let model = try XCTUnwrap(presenter.viewModel)
        XCTAssertEqual(model.bondedAmount, Decimal(string: "2.5")); XCTAssertEqual(model.fee, Decimal(string: "0.25"))
        XCTAssertEqual(model.buttonTitle, InputRewardAmountType.unbond.buttonTitle)
    }
    func testRewardFactoryRejectsAMissingConnection() throws {
        let f = try RouteFixture(); var deps = dependencies(f); deps.connection = { nil }
        XCTAssertNil(reward(f, ReferralRouteOutput(), deps))
    }
    func testRewardFactoryRejectsAMissingRuntime() throws {
        let f = try RouteFixture(); var deps = dependencies(f); deps.runtime = { nil }
        XCTAssertNil(reward(f, ReferralRouteOutput(), deps))
    }
    func testRewardFactoryRejectsAMissingAccount() throws {
        let f = try RouteFixture(); var deps = dependencies(f); deps.selectedAccount = { nil }
        XCTAssertNil(reward(f, ReferralRouteOutput(), deps))
    }
    func testRewardFactoryRejectsACatalogWithoutAFeeAsset() throws {
        let f = try RouteFixture(); f.assets.assets.removeAll { $0.isFeeAsset }
        XCTAssertNil(reward(f, ReferralRouteOutput(), dependencies(f)))
    }
}

private final class ReferralRouteOutput: InputLinkPresenterOutput, InputRewardAmountPresenterOutput {
    func setupReferrer(_ referrer: String) { XCTFail("No referrer submission is part of assembly") }
    func showAlert(withSuccess isSuccess: Bool) {}
    func showTransactionDetails(from controller: UIViewController?, result: Result<String, Error>, peerAddress: String, completion: (() -> Void)?) { XCTFail("No transaction is part of assembly") }
    func moveForward(controller: UIViewController?) {}
    func updateReferral(balance: Decimal) { XCTFail("No reward submission is part of assembly") }
    func showTransactionDetails(from controller: UIViewController?, result: Result<String, Error>, fee: Decimal, amount: Decimal, type: ReferralBondTransaction.ReferralTransactionType, completion: (() -> Void)?) { XCTFail("No transaction is part of assembly") }
}

private final class ReferralRouteRuntime: RuntimeProviderProtocol {
    let chainId = PIIndexerClient.soraMainnetGenesis
    var snapshot: RuntimeSnapshot? { nil }
    func setup() {}
    func setupHot() {}
    func replaceTypesUsage(_ usage: SoraPassport.ChainModel.TypesUsage) {}
    func cleanup() {}
    func fetchCoderFactoryOperation(with timeout: TimeInterval, closure: SoraPassport.RuntimeMetadataClosure?) -> BaseOperation<RuntimeCoderFactoryProtocol> {
        ClosureOperation { throw CancellationError() }
    }
}

private final class RouteStackNavigationController: UINavigationController {
    var requestedAnimation: Bool?
    override func setViewControllers(_ viewControllers: [UIViewController], animated: Bool) {
        requestedAnimation = animated
        super.setViewControllers(viewControllers, animated: false)
    }
}

@MainActor
final class IrohaCoordinatorRoutingCoverageTests: RootActionFixtureTests {
    private var malformedLaunch: URL { URL(string: "iroha://connect?v=1")! }
    private func expectBlocked(from host: UIViewController) async throws {
        XCTAssertTrue(IrohaConnectCoordinator.shared.handle(malformedLaunch, in: window))
        await wait { host.presentedViewController is UIAlertController }
        let alert = try XCTUnwrap(host.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.title, "IrohaConnect request blocked")
        XCTAssertFalse(try XCTUnwrap(alert.message).isEmpty)
        XCTAssertEqual(alert.actions.map(\.title), ["OK"])
        XCTAssertFalse(alert.actions.contains { $0.style == .destructive })
    }
    func testUnrecognizedLinksNeverPresentAConnectionOrError() async {
        let host = UIViewController(); mount(host)
        for value in ["https://connect?v=1", "iroha://unrelated?v=1", "wallet://connect?v=1"] {
            XCTAssertFalse(IrohaConnectCoordinator.shared.handle(URL(string: value)!, in: window))
        }
        await settle()
        XCTAssertNil(host.presentedViewController)
    }
    func testAcceptedSchemeWithoutAWindowDoesNotStartPresentation() async {
        let host = UIViewController(); mount(host)
        XCTAssertTrue(IrohaConnectCoordinator.shared.handle(malformedLaunch, in: nil))
        await settle()
        XCTAssertNil(host.presentedViewController)
    }
    func testMalformedConnectRequestShowsAnExplanationBeforeWalletAccess() async throws {
        let host = UIViewController(); mount(host)
        try await expectBlocked(from: host)
    }
    func testMalformedConnectRequestUsesTheVisibleNavigationController() async throws {
        let root = UIViewController(), top = UIViewController()
        let navigation = UINavigationController(rootViewController: root)
        navigation.pushViewController(top, animated: false); mount(navigation)
        try await expectBlocked(from: top)
        XCTAssertTrue(navigation.topViewController === top)
    }
    func testMalformedConnectRequestUsesTheSelectedTab() async throws {
        let hidden = UIViewController(), selected = UIViewController()
        let tabs = UITabBarController(); tabs.viewControllers = [hidden, selected]; tabs.selectedIndex = 1
        mount(tabs)
        try await expectBlocked(from: selected)
        // UIKit forwards presentation through the tab container, so even an
        // inactive child's presentedViewController can resolve to that alert.
        XCTAssertTrue(tabs.selectedViewController === selected)
        XCTAssertNil(hidden.viewIfLoaded?.window)
    }
    func testMalformedConnectRequestUsesTheFrontmostModal() async throws {
        let host = UIViewController(), modal = UIViewController(); mount(host)
        host.present(modal, animated: false); await settle()
        try await expectBlocked(from: modal)
        XCTAssertTrue(host.presentedViewController === modal)
    }
    func testBackgroundWithNoActiveConnectionDoesNotPresentAnError() async {
        let host = UIViewController(); mount(host)
        IrohaConnectCoordinator.shared.applicationDidEnterBackground()
        await settle(); XCTAssertNil(host.presentedViewController)
    }
}
