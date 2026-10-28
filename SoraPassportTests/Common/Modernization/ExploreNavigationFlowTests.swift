// SPDX-License-Identifier: BSD-4-Clause
import BigInt
import Foundation
import IrohaCrypto
import RobinHood
import SSFUtils
import SoraFoundation
import SoraUIKit
import UIKit
import XCTest

@testable import SoraPassport

@MainActor
final class ExploreNavigationFlowTests: XCTestCase {
  private var selected: AccountItem?
  override func setUp() {
    super.setUp()
    selected = SelectedWalletSettings.shared.currentAccount
  }
  override func tearDown() {
    SelectedWalletSettings.shared.commitInternalValue(selected)
    super.tearDown()
  }
  private func make() throws -> ExploreRouteFixture {
    let f = try ExploreRouteFixture()
    SelectedWalletSettings.shared.commitInternalValue(f.account)
    return f
  }
  private func content<T: UIViewController>(_ type: T.Type, _ f: ExploreRouteFixture) throws -> T {
    let blur = try XCTUnwrap(f.host.shown.last as? BlurViewController)
    XCTAssertEqual(blur.modalPresentationStyle, .overFullScreen)
    let child = try XCTUnwrap(blur.children.first)
    return try XCTUnwrap((child as? UINavigationController)?.topViewController as? T ?? child as? T)
  }
  func testAssetRouteOpensTheRequestedAssetDetails() throws {
    let f = try make()
    f.explore().showAssetDetails(on: f.host, assetId: WalletAssetId.val.rawValue)
    let v = try content(AssetDetailsViewController.self, f)
    XCTAssertNotNil(v.viewModel)
  }
  func testUnknownAssetCannotOpenAnEmptyDetailsScreen() throws {
    let f = try make()
    f.explore().showAssetDetails(on: f.host, assetId: "missing")
    XCTAssertTrue(f.host.shown.isEmpty)
  }
  func testAssetRouteRequiresItsFiatService() throws {
    let f = try make()
    f.explore(missing: .fiat).showAssetDetails(on: f.host, assetId: WalletAssetId.val.rawValue)
    XCTAssertTrue(f.host.shown.isEmpty)
  }
  func testAssetRouteRequiresItsSwapReadService() throws {
    let f = try make()
    f.explore(noSwap: true).showAssetDetails(on: f.host, assetId: WalletAssetId.val.rawValue)
    XCTAssertTrue(f.host.shown.isEmpty)
  }
  func testPoolRouteOpensTheRequestedPool() throws {
    let f = try make()
    f.explore().showAccountPoolDetails(on: f.host, poolInfo: f.pool)
    let v = try content(PoolDetailsViewController.self, f)
    XCTAssertNotNil(v.viewModel)
  }
  func testPoolRouteRequiresItsNetworkFactory() throws {
    let f = try make()
    f.explore(missing: .network).showAccountPoolDetails(on: f.host, poolInfo: f.pool)
    XCTAssertTrue(f.host.shown.isEmpty)
  }
  func testPoolRouteRequiresItsFiatService() throws {
    let f = try make()
    f.explore(missing: .fiat).showAccountPoolDetails(on: f.host, poolInfo: f.pool)
    XCTAssertTrue(f.host.shown.isEmpty)
  }
  func testLiquidityRouteOpensTheRealLiquidityController() throws {
    let f = try make()
    f.explore().showLiquidity(on: f.host)
    let v = try content(PolkaswapViewController.self, f)
    XCTAssertTrue(v.viewModel is SupplyLiquidityViewModel)
  }
  func testLiquidityRouteRequiresItsNetworkFactory() throws {
    let f = try make()
    f.explore(missing: .network).showLiquidity(on: f.host)
    XCTAssertTrue(f.host.shown.isEmpty)
  }
  func testLiquidityRouteRequiresItsFiatService() throws {
    let f = try make()
    f.explore(missing: .fiat).showLiquidity(on: f.host)
    XCTAssertTrue(f.host.shown.isEmpty)
  }
  func testFarmRouteOpensTheRealFarmDetailsController() throws {
    let f = try make()
    f.explore().showFarmDetails(on: f.host, farm: f.farm)
    let v = try content(FarmDetailsViewController.self, f)
    XCTAssertNotNil(v.viewModel)
  }
  func testMissingPresenterDoesNotPresentAssetDetails() throws {
    let f = try make()
    f.explore().showAssetDetails(on: nil, assetId: WalletAssetId.val.rawValue)
    XCTAssertTrue(f.host.shown.isEmpty)
  }
  func testMissingPresenterDoesNotPresentPoolDetails() throws {
    let f = try make()
    f.explore().showAccountPoolDetails(on: nil, poolInfo: f.pool)
    XCTAssertTrue(f.host.shown.isEmpty)
  }
  func testMissingPresenterDoesNotPresentLiquidity() throws {
    let f = try make()
    f.explore().showLiquidity(on: nil)
    XCTAssertTrue(f.host.shown.isEmpty)
  }
  func testMissingPresenterDoesNotPresentFarmDetails() throws {
    let f = try make()
    f.explore().showFarmDetails(on: nil, farm: f.farm)
    XCTAssertTrue(f.host.shown.isEmpty)
  }
  func testAllExploreRoutesUseOneContentContainer() throws {
    let f = try make()
    let r = f.explore()
    r.showAssetDetails(on: f.host, assetId: WalletAssetId.val.rawValue)
    r.showAccountPoolDetails(on: f.host, poolInfo: f.pool)
    r.showLiquidity(on: f.host)
    r.showFarmDetails(on: f.host, farm: f.farm)
    XCTAssertEqual(f.host.shown.count, 4)
    for v in f.host.shown {
      XCTAssertEqual(v.children.count, 1)
      let child = try XCTUnwrap(v.children.first)
      if let nav = child as? UINavigationController {
        XCTAssertEqual(nav.viewControllers.count, 1)
        XCTAssertFalse(nav.topViewController is BlurViewController)
      } else {
        XCTAssertTrue(child is AssetDetailsViewController)
      }
    }
  }
}
private final class RouteCatalog: ExplorePoolsServiceInputProtocol {
  func getPools(with fiat: [PIExactFiatData]) async throws -> [ExplorePool] { [] }
}
private actor RouteAPY: APYServiceProtocol {
  func getApy(for baseAssetId: String, targetAssetId: String) async -> Decimal? { nil }
  func setup(factory: PolkaswapNetworkOperationFactoryProtocol) {}
}
@MainActor
private final class ExploreRouteFixture {
  enum Missing { case pool, pools, balances, fiat, network }
  let account: AccountItem
  let host = ExploreRouteHost(), assets = ExploreRouteAssets(), balances = ExploreRouteBalances(),
    pools = ExploreRoutePools(), farms = ExploreRouteFarms(), fees = ExploreRouteFees(),
    engine = ExploreRouteEngine(), fiat = ExploreRouteFiat(), market = ExploreRouteMarket(),
    network = WalletNetworkOperationFactoryProtocolMock(), encoder = ExploreRouteEncoder()
  let provider: BalanceProviderFactory
  var pool: PoolInfo {
    .init(
      baseAssetId: WalletAssetId.xor.rawValue, targetAssetId: WalletAssetId.val.rawValue,
      poolId: "public-pool", accountId: account.address, baseAssetPooledByAccount: 10,
      targetAssetPooledByAccount: 20, accountPoolBalance: 5)
  }
  var farm: Farm {
    .init(
      id: "public-farm", name: "XOR-VAL", baseAsset: assets.assets[0], poolAsset: assets.assets[1],
      rewardAsset: assets.assets[0], tvl: 100, apr: 12, depositFee: 0)
  }
  var walletExploreRoute: RedesignWalletWireframe { .init(feeProvider: fees) }
  var assetFactory: AssetViewModelFactory {
    .init(walletAssets: assets.assets, assetManager: assets, fiatService: fiat)
  }
  var poolFactory: PoolViewModelFactory {
    .init(walletAssets: assets.assets, assetManager: assets, fiatService: fiat)
  }
  func explore(missing: Missing? = nil, noSwap: Bool = false) -> ExploreWireframe {
    let item = ExploreItemFactory(assetManager: assets)
    let catalog = RouteCatalog()
    let apy = RouteAPY()
    let models = ExplorePoolsViewModelService(
      itemFactory: item, poolsService: catalog, apyService: apy, fiatService: fiat)
    return ExploreWireframe(
      fiatService: missing == .fiat ? nil : fiat, itemFactory: item, assetManager: assets,
      marketCapService: market, explorePoolsService: catalog, apyService: apy,
      assetViewModelFactory: assetFactory, poolsService: pools, poolViewModelsFactory: poolFactory,
      providerFactory: provider, networkFacade: missing == .network ? nil : network,
      accountId: account.publicKeyData.toHex(), address: account.address,
      polkaswapNetworkFacade: noSwap ? nil : PolkaswapNetworkOperationFactory(engine: engine),
      qrEncoder: encoder, sharingFactory: ExploreRouteShare(),
      referralFactory: ExploreRouteReferrals(), assetsProvider: balances, farmingService: farms,
      poolViewModelsService: models, feeProvider: fees,
      walletService: WalletService(operationFactory: network))
  }
  func showAssetList() {
    walletExploreRoute.showFullListAssets(
      on: host, assetManager: assets, fiatService: fiat, assetViewModelFactory: assetFactory,
      providerFactory: provider, poolsService: pools, networkFacade: network,
      accountId: account.publicKeyData.toHex(), address: account.address,
      polkaswapNetworkFacade: PolkaswapNetworkOperationFactory(engine: engine), qrEncoder: encoder,
      sharingFactory: ExploreRouteShare(), referralFactory: ExploreRouteReferrals(),
      assetsProvider: balances, marketCapService: market, farmingService: farms, updateHandler: nil)
  }
  func showPoolList() {
    walletExploreRoute.showFullListPools(
      on: host, poolsService: pools, networkFacade: network,
      polkaswapNetworkFacade: PolkaswapNetworkOperationFactory(engine: engine),
      assetManager: assets, fiatService: fiat, poolViewModelFactory: poolFactory,
      providerFactory: provider, operationFactory: network, assetsProvider: balances,
      marketCapService: market, farmingService: farms, updateHandler: nil)
  }
  func showQR(close: (() -> Void)? = nil) {
    walletExploreRoute.showGenerateQR(
      on: host, accountId: account.publicKeyData.toHex(), address: account.address,
      username: account.username, qrEncoder: encoder, sharingFactory: ExploreRouteShare(),
      assetManager: assets, assetsProvider: balances, networkFacade: network,
      providerFactory: provider, isScanQRShown: false, marketCapService: market, closeHandler: close
    )
  }
  var details: DetailViewModelFactory { .init(assetManager: assets) }
  var farmExploreRoute: FarmDetailsWireframe {
    .init(
      feeProvider: fees, walletService: WalletService(operationFactory: network),
      assetManager: assets)
  }
  var poolExploreRoute: PoolDetailsWireframe {
    .init(
      feeProvider: fees, providerFactory: provider, operationFactory: network,
      assetsProvider: balances, marketCapService: market)
  }
  init() throws {
    let key = Data(repeating: 0x42, count: 32)
    account = AccountItem(
      address: try SS58AddressFactory().addressFromAccountId(
        data: key, type: SoraPassport.Chain.sora.addressType()), cryptoType: .sr25519,
      networkType: SoraPassport.Chain.sora.addressType(), username: "Fixture", publicKeyData: key,
      settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0,
      isSelected: true)
    provider = BalanceProviderFactory(
      accountId: key.toHex(), cacheFacade: CoreDataCacheFacade.shared,
      networkOperationFactory: network, identifierFactory: SingleProviderIdentifierFactory())
  }
  func assetExploreRoute(network available: Bool = true) -> AssetDetailsWireframe {
    let route = AssetDetailsWireframe(
      accountId: account.publicKeyData.toHex(), address: account.address, assetManager: assets,
      fiatService: fiat, eventCenter: ExploreRouteEvents(), assetInfo: assets.assets[1],
      providerFactory: provider, networkFacade: available ? network : nil,
      polkaswapNetworkFacade: PolkaswapNetworkOperationFactory(engine: engine),
      assetsProvider: balances, marketCapService: market, qrEncoder: encoder,
      sharingFactory: ExploreRouteShare(), farmingService: farms, feeProvider: fees)
    route.controller = host
    return route
  }
  func showFarmPool(missing: Missing? = nil) {
    farmExploreRoute.showPoolDetails(
      on: host, poolInfo: missing == .pool ? nil : pool, fiatService: missing == .fiat ? nil : fiat,
      poolsService: missing == .pools ? nil : pools, providerFactory: provider,
      operationFactory: missing == .network ? nil : network,
      assetsProvider: missing == .balances ? nil : balances, marketCapService: market,
      farmingService: farms)
  }
}
private final class ExploreRouteHost: UIViewController {
  var shown = [UIViewController]()
  override func present(
    _ viewControllerToPresent: UIViewController, animated flag: Bool,
    completion: (() -> Void)? = nil
  ) {
    shown.append(viewControllerToPresent)
    completion?()
  }
}
private final class ExploreRouteEncoder: WalletQREncoderProtocol {
  private let lock = NSLock()
  private var values = [ReceiveInfo]()
  var infos: [ReceiveInfo] {
    lock.lock()
    defer { lock.unlock() }
    return values
  }
  func encode(receiverInfo: ReceiveInfo) throws -> Data {
    lock.lock()
    values.append(receiverInfo)
    lock.unlock()
    return Data("public-qr-fixture".utf8)
  }
}
private final class ExploreRouteShare: AccountShareFactoryProtocol {
  func createSources(for receiveInfo: ReceiveInfo, qrImage: UIImage) -> [Any] { [] }
}
private final class ExploreRouteEvents: EventCenterProtocol {
  func notify(with event: EventProtocol) {}
  func notify(with event: EventProtocol, completionOnMain: @escaping () -> Void) {
    DispatchQueue.main.async(execute: completionOnMain)
  }
  func add(observer: EventVisitorProtocol, dispatchIn: DispatchQueue?) {}
  func remove(observer: EventVisitorProtocol) {}
}
private final class ExploreRouteFees: FeeProviderProtocol {
  func getFee(for type: TransactionType, completion: @escaping (Decimal) -> Void) { completion(1) }
  func getFee(for type: InputRewardAmountType, completion: @escaping (Decimal) -> Void) {
    completion(1)
  }
  func getFee(for call: any RuntimeCallable) async -> Decimal { 1 }
  func getFee(for type: TransactionType) async -> Decimal { 1 }
}
private final class ExploreRouteAssets: AssetManagerProtocol {
  static var networkAssets: [AssetInfo] = []
  let assets = [
    AssetInfo(
      id: WalletAssetId.xor.rawValue, symbol: "XOR", chainId: "", precision: 18, icon: nil,
      displayName: "SORA", visible: true),
    AssetInfo(
      id: WalletAssetId.val.rawValue, symbol: "VAL", chainId: "", precision: 18, icon: nil,
      displayName: "Validator", visible: true),
    AssetInfo(
      id: "custom-zero", symbol: "ZERO", chainId: "", precision: 18, icon: nil,
      displayName: "Zero asset", visible: false),
    AssetInfo(
      id: "custom-unknown", symbol: "UNKNOWN", chainId: "", precision: 18, icon: nil,
      displayName: "Unread asset", visible: false),
  ]
  var saved: [[AssetInfo]] = []
  func assetInfo(for identifier: String) -> AssetInfo? {
    assets.first { $0.identifier == identifier }
  }
  func getAssetList() -> [AssetInfo]? { assets }
  func updateAssetList(_ list: [AssetInfo]) {}
  func saveAssetList(_ list: [AssetInfo]) { saved.append(list) }
  func sortedAssets(_ list: [WalletAsset], onlyVisible: Bool) -> [WalletAsset] { list }
  func visibleCount() -> UInt { 2 }
  func setup(for accountSettings: SelectedWalletSettings) {}
}

