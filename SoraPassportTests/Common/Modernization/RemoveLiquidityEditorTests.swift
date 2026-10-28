// SPDX-License-Identifier: Apache-2.0
import Foundation
import RobinHood
import SoraFoundation
import SoraUIKit
import UIKit
import XCTest

@testable import SoraPassport

@MainActor final class RemoveLiquidityEditorTests: XCTestCase {
  private var fixtures = [RemovalEditorFixture]()
  private func make() -> RemovalEditorFixture {
    let f = RemovalEditorFixture()
    fixtures.append(f)
    return f
  }
  private func wait(_ condition: () -> Bool) async {
    for _ in 0..<150 {
      if condition() { return }
      try? await Task.sleep(nanoseconds: 5_000_000)
    }
    XCTAssertTrue(condition())
  }
  private func ready(_ f: RemovalEditorFixture) async {
    f.model.viewDidLoad()
    await wait { f.model.poolInfo != nil }
    f.model.inputedFirstAmount = 2
    f.model.inputedSecondAmount = 4
    f.model.updateDetails()
    await wait { f.view.enabled }
  }
  override func tearDown() {
    fixtures = []
    super.tearDown()
  }
  func testLoadUsesTheExactPoolPair() async {
    let f = make()
    await ready(f)
    XCTAssertEqual(f.model.firstAssetId, f.xor)
    XCTAssertEqual(f.model.secondAssetId, f.val)
    XCTAssertEqual(f.balances.additions, 1)
    XCTAssertEqual(f.view.focused, .one)
  }
  func testEmptyEditorCannotOpenConfirmation() {
    let f = make()
    f.model.reviewButtonTapped()
    XCTAssertTrue(f.routes.removalReviews.isEmpty)
  }
  func testReviewCarriesExactRemovalAmountsAndFee() async {
    let f = make()
    await ready(f)
    f.model.reviewButtonTapped()
    XCTAssertEqual(f.routes.removalReviews.first?.0, f.xor)
    XCTAssertEqual(f.routes.removalReviews.first?.1, f.val)
    XCTAssertEqual(f.routes.removalReviews.first?.2, 2)
    XCTAssertEqual(f.routes.removalReviews.first?.3, 4)
    XCTAssertEqual(f.routes.removalReviews.first?.4, 1)
  }
  func testReviewChecksTheCurrentFeeBalance() async {
    let f = make()
    await ready(f)
    f.balances.values[f.xor] = 0
    f.model.reviewButtonTapped()
    XCTAssertTrue(f.routes.removalReviews.isEmpty)
  }
  func testMissingFeeBalanceClearsTheOldWalletValue() async {
    let f = make()
    await ready(f)
    f.balances.values.removeValue(forKey: f.xor)
    f.model.processBalance(data: [])
    XCTAssertEqual(f.model.firstAssetBalance.balance.decimalValue, 0)
    XCTAssertFalse(f.view.enabled)
  }
  func testMissingTargetBalanceClearsTheOldWalletValue() async {
    let f = make()
    await ready(f)
    f.balances.values.removeValue(forKey: f.val)
    f.model.processBalance(data: [])
    XCTAssertEqual(f.model.secondAssetBalance.balance.decimalValue, 0)
  }
  func testRemovalDoesNotRequireTokenBalanceOutsideThePool() async {
    let f = make()
    await ready(f)
    f.balances.values[f.val] = 0
    f.model.processBalance(data: [])
    f.model.reviewButtonTapped()
    XCTAssertEqual(f.routes.removalReviews.count, 1)
  }
  func testZeroAmountBlocksReview() async {
    let f = make()
    await ready(f)
    f.model.inputedFirstAmount = 0
    f.model.reviewButtonTapped()
    XCTAssertTrue(f.routes.removalReviews.isEmpty)
  }
  func testNegativeAmountBlocksReview() async {
    let f = make()
    await ready(f)
    f.model.inputedSecondAmount = -1
    f.model.reviewButtonTapped()
    XCTAssertTrue(f.routes.removalReviews.isEmpty)
  }
  func testPairChangeInvalidatesReviewImmediately() async {
    let f = make()
    await ready(f)
    f.model.secondAssetId = f.xor
    f.model.reviewButtonTapped()
    XCTAssertTrue(f.routes.removalReviews.isEmpty)
  }
  func testSlippageChangeInvalidatesReviewImmediately() async {
    let f = make()
    await ready(f)
    f.model.slippageTolerance = .defaultValue
    f.model.reviewButtonTapped()
    XCTAssertTrue(f.routes.removalReviews.isEmpty)
  }
  func testInputAmountClampsToTheAccountPoolShare() async {
    let f = make()
    await ready(f)
    f.model.inputedFirstAmount = 500
    XCTAssertEqual(f.model.inputedFirstAmount, 50)
  }
  func testOutputAmountClampsToTheAccountPoolShare() async {
    let f = make()
    await ready(f)
    f.model.inputedSecondAmount = 500
    XCTAssertEqual(f.model.inputedSecondAmount, 100)
  }
  func testHalfInputUsesTheAccountShareAndPoolRatio() async {
    let f = make()
    await ready(f)
    f.model.focusedField = .one
    f.model.didSelect(variant: 0.5)
    XCTAssertEqual(f.model.inputedFirstAmount, 25)
    XCTAssertEqual(f.model.inputedSecondAmount, 50)
  }
  func testHalfOutputUsesTheAccountShareAndPoolRatio() async {
    let f = make()
    await ready(f)
    f.model.focusedField = .two
    f.model.didSelect(variant: 0.5)
    XCTAssertEqual(f.model.inputedSecondAmount, 50)
    XCTAssertEqual(f.model.inputedFirstAmount, 25)
  }
  func testRecalculationUsesTheFocusedInputRatio() async {
    let f = make()
    await ready(f)
    f.model.inputedFirstAmount = 3
    f.model.focusedField = .one
    f.model.recalculate(field: .one)
    XCTAssertEqual(f.model.inputedSecondAmount, 6)
  }
  func testRecalculationUsesTheFocusedOutputRatio() async {
    let f = make()
    await ready(f)
    f.model.inputedSecondAmount = 8
    f.model.focusedField = .two
    f.model.recalculate(field: .two)
    XCTAssertEqual(f.model.inputedFirstAmount, 4)
  }
  func testMissingPoolClearsAmountsInsteadOfKeepingAQuote() async {
    let f = make()
    await ready(f)
    f.model.poolInfo = nil
    f.model.recalculate(field: .one)
    XCTAssertEqual(f.model.inputedFirstAmount, 0)
    XCTAssertEqual(f.model.inputedSecondAmount, 0)
    XCTAssertFalse(f.view.enabled)
  }
  func testZeroPoolReservesClearAmounts() async {
    let f = make()
    await ready(f)
    var pool = RemovalEditorFixture.pool()
    pool.baseAssetPooledTotal = 0
    f.model.poolInfo = pool
    f.model.recalculate(field: .one)
    XCTAssertEqual(f.model.inputedFirstAmount, 0)
    XCTAssertEqual(f.model.inputedSecondAmount, 0)
  }
  func testStakedShareIsExcludedFromRemoval() async {
    let f = make()
    f.pools.pool = RemovalEditorFixture.pool(staked: 2)
    await ready(f)
    f.model.didSelect(variant: 1)
    XCTAssertEqual(f.model.inputedFirstAmount, 30)
    XCTAssertEqual(f.model.inputedSecondAmount, 60)
  }
  func testOverstakedShareNeverBecomesNegative() async {
    let f = make()
    f.pools.pool = RemovalEditorFixture.pool(staked: 10)
    f.model.viewDidLoad()
    await wait { f.model.poolInfo != nil }
    f.model.didSelect(variant: 1)
    XCTAssertEqual(f.model.inputedFirstAmount, 0)
    XCTAssertEqual(f.model.inputedSecondAmount, 0)
    XCTAssertFalse(f.view.enabled)
  }
  func testPoolReadFailureLeavesReviewDisabled() async {
    let f = make()
    f.pools.error = NSError(domain: "fixture", code: 1)
    f.model.viewDidLoad()
    await wait { !f.pools.pairQueries.isEmpty }
    f.model.reviewButtonTapped()
    XCTAssertTrue(f.routes.removalReviews.isEmpty)
    XCTAssertFalse(f.view.enabled)
  }
  func testWrongPairFromPoolReadCannotBeReviewed() async {
    let f = make()
    f.pools.pool = RemovalEditorFixture.pool(base: WalletAssetId.xstusd.rawValue)
    f.model.viewDidLoad()
    await wait { f.pools.poolQueries > 0 }
    XCTAssertNil(f.model.poolInfo)
    f.model.reviewButtonTapped()
    XCTAssertTrue(f.routes.removalReviews.isEmpty)
  }
  func testFeeFailureKeepsReviewDisabled() async {
    let f = make()
    f.network.liquidityFeeClosure = { _ in throw NSError(domain: "fixture", code: 1) }
    f.model.viewDidLoad()
    await wait { f.model.poolInfo != nil }
    f.model.inputedFirstAmount = 2
    f.model.inputedSecondAmount = 4
    f.model.updateDetails()
    try? await Task.sleep(nanoseconds: 30_000_000)
    f.model.reviewButtonTapped()
    XCTAssertFalse(f.view.enabled)
    XCTAssertTrue(f.routes.removalReviews.isEmpty)
  }
  func testBasePickerListsSupportedBaseAssets() {
    let f = make()
    f.model.choiсeBaseAssetButtonTapped()
    XCTAssertEqual(f.routes.assetLists.first, [f.xor, WalletAssetId.xstusd.rawValue])
  }
  func testBasePickerAppliesTheChosenIdentifier() {
    let f = make()
    f.model.choiсeBaseAssetButtonTapped()
    f.routes.assetCompletion?(WalletAssetId.xstusd.rawValue)
    XCTAssertEqual(f.model.firstAssetId, WalletAssetId.xstusd.rawValue)
  }
  func testTargetPickerAppliesTheChosenIdentifier() {
    let f = make()
    f.model.choiсeTargetAssetButtonTapped()
    f.routes.assetCompletion?(f.val)
    XCTAssertEqual(f.model.secondAssetId, f.val)
  }
  func testBalanceTextDoesNotInventAMissingPrice() {
    let f = make()
    var shown = ""
    f.model.setupFullBalanceText(from: .init(identifier: f.xor, balance: .init(value: 3))) {
      shown = $0
    }
    XCTAssertEqual(shown, "3")
  }
  func testKnownAssetWithoutPriceUsesEmptyFiatText() {
    let f = make()
    var shown = "pending"
    f.model.setupInputedFiatText(from: 3, assetId: f.xor) { shown = $0 }
    XCTAssertEqual(shown, "")
  }
  func testRemovalPresentationUsesTheLiquidityControls() {
    let f = make()
    XCTAssertFalse(f.model.isSwap)
    XCTAssertNotNil(f.model.title)
    XCTAssertNil(f.model.imageName)
    XCTAssertNotNil(f.model.actionButtonImage)
  }
}
@MainActor private final class RemovalEditorFixture {
  let xor = WalletAssetId.xor.rawValue, val = WalletAssetId.val.rawValue
  let assets = RemovalEditorAssets(), balances = RemovalEditorBalances(),
    routes = RemovalEditorRoutes(), view = RemovalEditorView(), fiat = RemovalEditorFiat(),
    market = RemovalEditorMarket(), pools = RemovalEditorPools(),
    network = WalletNetworkOperationFactoryProtocolMock(), farms = RemovalEditorFarms()
  lazy var model: RemoveLiquidityViewModel = {
    let m = RemoveLiquidityViewModel(
      wireframe: routes, poolInfo: Self.pool(), farms: [], apyService: nil, fiatService: fiat,
      poolsService: pools, assetManager: assets,
      detailsFactory: DetailViewModelFactory(assetManager: assets),
      providerFactory: BalanceProviderFactory(
        accountId: "fixture", cacheFacade: CoreDataCacheFacade.shared,
        networkOperationFactory: network, identifierFactory: SingleProviderIdentifierFactory()),
      operationFactory: network, assetsProvider: balances, farmingService: farms,
      marketCapService: market)
    m.view = view
    return m
  }()
  init() {
    pools.pool = Self.pool()
    network.liquidityFeeClosure = { _ in 1 }
  }
  static func pool(base: String = WalletAssetId.xor.rawValue, staked: Decimal? = nil) -> PoolInfo {
    .init(
      baseAssetId: base, targetAssetId: WalletAssetId.val.rawValue, poolId: "public-pool",
      accountId: "public-account", baseAssetPooledByAccount: 50, targetAssetPooledByAccount: 100,
      baseAssetPooledTotal: 100, targetAssetPooledTotal: 200, totalIssuances: 10,
      baseAssetReserves: 100, targetAssetReserves: 200, accountPoolBalance: 5,
      farms: staked.map {
        [
          UserFarm(
            id: "farm", baseAssetId: base, poolAssetId: WalletAssetId.val.rawValue,
            rewardAssetId: WalletAssetId.pswap.rawValue, isFarm: true, pooledTokens: $0)
        ]
      } ?? [])
  }
}
private final class RemovalEditorBalances: AssetProviderProtocol {
  var values: [String: Decimal] = [
    WalletAssetId.xor.rawValue: 10, WalletAssetId.val.rawValue: 20,
    WalletAssetId.pswap.rawValue: 30,
  ]
  var additions = 0
  func getBalances(with assetIds: [String]) -> [BalanceData] {
    assetIds.compactMap { id in
      values[id].map { BalanceData(identifier: id, balance: AmountDecimal(value: $0)) }
    }
  }
  func add(observer: AssetProviderObserverProtocol) { additions += 1 }
  func remove(observer: AssetProviderObserverProtocol) {}
}

