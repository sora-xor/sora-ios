// SPDX-License-Identifier: Apache-2.0
import Combine
import RobinHood
import SoraFoundation
import SoraUIKit
import UIKit
import XCTest

@testable import SoraPassport

@MainActor final class FarmDetailsFlowTests: XCTestCase {
  private let assets = FarmFlowAssets()
  private var language = "en"
  override func setUp() {
    super.setUp()
    language = LocalizationManager.shared.selectedLocalization
    LocalizationManager.shared.selectedLocalization = "en"
  }
  override func tearDown() {
    LocalizationManager.shared.selectedLocalization = language
    super.tearDown()
  }
  private func farm() -> Farm {
    let b = assets.assets[0]
    let t = assets.assets[1]
    return Farm(
      id: "\(b.assetId)-\(t.assetId)-\(b.assetId)", name: "XOR-VAL", baseAsset: b, poolAsset: t,
      rewardAsset: b, tvl: 100, apr: 12, depositFee: 0)
  }
  private func user(rewards: Decimal? = 5, tokens: Decimal? = 20, base: Int = 0, target: Int = 1)
    -> UserFarm
  {
    let b = assets.assets[base].assetId
    let t = assets.assets[target].assetId
    let r = assets.assets[0].assetId
    return UserFarm(
      id: "\(b)-\(t)-\(r)", baseAssetId: b, poolAssetId: t, rewardAssetId: r, isFarm: true,
      pooledTokens: tokens, rewards: rewards)
  }
  private func pool(farms: [UserFarm] = [], amount: Decimal? = 20) -> PoolInfo {
    PoolInfo(
      baseAssetId: assets.assets[0].assetId, targetAssetId: assets.assets[1].assetId,
      poolId: "pool", accountId: "fixture", baseAssetPooledByAccount: amount,
      targetAssetPooledByAccount: amount, accountPoolBalance: 100, farms: farms)
  }
  private struct Fixture {
    let model: FarmDetailsViewModel
    let users: FarmFlowUsers
    let pools: FarmFlowPools
    let route: FarmFlowRoute
    let view: FarmFlowView
  }
  private func make(farms: [UserFarm] = [], amount: Decimal? = 20) -> Fixture {
    let users = FarmFlowUsers()
    let pools = FarmFlowPools()
    let route = FarmFlowRoute()
    let view = FarmFlowView()
    pools.pool = pool(farms: farms, amount: amount)
    let provider = BalanceProviderFactory(
      accountId: "fixture", cacheFacade: CoreDataCacheFacade.shared,
      networkOperationFactory: WalletNetworkOperationFactoryProtocolMock(),
      identifierFactory: SingleProviderIdentifierFactory())
    let model = FarmDetailsViewModel(
      farm: farm(), poolInfo: pools.pool, poolsService: pools, fiatService: FarmFlowFiat(),
      providerFactory: provider, operationFactory: nil, assetsProvider: nil,
      marketCapService: FarmFlowMarket(), farmingService: FarmFlowFarms(),
      detailsFactory: DetailViewModelFactory(assetManager: assets), wireframe: route,
      userFarmService: users)
    model.view = view
    return Fixture(model: model, users: users, pools: pools, route: route, view: view)
  }
  private func settle() async { try? await Task.sleep(nanoseconds: 40_000_000) }
  private func start(_ f: Fixture) async {
    f.model.viewDidLoad()
    await settle()
  }
  private func row(_ f: Fixture) throws -> FarmDetailsItem {
    guard case .details(let row)? = f.model.snapshot.itemIdentifiers.first else {
      throw CancellationError()
    }
    return row
  }
  func testFarmWithLiquidityOffersInitialStake() async throws {
    let f = make()
    await start(f)
    XCTAssertEqual(try row(f).stackingState, .startStacking)
    XCTAssertFalse(try row(f).areThereRewards)
    XCTAssertTrue(try row(f).title.contains("XOR-VAL"))
  }
  func testExistingStakeOffersEditAndClaim() async throws {
    let f = make(farms: [user()])
    await start(f)
    XCTAssertEqual(try row(f).stackingState, .editFarm)
    XCTAssertTrue(try row(f).areThereRewards)
  }
  func testRewardsWithoutStakeOfferStakeAndClaim() async throws {
    let f = make(farms: [user(tokens: 0)])
    await start(f)
    XCTAssertEqual(try row(f).stackingState, .startStackingWithRewards)
    XCTAssertTrue(try row(f).areThereRewards)
  }
  func testMissingLiquidityCannotEnableStaking() async throws {
    let f = make(amount: nil)
    await start(f)
    XCTAssertEqual(try row(f).stackingState, .stackingUnavailable)
  }
  func testZeroLiquidityCannotEnableStaking() async throws {
    let f = make(amount: 0)
    await start(f)
    XCTAssertEqual(try row(f).stackingState, .stackingUnavailable)
  }
  func testNegativeLiquidityCannotEnableStaking() async throws {
    let f = make(amount: -1)
    await start(f)
    XCTAssertEqual(try row(f).stackingState, .stackingUnavailable)
  }
  func testNegativeRewardsCannotEnableClaim() async throws {
    let f = make(farms: [user(rewards: -1)])
    await start(f)
    XCTAssertFalse(try row(f).areThereRewards)
  }
  func testUnknownRewardsCannotEnableClaim() async throws {
    let f = make(farms: [user(rewards: nil)])
    await start(f)
    XCTAssertFalse(try row(f).areThereRewards)
  }
  func testFirstFarmEmissionReplacesInitialState() async throws {
    let f = make()
    await start(f)
    await f.users.emit([user()])
    await settle()
    XCTAssertEqual(try row(f).stackingState, .editFarm)
    XCTAssertTrue(try row(f).areThereRewards)
  }
  func testImmediateSubscriptionAnswerIsNotLost() async throws {
    let f = make()
    await f.users.setImmediate([user()])
    await start(f)
    XCTAssertEqual(try row(f).stackingState, .editFarm)
  }
  func testAnotherPairSharingRewardDoesNotBecomeThisFarm() async throws {
    let f = make()
    await start(f)
    await f.users.emit([])
    await f.users.emit([user(base: 1, target: 2)])
    await settle()
    XCTAssertEqual(try row(f).stackingState, .startStacking)
    XCTAssertFalse(try row(f).areThereRewards)
  }
  func testRepeatedLoadingKeepsOnlyOneSubscription() async {
    let f = make()
    await start(f)
    await start(f)
    XCTAssertEqual(f.users.observer.count, 1)
  }
  func testAnEmptyFarmUpdateClearsPreviousRewards() async throws {
    let f = make(farms: [user()])
    await start(f)
    await f.users.emit([])
    await f.users.emit([])
    await settle()
    XCTAssertFalse(try row(f).areThereRewards)
    XCTAssertEqual(try row(f).stackingState, .startStacking)
  }
  func testClaimActionCarriesReviewedFarmAndPool() async throws {
    let f = make(farms: [user()])
    await start(f)
    try row(f).onTapTopButton?()
    XCTAssertEqual(f.route.claims.count, 1)
    XCTAssertEqual(f.route.claims.first?.0.id, farm().id)
    XCTAssertEqual(f.route.claims.first?.1?.poolId, "pool")
  }
  func testEditActionCarriesCurrentPool() async throws {
    let f = make(farms: [user()])
    await start(f)
    try row(f).onTapBottomButton?()
    XCTAssertEqual(f.route.edits.count, 1)
    XCTAssertEqual(f.route.edits.first?.poolId, "pool")
  }
  func testSupplyActionRoutesTheCurrentPair() async {
    let f = make()
    await start(f)
    f.model.supplyLiquidityTapped()
    XCTAssertEqual(f.route.supplies.count, 1)
    XCTAssertEqual(f.route.supplies.first?.poolId, "pool")
  }
  func testAprExplanationIsPresented() {
    let f = make()
    f.model.aprInfoButtonTapped()
    XCTAssertEqual(f.view.alerts.count, 1)
  }
  func testOlderPoolResponseCannotReplaceNewerFarmUpdate() async throws {
    let f = make()
    await start(f)
    await f.users.emit([])
    await settle()
    f.pools.holdLoads = true
    await f.users.emit([user(rewards: 1)])
    await settle()
    await f.users.emit([user(rewards: 9)])
    await settle()
    XCTAssertEqual(f.pools.pendingLoads.count, 2)
    guard f.pools.pendingLoads.count == 2 else { return }
    f.pools.release(1, with: pool(farms: [user(rewards: 9)]))
    await settle()
    f.pools.release(0, with: pool(farms: [user(rewards: 1)]))
    await settle()
    XCTAssertEqual(f.model.poolInfo?.farms.first?.rewards, 9)
  }
  func testControllerRendersFarmDetails() async throws {
    let f = make(farms: [user()])
    let screen = FarmDetailsViewController(viewModel: f.model)
    f.model.view = screen
    screen.loadViewIfNeeded()
    await settle()
    let table = try XCTUnwrap(descendants(UITableView.self, screen.view).first)
    XCTAssertEqual(table.numberOfRows(inSection: 0), 1)
    XCTAssertTrue(
      table.dataSource?.tableView(table, cellForRowAt: IndexPath(row: 0, section: 0))
        is FarmDetailsCell)
  }
  func testAllButtonStatesHaveConsistentAvailability() {
    for state in [
      FarmDetailsBottomButtonState.startStacking, .startStackingWithRewards, .editFarm,
      .stackingUnavailable,
    ] {
      XCTAssertFalse(state.title.isEmpty)
      XCTAssertEqual(state.isUserInteractionEnabled, state != .stackingUnavailable)
      _ = state.backgroundColor
      _ = state.buttonTitleColor
    }
  }
  private func descendants<T: UIView>(_ type: T.Type, _ view: UIView) -> [T] {
    ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { descendants(type, $0) }
  }
}
private final class FarmFlowAssets: AssetManagerProtocol {
  static var networkAssets: [AssetInfo] = []
  let assets = [
    AssetInfo(
      id: WalletAssetId.xor.rawValue, symbol: "XOR", chainId: "", precision: 18, icon: nil,
      displayName: "SORA", visible: true),
    AssetInfo(
      id: WalletAssetId.val.rawValue, symbol: "VAL", chainId: "", precision: 18, icon: nil,
      displayName: "Validator", visible: true),
    AssetInfo(
      id: WalletAssetId.pswap.rawValue, symbol: "PSWAP", chainId: "", precision: 18, icon: nil,
      displayName: "Polkaswap", visible: true),
  ]
  func assetInfo(for identifier: String) -> AssetInfo? {
    assets.first { $0.identifier == identifier }
  }
  func getAssetList() -> [AssetInfo]? { assets }
  func updateAssetList(_ list: [AssetInfo]) {}
  func saveAssetList(_ list: [AssetInfo]) {}
  func sortedAssets(_ list: [WalletAsset], onlyVisible: Bool) -> [WalletAsset] { list }
  func visibleCount() -> UInt { 3 }
  func setup(for accountSettings: SelectedWalletSettings) {}
}
private actor FarmFlowFiat: FiatServiceProtocol {
  func getFiat() async -> [PIExactFiatData] { [] }
}
private final class FarmFlowValues: PoolDetailsItemServiceProtocol {
  @Published var tvl = ""
  @Published var unavailable = false
  @Published var details: [DetailViewModel] = []
  var pools: [PoolInfo] = []
  var tvlTextPublisher: Published<String>.Publisher { $tvl }
  var tvlUnavailablePublisher: Published<Bool>.Publisher { $unavailable }
  var detailsPublisher: Published<[DetailViewModel]>.Publisher { $details }
  func setup(with poolInfo: PoolInfo) { pools.append(poolInfo) }
}
private final class FarmFlowObserver {
  private let lock = NSLock()
  private var value = 0
  var count: Int {
    lock.lock()
    defer { lock.unlock() }
    return value
  }
  func add(_ delta: Int) {
    lock.lock()
    value += delta
    lock.unlock()
  }
}
private actor FarmFlowUsers: UserFarmsServiceProtocol {
  let subject = PassthroughSubject<[UserFarm], Never>()
  nonisolated let observer = FarmFlowObserver()
  var immediate: [UserFarm]?
  var userFarms: AnyPublisher<[UserFarm], Never> {
    subject.handleEvents(
      receiveSubscription: { [observer] _ in observer.add(1) },
      receiveCancel: { [observer] in observer.add(-1) }
    ).eraseToAnyPublisher()
  }
  func setImmediate(_ value: [UserFarm]) { immediate = value }
  func subscribeUserFarms(to baseAssetId: String, targetAssetId: String) async throws {
    if let immediate { subject.send(immediate) }
  }
  func emit(_ values: [UserFarm]) { subject.send(values) }
}
private final class FarmFlowFarms: DemeterFarmingServiceProtocol {
  var farms: [Farm] = []
  var fail = false
  func getUserFarmInfos(baseAssetId: String?, targetAssetId: String?) async -> [UserFarm] { [] }
  func loadUserFarmInfos(baseAssetId: String?, targetAssetId: String?, accountId: Data) async throws
    -> [UserFarm]
  { [] }
  func getAllFarms() async throws -> [Farm] {
    if fail { throw CancellationError() }
    return farms
  }
  func getFarm(with id: String) -> Farm? { farms.first { $0.id == id } }
  func getFarmDetails(baseAssetId: String, poolAssetId: String, rewardAssetId: String) async throws
    -> [Farm]
  { farms }
  func getSingleSidedXorFarmedPools(completion: @escaping ([UserFarmInfo]) -> Void) {
    completion([])
  }
}
private final class FarmFlowPools: PoolsServiceInputProtocol {
  var pool: PoolInfo?
  var holdLoads = false
  var pendingLoads: [CheckedContinuation<PoolInfo?, Never>?] = []
  func release(_ index: Int, with pool: PoolInfo?) {
    let pending = pendingLoads[index]
    pendingLoads[index] = nil
    pending?.resume(returning: pool)
  }
  func loadAccountPools() {}
  func getAccountPools() -> [PoolInfo] { pool.map { [$0] } ?? [] }
  func updatePools(_ pools: [PoolInfo]) {}
  func getPool(by: String) -> PoolInfo? { pool }
  func getPool(by: String, targetAssetId: String) async -> PoolInfo? { pool }
  func loadPool(by: String, targetAssetId: String) async -> PoolInfo? {
    if holdLoads { return await withCheckedContinuation { pendingLoads.append($0) } }
    return pool
  }
  func loadPairState(baseAssetId: String, targetAssetId: String) async throws -> PoolNetworkState {
    PoolNetworkState(isPresented: true, isEnabled: true)
  }
  func loadPools(currentAsset: AssetInfo) -> [PoolInfo] { [] }
  func loadTargetPools(for: String) -> [PoolInfo] { [] }
  func appendDelegate(delegate: PoolsServiceOutput) {}
}
private final class FarmFlowMarket: MarketCapServiceProtocol {
  func getMarketCap(for assets: [String]) async -> Set<MarketCapInfo> { [] }
}
private final class FarmFlowView: UIViewController, FarmDetailsViewProtocol {
  var alerts: [UIViewController] = []
  override func present(
    _ viewControllerToPresent: UIViewController, animated flag: Bool,
    completion: (() -> Void)? = nil
  ) {
    alerts.append(viewControllerToPresent)
    completion?()
  }
}
private final class FarmFlowRoute: FarmDetailsWireframeProtocol {
  var claims: [(Farm, PoolInfo?)] = [], edits: [PoolInfo] = [], supplies: [PoolInfo] = []
  func showPoolDetails(
    on controller: UIViewController?, poolInfo: PoolInfo?, fiatService: FiatServiceProtocol?,
    poolsService: PoolsServiceInputProtocol?, providerFactory: BalanceProviderFactory,
    operationFactory: WalletNetworkOperationFactoryProtocol?,
    assetsProvider: AssetProviderProtocol?, marketCapService: MarketCapServiceProtocol,
    farmingService: DemeterFarmingServiceProtocol
  ) { if let poolInfo { supplies.append(poolInfo) } }
  func showStakeDetails(
    on controller: UIViewController?, farm: Farm, poolInfo: PoolInfo?,
    assetsProvider: AssetProviderProtocol?, detailsFactory: DetailViewModelFactoryProtocol
  ) { if let poolInfo { edits.append(poolInfo) } }
  func showClaimRewards(
    on controller: UIViewController?, farm: Farm, poolInfo: PoolInfo?,
    fiatService: FiatServiceProtocol?, assetsProvider: AssetProviderProtocol?,
    detailsFactory: DetailViewModelFactoryProtocol
  ) { claims.append((farm, poolInfo)) }
}