private actor ExploreRouteFiat: FiatServiceProtocol {
  func getFiat() async -> [PIExactFiatData] { [] }
}

private final class ExploreRouteMarket: MarketCapServiceProtocol {
  func getMarketCap(for assets: [String]) async -> Set<MarketCapInfo> { [] }
}

private final class ExploreRouteBalances: AssetProviderProtocol {
  var balances: [BalanceData] = []
  var unavailable: Set<String> = []
  var additions = 0
  func getBalances(with assetIds: [String]) -> [BalanceData] {
    balances.filter { assetIds.contains($0.identifier) }
  }
  func unavailableBalanceAssetIds(among assetIds: [String]) -> Set<String> {
    unavailable.intersection(assetIds)
  }
  func add(observer: AssetProviderObserverProtocol) { additions += 1 }
  func remove(observer: AssetProviderObserverProtocol) {}
}

private final class ExploreRoutePools: PoolsServiceInputProtocol {
  let state = PoolNetworkState(isPresented: false, isEnabled: false)
  var pool: PoolInfo? = nil

  func loadAccountPools() {}
  func getAccountPools() -> [PoolInfo] { pool.map { [$0] } ?? [] }
  var saved: [[PoolInfo]] = []
  func updatePools(_ pools: [PoolInfo]) { saved.append(pools) }
  func getPool(by _: String) -> PoolInfo? { pool }
  func getPool(by _: String, targetAssetId _: String) async -> PoolInfo? { pool }
  func loadPool(by _: String, targetAssetId _: String) async -> PoolInfo? { pool }
  func loadPairState(baseAssetId _: String, targetAssetId _: String) async throws
    -> PoolNetworkState
  { state }
  func loadPools(currentAsset _: AssetInfo) -> [PoolInfo] { [] }
  func loadTargetPools(for _: String) -> [PoolInfo] { [] }
  var delegates = 0
  func appendDelegate(delegate _: PoolsServiceOutput) { delegates += 1 }
}