private actor RemovalEditorFiat: FiatServiceProtocol {
  func getFiat() async -> [PIExactFiatData] { [] }
}
private final class RemovalEditorMarket: MarketCapServiceProtocol {
  func getMarketCap(for assets: [String]) async -> Set<MarketCapInfo> { [] }
}

private final class RemovalEditorView: UIViewController, LiquidityViewProtocol {
  var firstText = "", secondText = "", enabled = false, marketLoading = false,
    focused: FocusedField?
  func update(details: [DetailViewModel]) {}
  func updateFirstAsset(balance: String) {}
  func updateSecondAsset(balance: String) {}
  func updateFirstAsset(symbol: String, image: UIImage?) {}
  func updateSecondAsset(symbol: String, image: UIImage?) {}
  func updateFirstAsset(fiatText: String) {}
  func updateSecondAsset(fiatText: String) {}
  func updateFirstAsset(
    state: InputFieldState, amountColor: SoramitsuColor, fiatColor: SoramitsuColor
  ) {}
  func updateSecondAsset(
    state: InputFieldState, amountColor: SoramitsuColor, fiatColor: SoramitsuColor
  ) {}
  func update(slippageTolerance: String) {}
  func update(selectedMarket: String) {}
  func updateMiddleButton(isEnabled: Bool) {}
  func set(firstAmountText: String) { firstText = firstAmountText }
  func set(secondAmountText: String) { secondText = secondAmountText }
  func setupButton(isEnabled: Bool) { enabled = isEnabled }
  func setAccessoryView(isHidden: Bool) {}
  func setupMarketButton(isLoadingState: Bool) { marketLoading = isLoadingState }
  func focus(field: FocusedField) { focused = field }
  func update(isNeedLoadingState: Bool) {}
  func updateReviewButton(title: String) {}
  func updateFirstLiquidityWarinignView(model: WarningViewModel) {}
  func updateWarinignView(model: WarningViewModel) {}
}

