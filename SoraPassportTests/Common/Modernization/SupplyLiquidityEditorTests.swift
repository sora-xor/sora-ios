// SPDX-License-Identifier: Apache-2.0
import Foundation
import RobinHood
import SoraFoundation
import SoraUIKit
import UIKit
import XCTest

@testable import SoraPassport

@MainActor final class SupplyLiquidityEditorTests: XCTestCase {
  private var fixtures = [SupplyEditorFixture]()
  private func make() -> SupplyEditorFixture {
    let f = SupplyEditorFixture()
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
  private func ready(_ f: SupplyEditorFixture) async {
    f.model.viewDidLoad()
    await wait { f.model.poolInfo != nil }
    f.model.inputedFirstAmount = 2
    f.model.inputedSecondAmount = 4
    let done = expectation(description: "supply fee details")
    f.model.updateDetails { done.fulfill() }
    await fulfillment(of: [done], timeout: 1)
  }
  override func tearDown() {
    fixtures = []
    super.tearDown()
  }
  func testFirstLoadSelectsThePoolsExactPair() async {
    let f = make()
    f.model.viewDidLoad()
    await wait { f.model.poolInfo != nil }
    XCTAssertEqual(f.model.firstAssetId, f.xor)
    XCTAssertEqual(f.model.secondAssetId, f.val)
    XCTAssertEqual(f.view.focused, .one)
    XCTAssertEqual(f.balances.additions, 1)
  }
  func testEmptyEditorCannotOpenConfirmation() {
    let f = make()
    f.model.reviewButtonTapped()
    XCTAssertTrue(f.routes.supplyReviews.isEmpty)
  }
  func testReadyReviewCarriesExactAmountsAndLiveFee() async {
    let f = make()
    await ready(f)
    f.model.reviewButtonTapped()
    XCTAssertEqual(f.routes.supplyReviews.first?.0, f.xor)
    XCTAssertEqual(f.routes.supplyReviews.first?.1, f.val)
    XCTAssertEqual(f.routes.supplyReviews.first?.2, 2)
    XCTAssertEqual(f.routes.supplyReviews.first?.3, 4)
    XCTAssertEqual(f.routes.supplyReviews.first?.4, 1)
  }
  func testReviewRereadsInputBalanceBeforeOpeningConfirmation() async {
    let f = make()
    await ready(f)
    f.balances.values[f.xor] = 0
    f.model.reviewButtonTapped()
    XCTAssertTrue(f.routes.supplyReviews.isEmpty)
  }
  func testReviewRereadsOutputBalanceBeforeOpeningConfirmation() async {
    let f = make()
    await ready(f)
    f.balances.values[f.val] = 0
    f.model.reviewButtonTapped()
    XCTAssertTrue(f.routes.supplyReviews.isEmpty)
  }
  func testMissingInputBalanceClearsThePreviousWalletAmount() async {
    let f = make()
    await ready(f)
    f.balances.values.removeValue(forKey: f.xor)
    f.model.processBalance(data: [])
    XCTAssertEqual(f.model.firstAssetBalance.balance.decimalValue, 0)
    XCTAssertFalse(f.view.enabled)
  }
  func testMissingOutputBalanceClearsThePreviousWalletAmount() async {
    let f = make()
    await ready(f)
    f.balances.values.removeValue(forKey: f.val)
    f.model.processBalance(data: [])
    XCTAssertEqual(f.model.secondAssetBalance.balance.decimalValue, 0)
    XCTAssertFalse(f.view.enabled)
  }
  func testZeroInputAmountBlocksReview() async {
    let f = make()
    await ready(f)
    f.model.inputedFirstAmount = 0
    f.model.reviewButtonTapped()
    XCTAssertTrue(f.routes.supplyReviews.isEmpty)
  }
  func testNegativeOutputAmountBlocksReview() async {
    let f = make()
    await ready(f)
    f.model.inputedSecondAmount = -1
    f.model.reviewButtonTapped()
    XCTAssertTrue(f.routes.supplyReviews.isEmpty)
  }
  func testInputLargerThanTheBalanceBlocksReview() async {
    let f = make()
    await ready(f)
    f.model.inputedFirstAmount = 100
    f.model.reviewButtonTapped()
    XCTAssertTrue(f.routes.supplyReviews.isEmpty)
  }
  func testOutputLargerThanTheBalanceBlocksReview() async {
    let f = make()
    await ready(f)
    f.model.inputedSecondAmount = 100
    f.model.reviewButtonTapped()
    XCTAssertTrue(f.routes.supplyReviews.isEmpty)
  }
  func testChangingThePairInvalidatesItsExistingReview() async {
    let f = make()
    await ready(f)
    f.model.secondAssetId = f.pswap
    f.model.reviewButtonTapped()
    XCTAssertTrue(f.routes.supplyReviews.isEmpty)
  }
  func testSameAssetPairCannotOpenReview() async {
    let f = make()
    await ready(f)
    f.model.secondAssetId = f.xor
    f.model.reviewButtonTapped()
    XCTAssertTrue(f.routes.supplyReviews.isEmpty)
  }
  func testSlippageChangeInvalidatesTheReviewedFeeImmediately() async {
    let f = make()
    await ready(f)
    f.model.slippageTolerance = .defaultValue
    f.model.reviewButtonTapped()
    XCTAssertTrue(f.routes.supplyReviews.isEmpty)
  }
  func testHalfInputBalanceReservesTheExactNetworkFee() async {
    let f = make()
    await ready(f)
    f.model.focusedField = .one
    f.model.didSelect(variant: Decimal(string: "0.5")!)
    XCTAssertEqual(f.model.inputedFirstAmount, 4)
    XCTAssertEqual(f.model.inputedSecondAmount, 8)
  }
  func testOutputPercentageRecalculatesInputUsingPoolReserves() async {
    let f = make()
    await ready(f)
    f.model.focusedField = .two
    f.model.didSelect(variant: Decimal(string: "0.5")!)
    XCTAssertEqual(f.model.inputedSecondAmount, 10)
    XCTAssertEqual(f.model.inputedFirstAmount, 5)
  }
  func testInputRecalculationMaintainsThePoolRatio() async {
    let f = make()
    await ready(f)
    f.model.inputedFirstAmount = 3
    f.model.focusedField = .one
    f.model.recalculate(field: .one)
    XCTAssertEqual(f.model.inputedSecondAmount, 6)
  }
  func testOutputRecalculationMaintainsThePoolRatio() async {
    let f = make()
    await ready(f)
    f.model.inputedSecondAmount = 8
    f.model.focusedField = .two
    f.model.recalculate(field: .two)
    XCTAssertEqual(f.model.inputedFirstAmount, 4)
  }
  func testZeroInputBalanceDoesNotOverwriteTheEnteredAmount() async {
    let f = make()
    await ready(f)
    f.model.firstAssetBalance = BalanceData(identifier: f.xor, balance: .init(value: 0))
    f.model.inputedFirstAmount = 3
    f.model.didSelect(variant: 1)
    XCTAssertEqual(f.model.inputedFirstAmount, 3)
  }
  func testBasePickerOffersOnlySupportedPoolBaseAssets() {
    let f = make()
    f.model.choiсeBaseAssetButtonTapped()
    XCTAssertEqual(f.routes.assetLists.first, [f.xor, WalletAssetId.xstusd.rawValue])
  }
  func testTargetPickerExcludesBothPoolBaseAssets() {
    let f = make()
    f.model.firstAssetId = f.xor
    f.model.choiсeTargetAssetButtonTapped()
    let ids = f.routes.assetLists.first ?? []
    XCTAssertFalse(ids.contains(f.xor))
    XCTAssertFalse(ids.contains(WalletAssetId.xstusd.rawValue))
    XCTAssertTrue(ids.contains(f.val))
  }
  func testSelectingAnotherBaseUpdatesTheEditor() {
    let f = make()
    f.model.choiсeBaseAssetButtonTapped()
    f.routes.assetCompletion?(WalletAssetId.xstusd.rawValue)
    XCTAssertEqual(f.model.firstAssetId, WalletAssetId.xstusd.rawValue)
  }
  func testSelectingAnotherTargetUpdatesTheEditor() {
    let f = make()
    f.model.choiсeTargetAssetButtonTapped()
    f.routes.assetCompletion?(f.val)
    XCTAssertEqual(f.model.secondAssetId, f.val)
  }
  func testPoolStateFailureKeepsReviewUnavailable() async {
    let f = make()
    f.pools.error = NSError(domain: "fixture", code: 1)
    f.model.viewDidLoad()
    await wait { !f.pools.pairQueries.isEmpty }
    f.model.inputedFirstAmount = 2
    f.model.inputedSecondAmount = 4
    f.model.reviewButtonTapped()
    XCTAssertTrue(f.routes.supplyReviews.isEmpty)
    XCTAssertFalse(f.view.enabled)
  }
  func testMismatchedLivePoolCannotReplaceTheRequestedPair() async {
    let f = make()
    f.pools.pool = SupplyEditorFixture.pool(base: WalletAssetId.xstusd.rawValue)
    f.model.viewDidLoad()
    await wait { f.pools.poolQueries > 0 }
    XCTAssertNil(f.model.poolInfo)
    f.model.reviewButtonTapped()
    XCTAssertTrue(f.routes.supplyReviews.isEmpty)
  }
  func testFeeFailureNeverEnablesReview() async {
    let f = make()
    f.network.liquidityFeeClosure = { _ in throw NSError(domain: "fixture", code: 1) }
    await ready(f)
    f.model.reviewButtonTapped()
    XCTAssertTrue(f.routes.supplyReviews.isEmpty)
    XCTAssertFalse(f.view.enabled)
  }
  func testBalanceTextWithoutPriceStillShowsTheTokenAmount() {
    let f = make()
    var shown = ""
    f.model.setupFullBalanceText(from: .init(identifier: f.xor, balance: .init(value: 3))) {
      shown = $0
    }
    XCTAssertEqual(shown, "3")
  }
  func testUnknownAssetHasNoInventedFiatValue() {
    let f = make()
    XCTAssertEqual(f.model.setupInputedFiatText(from: 1, assetId: "missing"), "")
  }
  func testEditorExposesSupplyRatherThanSwapPresentation() {
    let f = make()
    XCTAssertFalse(f.model.isSwap)
    XCTAssertNotNil(f.model.title)
    XCTAssertNil(f.model.imageName)
    XCTAssertNotNil(f.model.actionButtonImage)
  }
}
@MainActor private final class SupplyEditorFixture {
  let xor = WalletAssetId.xor.rawValue, val = WalletAssetId.val.rawValue,
    pswap = WalletAssetId.pswap.rawValue
  let assets = SupplyEditorAssets(), balances = SupplyEditorBalances(),
    routes = SupplyEditorRoutes(), view = SupplyEditorView(), fiat = SupplyEditorFiat(),
    market = SupplyEditorMarket(), pools = SupplyEditorPools(),
    network = WalletNetworkOperationFactoryProtocolMock()
  lazy var model: SupplyLiquidityViewModel = {
    let m = SupplyLiquidityViewModel(
      wireframe: routes, poolInfo: Self.pool(), fiatService: fiat, apyService: nil,
      poolsService: pools, assetManager: assets,
      detailsFactory: DetailViewModelFactory(assetManager: assets), operationFactory: network,
      assetsProvider: balances, marketCapService: market)
    m.view = view
    return m
  }()
  init() {
    pools.pool = Self.pool()
    network.liquidityFeeClosure = { _ in 1 }
  }
  static func pool(base: String = WalletAssetId.xor.rawValue) -> PoolInfo {
    .init(
      baseAssetId: base, targetAssetId: WalletAssetId.val.rawValue, poolId: "public-pool",
      accountId: "public-account", baseAssetPooledByAccount: 50, targetAssetPooledByAccount: 100,
      baseAssetPooledTotal: 100, targetAssetPooledTotal: 200, totalIssuances: 10,
      baseAssetReserves: 100, targetAssetReserves: 200, accountPoolBalance: 5)
  }
}

private final class SupplyEditorBalances: AssetProviderProtocol {
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

private actor SupplyEditorFiat: FiatServiceProtocol {
  func getFiat() async -> [PIExactFiatData] { [] }
}
private final class SupplyEditorMarket: MarketCapServiceProtocol {
  func getMarketCap(for assets: [String]) async -> Set<MarketCapInfo> { [] }
}

private final class SupplyEditorView: UIViewController, LiquidityViewProtocol {
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

private final class SupplyEditorRoutes: LiquidityWireframeProtocol {
  var assetLists = [[String]](), assetCompletion: ((String) -> Void)?,
    reviews = [(String, String, Decimal, Decimal, Decimal)](),
    supplyReviews = [(String, String, Decimal, Decimal, Decimal)]()
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
  ) {}

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

private final class SupplyEditorPools: PoolsServiceInputProtocol {
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
private final class SupplyEditorAssets: AssetManagerProtocol {
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