private final class ExploreRouteFarms: DemeterFarmingServiceProtocol {
  func getUserFarmInfos(baseAssetId _: String?, targetAssetId _: String?) async -> [UserFarm] { [] }
  func loadUserFarmInfos(baseAssetId _: String?, targetAssetId _: String?, accountId _: Data)
    async throws -> [UserFarm]
  { [] }
  func getAllFarms() async throws -> [Farm] { [] }
  func getFarm(with _: String) -> Farm? { nil }
  func getFarmDetails(baseAssetId _: String, poolAssetId _: String, rewardAssetId _: String)
    async throws -> [Farm]
  { [] }
  func getSingleSidedXorFarmedPools(completion: @escaping ([UserFarmInfo]) -> Void) {
    completion([])
  }
}

private final class ExploreRouteEngine: JSONRPCEngine {
  var url: URL?
  var pendingEngineRequests: [JSONRPCRequest] { [] }
  func callMethod<P: Codable, T: Decodable>(
    _ method: String, params: P?, options: JSONRPCOptions,
    completion closure: ((Result<T, Error>) -> Void)?
  ) throws -> UInt16 {
    if method.contains("submit") { XCTFail("No transport is permitted during tab construction") }
    throw URLError(.notConnectedToInternet)
  }
  func subscribe<P: Codable, T: Decodable>(
    _ method: String, params: P?, updateClosure: @escaping (T) -> Void,
    failureClosure: @escaping (Error, Bool) -> Void
  ) throws -> UInt16 { throw URLError(.notConnectedToInternet) }
  func cancelForIdentifier(_ identifier: UInt16) {}
  func generateRequestId() -> UInt16 { 1 }
  func addSubscription(_ subscription: JSONRPCSubscribing) {}
  func connectIfNeeded() {}
  func disconnectIfNeeded() {}
  func unsubsribe(_ identifier: UInt16) throws {}
}

private final class ExploreRouteReferrals: ReferralsOperationFactoryProtocol {
  func createReferrerBalancesOperation() -> JSONRPCListOperation<
    JSONScaleDecodable<SoraPassport.Balance>
  >? { nil }
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