private final class RemovalEditorRoutes: LiquidityWireframeProtocol {
  var assetLists = [[String]](), assetCompletion: ((String) -> Void)?,
    reviews = [(String, String, Decimal, Decimal, Decimal)](),
    supplyReviews = [(String, String, Decimal, Decimal, Decimal)](),
    removalReviews = [(String, String, Decimal, Decimal, Decimal)]()
  func showChoiсeBaseAsset(
    on controller: UIViewController?,
    assetManager: AssetManagerProtocol,
    fiatService: FiatServiceProtocol,
    assetViewModelFactory: AssetViewModelFactory,
    assetsProvider: AssetProviderProtocol?,
    assetIds: [String],
    marketCapService: MarketCapServiceProtocol,
    completion: @escaping (String) -> Void
  ) {
    assetLists.append(assetIds)
    assetCompletion = completion
  }

  func showSlippageTolerance(
    on controller: UINavigationController?,
    currentLocale: PolkaswapSlippage,
    completion: @escaping (PolkaswapSlippage) -> Void
  ) {}

  func showChoiсeMarket(
    on controller: UINavigationController?,
    selectedMarket: LiquiditySourceType,
    markets: [LiquiditySourceType],
    completion: @escaping (LiquiditySourceType) -> Void
  ) {}

