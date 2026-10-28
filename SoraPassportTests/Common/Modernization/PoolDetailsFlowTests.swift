// SPDX-License-Identifier: BSD-4-Clause
import Combine
import RobinHood
import SoraFoundation
import SoraUIKit
import UIKit
import XCTest

@testable import SoraPassport

@MainActor final class PoolDetailsFlowTests: XCTestCase {
  private let assets = DetailFlowAssets()
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
  private func farm(reward: Int = 0, base: Int = 0, target: Int = 1, apr: Decimal = 12) -> Farm {
    let b = assets.assets[base]
    let t = assets.assets[target]
    let r = assets.assets[reward]
    return Farm(
      id: "\(b.assetId)-\(t.assetId)-\(r.assetId)", name: "XOR-VAL", baseAsset: b, poolAsset: t,
      rewardAsset: r, tvl: 100, apr: apr, depositFee: 0)
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
  private func pool(farms: [UserFarm] = [], balance: Decimal? = 100, amount: Decimal? = 20)
    -> PoolInfo
  {
    PoolInfo(
      baseAssetId: assets.assets[0].assetId, targetAssetId: assets.assets[1].assetId,
      poolId: "pool", accountId: "fixture", baseAssetPooledByAccount: amount, targetAssetPooledByAccount: amount,
      accountPoolBalance: balance, farms: farms)
  }
  private struct Fixture {
    let model: PoolDetailsViewModel
    let farms: DetailFlowFarms
    let users: DetailFlowUsers
    let values: DetailFlowValues
    let route: DetailFlowRoute
    let view: DetailFlowView
    let pools: DetailFlowPools
  }
  private func make(farms: [UserFarm] = [], catalog: [Farm]? = nil) -> Fixture {
    let pools = DetailFlowPools()
    pools.pool = pool(farms: farms)
    let service = DetailFlowFarms()
    service.farms = catalog ?? [farm(), farm(reward: 2)]
    let users = DetailFlowUsers()
    let values = DetailFlowValues()
    let route = DetailFlowRoute()
    let view = DetailFlowView()
    let model = PoolDetailsViewModel(
      wireframe: route, poolInfo: pools.pool!, fiatService: DetailFlowFiat(), poolsService: pools,
      assetManager: assets, detailsFactory: DetailViewModelFactory(assetManager: assets),
      farmingService: service, poolDetailsService: values, userFarmService: users)
    model.view = view
    return Fixture(
      model: model, farms: service, users: users, values: values, route: route, view: view,
      pools: pools)
  }
  private func settle() async { try? await Task.sleep(nanoseconds: 40_000_000) }
  private func start(_ f: Fixture) async {
    f.model.viewDidLoad()
    await settle()
  }
  private func details(_ f: Fixture) throws -> PoolDetailsItem {
    for item in f.model.snapshot.itemIdentifiers {
      if case .details(let value) = item { return value }
    }
    throw CancellationError()
  }
  private func lists(_ f: Fixture) -> [FarmListItem] {
    f.model.snapshot.itemIdentifiers.compactMap {
      if case .staked(let value) = $0 { return value }
      return nil
    }
  }
  func testInitialDetailsShowPairAndLiquidity() async throws {
    let f = make()
    await start(f)
    XCTAssertTrue(try details(f).title.contains("XOR-VAL"))
    XCTAssertTrue(try details(f).isThereLiquidity)
    XCTAssertEqual(lists(f).flatMap(\.farmViewModels).count, 2)
    XCTAssertEqual(f.values.pools.last?.poolId, "pool")
  }
  func testCatalogOnlyOffersFarmsForDisplayedPair() async {
    let f = make(catalog: [farm(), farm(base: 1, target: 2)])
    await start(f)
    XCTAssertEqual(lists(f).flatMap(\.farmViewModels).map(\.identifier), [farm().id])
  }
  func testActiveFarmIsNotAlsoOfferedForNewStake() async {
    let f = make(farms: [user()])
    await start(f)
    XCTAssertEqual(lists(f).count, 2)
    XCTAssertEqual(
      lists(f).flatMap(\.farmViewModels).filter { $0.identifier == farm().id }.count, 1)
  }
  func testFirstFarmUpdateIsDisplayed() async {
    let f = make()
    await start(f)
    await f.users.emit([user()])
    await settle()
    XCTAssertTrue(lists(f).contains { $0.farmViewModels.contains { $0.isFarmed } })
    XCTAssertEqual(f.values.pools.last?.farms.first?.rewards, 5)
  }
  func testFarmUpdateFromAnotherPairIsIgnored() async {
    let f = make()
    await start(f)
    await f.users.emit([])
    await f.users.emit([user(base: 1, target: 2)])
    await settle()
    XCTAssertFalse(lists(f).contains { $0.farmViewModels.contains { $0.isFarmed } })
  }
  func testReloadReplacesPreviousSubscription() async {
    let f = make()
    await start(f)
    await start(f)
    XCTAssertEqual(f.users.observer.count, 1)
  }
  func testEmissionDuringSubscribeIsNotLost() async {
    let f = make()
    await f.users.setImmediate([user()])
    await start(f)
    XCTAssertTrue(lists(f).contains { $0.farmViewModels.contains { $0.isFarmed } })
  }
  func testReappearingPoolClearsDeletionState() async {
    let f = make()
    await start(f)
    var count = 0
    f.model.dismiss = { count += 1 }
    f.model.loaded(pools: [])
    XCTAssertEqual(count, 1)
    f.model.loaded(pools: [pool()])
    f.model.dismissIfNeeded()
    XCTAssertEqual(count, 1)
  }
  func testDeletedPoolDismissesScreen() {
    let f = make()
    var count = 0
    f.model.dismiss = { count += 1 }
    f.model.loaded(pools: [])
    XCTAssertEqual(count, 1)
  }
  func testDismissHandlerRunsOnce() {
    let f = make()
    var count = 0
    f.model.dismissHandler = { count += 1 }
    f.model.dismissed()
    XCTAssertEqual(count, 1)
  }
  func testPoolRefreshUpdatesValuesAndRewards() async {
    let f = make()
    await start(f)
    f.model.loaded(pools: [pool(farms: [user(rewards: 7)])])
    XCTAssertTrue(lists(f).first?.farmViewModels.first?.subtitle.contains("7 XOR") == true)
    XCTAssertEqual(f.values.pools.last?.farms.first?.rewards, 7)
  }
  func testMissingCatalogKeepsOwnedFarm() async {
    let f = make(farms: [user()], catalog: [])
    await start(f)
    XCTAssertEqual(lists(f).first?.farmViewModels.count, 1)
  }
  func testCatalogErrorPreservesLiquidity() async throws {
    let f = make(farms: [user()])
    f.farms.fail = true
    await start(f)
    XCTAssertTrue(try details(f).isThereLiquidity)
    XCTAssertEqual(lists(f).first?.farmViewModels.count, 1)
  }
  func testActiveFarmTapUsesMatchingCatalogEntry() async throws {
    let f = make(farms: [user()])
    await start(f)
    try XCTUnwrap(lists(f).first).tapHandler?(farm().id)
    XCTAssertEqual(f.route.shownFarms.map(\.id), [farm().id])
  }
  func testOfferedFarmTapUsesOwnReward() async throws {
    let f = make()
    await start(f)
    try XCTUnwrap(lists(f).first).tapHandler?(farm(reward: 2).id)
    XCTAssertEqual(f.route.shownFarms.first?.rewardAsset?.assetId, assets.assets[2].assetId)
  }
  func testUnknownFarmTapDoesNotNavigate() async throws {
    let f = make()
    await start(f)
    try XCTUnwrap(lists(f).first).tapHandler?("missing")
    XCTAssertTrue(f.route.shownFarms.isEmpty)
  }
  func testLiquidityActionUsesCurrentPool() async throws {
    let f = make()
    await start(f)
    f.model.loaded(pools: [pool(farms: [user(rewards: 8)])])
    try details(f).handler?(.withdraw)
    XCTAssertEqual(f.route.liquidity, [.withdraw])
    XCTAssertEqual(f.route.latestPool?.farms.first?.rewards, 8)
  }
  func testApyExplanationUsesPresenter() {
    let f = make()
    f.model.apyInfoButtonTapped()
    XCTAssertEqual(f.view.alerts.count, 1)
  }
  private func factoryItem(_ p: PoolInfo, _ farms: [UserFarm]) -> PoolDetailsItem {
    PoolDetailsItemFactory().createPoolDetailsItem(
      with: assets, poolInfo: p, detailsFactory: DetailViewModelFactory(assetManager: assets),
      viewModel: nil, farms: farms, service: DetailFlowValues())
  }
  func testFullyStakedLiquidityCannotBeRemoved() {
    XCTAssertFalse(factoryItem(pool(), [user(tokens: 100)]).isRemoveLiquidityEnabled)
  }
  func testPartialStakeAllowsUnstakedRemoval() {
    XCTAssertTrue(factoryItem(pool(), [user(tokens: 20)]).isRemoveLiquidityEnabled)
  }
  func testOverreportedStakeCannotEnableRemoval() {
    XCTAssertFalse(factoryItem(pool(), [user(tokens: 101)]).isRemoveLiquidityEnabled)
  }
  func testMissingPoolBalanceCannotEnableRemoval() {
    XCTAssertFalse(factoryItem(pool(balance: nil), [user()]).isRemoveLiquidityEnabled)
  }
  func testZeroPoolBalanceCannotEnableRemoval() {
    XCTAssertFalse(factoryItem(pool(balance: 0), []).isRemoveLiquidityEnabled)
  }
  func testZeroUnderlyingAmountsAreNotLiquidity() {
    XCTAssertFalse(factoryItem(pool(amount: 0), []).isThereLiquidity)
  }
  func testUnknownUnderlyingAmountsAreNotLiquidity() {
    XCTAssertFalse(factoryItem(pool(amount: nil), []).isThereLiquidity)
  }
  func testActiveAprMatchesAllAssets() {
    let rows = PoolDetailsItemFactory().farmsItem(
      with: assets, poolInfo: pool(farms: [user()]),
      farms: [farm(base: 1, target: 2, apr: 99), farm(apr: 12)])
    XCTAssertEqual(rows.first?.aprText, farm(apr: 12).aprText(suffix: "% APR"))
  }
  func testActivePercentageUsesStakeShare() {
    let rows = PoolDetailsItemFactory().farmsItem(
      with: assets, poolInfo: pool(farms: [user(tokens: 25)]), farms: [farm()])
    XCTAssertEqual(rows.first?.percentageText, "25%")
    XCTAssertTrue(rows.first?.subtitle.contains("5 XOR") == true)
  }
  func testOfferedRowShowsCatalogValues() {
    let rows = PoolDetailsItemFactory().farmsItem(with: [farm()])
    XCTAssertEqual(rows.first?.aprText, farm().aprText(suffix: "% APR"))
    XCTAssertFalse(rows.first!.isFarmed)
  }
  func testControllerRendersDetailsSpacerAndFarms() async throws {
    let f = make()
    let screen = PoolDetailsViewController(viewModel: f.model)
    screen.viewModel = f.model
    f.model.view = screen
    screen.loadViewIfNeeded()
    await settle()
    let table = try XCTUnwrap(descendants(UITableView.self, screen.view).first)
    XCTAssertEqual(table.numberOfSections, 1)
    XCTAssertEqual(table.numberOfRows(inSection: 0), 3)
    for i in 0..<3 {
      XCTAssertNotNil(
        table.dataSource?.tableView(table, cellForRowAt: IndexPath(row: i, section: 0)))
    }
  }
  private func descendants<T: UIView>(_ type: T.Type, _ view: UIView) -> [T] {
    ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { descendants(type, $0) }
  }
}
private final class DetailFlowAssets: AssetManagerProtocol {
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
private actor DetailFlowFiat: FiatServiceProtocol {
  func getFiat() async -> [PIExactFiatData] { [] }
}
private final class DetailFlowValues: PoolDetailsItemServiceProtocol {
  @Published var tvl = ""
  @Published var unavailable = false
  @Published var details: [DetailViewModel] = []
  var pools: [PoolInfo] = []
  var tvlTextPublisher: Published<String>.Publisher { $tvl }
  var tvlUnavailablePublisher: Published<Bool>.Publisher { $unavailable }
  var detailsPublisher: Published<[DetailViewModel]>.Publisher { $details }
  func setup(with poolInfo: PoolInfo) { pools.append(poolInfo) }
}
private final class DetailFlowObserver {
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
private actor DetailFlowUsers: UserFarmsServiceProtocol {
  let subject = PassthroughSubject<[UserFarm], Never>()
  nonisolated let observer = DetailFlowObserver()
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
private final class DetailFlowFarms: DemeterFarmingServiceProtocol {
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
private final class DetailFlowPools: PoolsServiceInputProtocol {
  var pool: PoolInfo?
  func loadAccountPools() {}
  func getAccountPools() -> [PoolInfo] { pool.map { [$0] } ?? [] }
  func updatePools(_ pools: [PoolInfo]) {}
  func getPool(by: String) -> PoolInfo? { pool }
  func getPool(by: String, targetAssetId: String) async -> PoolInfo? { pool }
  func loadPool(by: String, targetAssetId: String) async -> PoolInfo? { pool }
  func loadPairState(baseAssetId: String, targetAssetId: String) async throws -> PoolNetworkState {
    PoolNetworkState(isPresented: true, isEnabled: true)
  }
  func loadPools(currentAsset: AssetInfo) -> [PoolInfo] { [] }
  func loadTargetPools(for: String) -> [PoolInfo] { [] }
  func appendDelegate(delegate: PoolsServiceOutput) {}
}
private final class DetailFlowView: UIViewController, PoolDetailsViewProtocol {
  var alerts: [UIViewController] = []
  override func present(
    _ viewControllerToPresent: UIViewController, animated flag: Bool,
    completion: (() -> Void)? = nil
  ) {
    alerts.append(viewControllerToPresent)
    completion?()
  }
}
private final class DetailFlowRoute: PoolDetailsWireframeProtocol {
  var shownFarms: [Farm] = [], liquidity: [Liquidity.TransactionLiquidityType] = []
  var latestPool: PoolInfo?
  func showLiquidity(
    on controller: UIViewController?, poolInfo: PoolInfo, farms: [UserFarm],
    type: Liquidity.TransactionLiquidityType, assetManager: AssetManagerProtocol,
    poolsService: PoolsServiceInputProtocol?, fiatService: FiatServiceProtocol?,
    farmingService: DemeterFarmingServiceProtocol, completionHandler: (() -> Void)?
  ) {
    liquidity.append(type)
    latestPool = poolInfo
  }
  func showFarmDetails(
    on viewController: UIViewController?, poolsService: PoolsServiceInputProtocol?,
    fiatService: FiatServiceProtocol?, assetManager: AssetManagerProtocol,
    farmingService: DemeterFarmingServiceProtocol, poolInfo: PoolInfo?, farm: Farm
  ) { shownFarms.append(farm) }
}