  func showSupplyLiquidityConfirmation(
    on controller: UINavigationController?,
    baseAssetId: String,
    targetAssetId: String,
    fiatService: FiatServiceProtocol,
    poolsService: PoolsServiceInputProtocol,
    assetManager: AssetManagerProtocol,
    firstAssetAmount: Decimal,
    secondAssetAmount: Decimal,
    slippageTolerance: PolkaswapSlippage,
    details: [DetailViewModel],
    transactionType: TransactionType,
    fee: Decimal,
    operationFactory: WalletNetworkOperationFactoryProtocol,
    feeChangeHandler: @escaping () -> Void
  ) { supplyReviews.append((baseAssetId, targetAssetId, firstAssetAmount, secondAssetAmount, fee)) }

  func showRemoveLiquidityConfirmation(
    on controller: UINavigationController?,
    poolInfo: PoolInfo,
    poolsService: PoolsServiceInputProtocol,
    assetManager: AssetManagerProtocol,
    firstAssetAmount: Decimal,
    secondAssetAmount: Decimal,
    slippageTolerance: PolkaswapSlippage,
    details: [DetailViewModel],
    fee: Decimal,
    operationFactory: WalletNetworkOperationFactoryProtocol,
    feeChangeHandler: @escaping () -> Void,
    completionHandler: (() -> Void)?
  ) {
    removalReviews.append(
      (poolInfo.baseAssetId, poolInfo.targetAssetId, firstAssetAmount, secondAssetAmount, fee))
  }

  func showSwapConfirmation(
    on controller: UINavigationController?,
    baseAssetId: String,
    targetAssetId: String,
    assetManager: AssetManagerProtocol,
    eventCenter: EventCenterProtocol,
    firstAssetAmount: Decimal,
    secondAssetAmount: Decimal,
    slippageTolerance: PolkaswapSlippage,
    market: LiquiditySourceType,
    details: [DetailViewModel],
    amounts: SwapQuoteAmounts,
    fee: Decimal,
    swapVariant: SwapVariant,
    networkFacade: WalletNetworkOperationFactoryProtocol?,
    minMaxValue: Decimal,
    dexId: UInt32,
    quoteParams: PolkaswapMainInteractorQuoteParams,
    assetsProvider: AssetProviderProtocol?,
    fiatData: [PIExactFiatData],
    polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol?
  ) { reviews.append((baseAssetId, targetAssetId, firstAssetAmount, secondAssetAmount, fee)) }
}

private final class RemovalEditorPools: PoolsServiceInputProtocol {
  var pool: PoolInfo?
  var state = PoolNetworkState(isPresented: true, isEnabled: true)
  var pairQueries: [[String]] = []
  var poolQueries = 0
  var error: Error?
  func loadPairState(baseAssetId: String, targetAssetId: String) async throws -> PoolNetworkState {
    pairQueries.append([baseAssetId, targetAssetId])
    if let error { throw error }
    return state
  }
  func loadPool(by baseAssetId: String, targetAssetId: String) async -> PoolInfo? {
    poolQueries += 1
    return pool
  }
  func getPool(by baseAssetId: String, targetAssetId: String) async -> PoolInfo? { pool }
  func getPool(by id: String) -> PoolInfo? { pool }
  func getAccountPools() -> [PoolInfo] { pool.map { [$0] } ?? [] }
  func loadAccountPools() {}
  func updatePools(_ pools: [PoolInfo]) {}
  func loadPools(currentAsset: AssetInfo) -> [PoolInfo] { getAccountPools() }
  func loadTargetPools(for baseAssetId: String) -> [PoolInfo] { getAccountPools() }
  func appendDelegate(delegate: PoolsServiceOutput) {}
}
private final class RemovalEditorAssets: AssetManagerProtocol {
  static var networkAssets: [AssetInfo] = []
  let assets = [
    (WalletAssetId.xor.rawValue, "XOR"), (WalletAssetId.val.rawValue, "VAL"),
    (WalletAssetId.kxor, "KXOR"),
    (WalletAssetId.xstusd.rawValue, "XSTUSD"),
  ].map {
    AssetInfo(
      id: $0.0, symbol: $0.1, chainId: "", precision: 18, icon: nil, displayName: $0.1,
      visible: true)
  }
  func assetInfo(for identifier: String) -> AssetInfo? {
    assets.first { $0.identifier == identifier }
  }
  func getAssetList() -> [AssetInfo]? { assets }
  func updateAssetList(_ list: [AssetInfo]) {}
  func saveAssetList(_ list: [AssetInfo]) {}
  func sortedAssets(_ list: [WalletAsset], onlyVisible: Bool) -> [WalletAsset] { list }
  func visibleCount() -> UInt { UInt(assets.count) }
  func setup(for accountSettings: SelectedWalletSettings) {}
}

private final class RemovalEditorFarms: DemeterFarmingServiceProtocol {
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
