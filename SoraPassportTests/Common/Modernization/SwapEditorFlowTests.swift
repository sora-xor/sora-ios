import Foundation
import SSFUtils
import SoraFoundation
import SoraUIKit
// SPDX-License-Identifier: Apache-2.0
import UIKit
import XCTest

@testable import SoraPassport

@MainActor
final class SwapEditorFlowTests: XCTestCase {
  private var fixtures = [SwapEditorFixture]()
  private func make() -> SwapEditorFixture {
    let f = SwapEditorFixture()
    fixtures.append(f)
    return f
  }
  override func tearDown() {
    fixtures.forEach { $0.fees.releaseAll() }
    fixtures.removeAll()
    super.tearDown()
  }
  private func settle() async { try? await Task.sleep(nanoseconds: 30_000_000) }
  private func ready(_ f: SwapEditorFixture, amount: String = "2000000") async {
    let done = expectation(description: "quote and fee ready")
    f.model.updateDetails(
      params: f.params, quote: SwapValues(amount: amount, route: [f.xor, f.val]), dexId: 0
    ) { done.fulfill() }
    await fulfillment(of: [done], timeout: 1)
  }
  private func waitFees(_ f: SwapEditorFixture, _ count: Int) async {
    for _ in 0..<100 {
      if f.fees.count >= count { return }
      try? await Task.sleep(nanoseconds: 5_000_000)
    }
    XCTAssertEqual(f.fees.count, count)
  }
  func testFirstLoadSelectsTheRequestedPairAndSubscribesToBalances() async {
    let f = make()
    f.model.viewDidLoad()
    await settle()
    XCTAssertEqual(f.model.firstAssetId, f.xor)
    XCTAssertEqual(f.model.secondAssetId, f.val)
    XCTAssertEqual(f.balances.additions, 1)
    XCTAssertNotNil(f.model.middleButtonActionHandler)
    XCTAssertEqual(f.model.selectedMarket, .smart)
  }
  func testInitialLoadDoesNotEnableReviewBeforeAQuote() async {
    let f = make()
    f.model.viewDidLoad()
    await settle()
    XCTAssertFalse(f.view.enabled)
    XCTAssertNil(f.model.amounts)
  }
  func testInputPercentageReservesTheNetworkFee() async {
    let f = make()
    await ready(f)
    f.model.focusedField = .one
    f.model.didSelect(variant: 1)
    XCTAssertEqual(f.model.inputedFirstAmount, 9)
    XCTAssertEqual(f.view.firstText, "9")
  }
  func testInputPercentageClampsToZeroWhenFeeExceedsSelectedBalance() async {
    let f = make()
    f.fees.value = 20
    await ready(f)
    f.model.focusedField = .one
    f.model.didSelect(variant: 1)
    XCTAssertEqual(f.model.inputedFirstAmount, 0)
  }
  func testOutputPercentageUsesTheOutputTokensPrecision() async {
    let f = make()
    f.balances.values[f.val] = Decimal(string: "1.23456789")!
    f.model.updateAssetsBalance()
    f.model.focusedField = .two
    f.model.didSelect(variant: 1)
    XCTAssertEqual(
      f.view.secondText,
      NumberFormatter.inputedAmoutFormatter(with: 6).stringFromDecimal(f.model.inputedSecondAmount))
  }
  func testZeroInputBalanceDoesNotReplaceTheEnteredAmount() {
    let f = make()
    f.balances.values[f.xor] = 0
    f.model.updateAssetsBalance()
    f.model.inputedFirstAmount = 3
    f.model.didSelect(variant: 1)
    XCTAssertEqual(f.model.inputedFirstAmount, 3)
  }
  func testMissingInputBalanceCannotRetainAnotherWalletsOldBalance() {
    let f = make()
    f.balances.values[f.xor] = nil
    f.model.processBalance(data: [])
    XCTAssertEqual(f.model.firstAssetBalance.balance.decimalValue, 0)
  }
  func testMissingOutputBalanceCannotRetainTheOldBalance() {
    let f = make()
    f.balances.values[f.val] = nil
    f.model.processBalance(data: [])
    XCTAssertEqual(f.model.secondAssetBalance.balance.decimalValue, 0)
  }
  func testInputAssetSelectionExcludesTheCurrentOutput() {
    let f = make()
    f.model.choiсeBaseAssetButtonTapped()
    XCTAssertEqual(f.routes.assetLists.last, [f.xor, f.pswap])
  }
  func testOutputAssetSelectionExcludesTheCurrentInput() {
    let f = make()
    f.model.choiсeTargetAssetButtonTapped()
    XCTAssertEqual(f.routes.assetLists.last, [f.val, f.pswap])
  }
  func testSelectingAnInputAssetUpdatesThePairAndRequestsAPath() {
    let f = make()
    f.model.choiсeBaseAssetButtonTapped()
    f.routes.assetCompletion?(f.pswap)
    XCTAssertEqual(f.model.firstAssetId, f.pswap)
    XCTAssertEqual(f.interactor.paths.last?.0, f.pswap)
    XCTAssertEqual(f.interactor.paths.last?.1, f.val)
  }
  func testSelectingAnOutputAssetUpdatesThePair() {
    let f = make()
    f.model.choiсeTargetAssetButtonTapped()
    f.routes.assetCompletion?(f.pswap)
    XCTAssertEqual(f.model.secondAssetId, f.pswap)
  }
  func testCurrentPathSuccessLoadsItsMarketSources() {
    let f = make()
    f.model.didCheckPath(fromAssetId: f.xor, toAssetId: f.val, isAvailable: true)
    XCTAssertEqual(f.interactor.markets.count, 1)
    XCTAssertEqual(f.interactor.markets.first?.0, f.xor)
    XCTAssertTrue(f.view.marketLoading)
  }
  func testObsoletePathSuccessDoesNotLoadMarketSourcesForAnotherPair() {
    let f = make()
    f.model.didCheckPath(fromAssetId: f.val, toAssetId: f.pswap, isAvailable: true)
    XCTAssertTrue(f.interactor.markets.isEmpty)
  }
  func testObsoletePathFailureDoesNotDisableTheCurrentPair() {
    let f = make()
    f.view.enabled = true
    f.model.didCheckPath(fromAssetId: f.val, toAssetId: f.pswap, isAvailable: false)
    XCTAssertTrue(f.view.enabled)
  }
  func testCurrentPathFailureDisablesReview() {
    let f = make()
    f.view.enabled = true
    f.model.didCheckPath(fromAssetId: f.xor, toAssetId: f.val, isAvailable: false)
    XCTAssertFalse(f.view.enabled)
  }
  func testEmptyInputAmountIsNotReady() {
    let f = make()
    f.model.inputedFirstAmount = 0
    XCTAssertFalse(f.model.updateButtonState())
  }
  func testNegativeInputAmountIsNotReady() {
    let f = make()
    f.model.inputedFirstAmount = -1
    XCTAssertFalse(f.model.updateButtonState())
  }
  func testSameAssetPairIsNotReady() {
    let f = make()
    f.model.secondAssetId = f.xor
    XCTAssertFalse(f.model.updateButtonState())
  }
  func testReviewBeforeQuoteDoesNotOpenConfirmation() {
    let f = make()
    f.model.reviewButtonTapped()
    XCTAssertTrue(f.routes.reviews.isEmpty)
  }
  func testReadyReviewCarriesTheExactPairAmountsAndFee() async {
    let f = make()
    await ready(f)
    f.model.reviewButtonTapped()
    XCTAssertEqual(f.routes.reviews.count, 1)
    XCTAssertEqual(f.routes.reviews.first?.0, f.xor)
    XCTAssertEqual(f.routes.reviews.first?.1, f.val)
    XCTAssertEqual(f.routes.reviews.first?.2, 1)
    XCTAssertEqual(f.routes.reviews.first?.3, 2)
    XCTAssertEqual(f.routes.reviews.first?.4, 1)
  }
  func testReviewRechecksBalanceChangesBeforePresentingConfirmation() async {
    let f = make()
    await ready(f)
    f.balances.values[f.xor] = 0
    f.model.reviewButtonTapped()
    XCTAssertTrue(f.routes.reviews.isEmpty)
  }
  func testInvalidNetworkFeeCannotOpenReview() async {
    let f = make()
    f.fees.value = 0
    await ready(f)
    f.model.reviewButtonTapped()
    XCTAssertTrue(f.routes.reviews.isEmpty)
  }
  func testFailedQuoteClearsThePreviousReviewData() async {
    let f = make()
    await ready(f)
    f.model.didLoadQuote(nil, dexId: 0, params: f.params)
    f.model.reviewButtonTapped()
    XCTAssertTrue(f.routes.reviews.isEmpty)
    XCTAssertFalse(f.view.enabled)
  }
  func testOlderFeeCompletionCannotReplaceTheNewerQuote() async {
    let f = make()
    f.fees.holding = true
    f.model.updateDetails(
      params: f.params, quote: SwapValues(amount: "2000000", route: [f.xor, f.val]), dexId: 0)
    await waitFees(f, 1)
    f.model.updateDetails(
      params: f.params, quote: SwapValues(amount: "3000000", route: [f.xor, f.val]), dexId: 0)
    await waitFees(f, 2)
    f.fees.release(1)
    await settle()
    XCTAssertEqual(f.model.amounts?.toAmount, 3)
    f.fees.release(0)
    await settle()
    XCTAssertEqual(f.model.amounts?.toAmount, 3)
  }
  func testQuoteCompletingAfterAnAssetChangeIsDiscarded() async {
    let f = make()
    f.fees.holding = true
    f.model.updateDetails(
      params: f.params, quote: SwapValues(amount: "2000000", route: [f.xor, f.val]), dexId: 0)
    await waitFees(f, 1)
    f.model.secondAssetId = f.pswap
    f.fees.release(0)
    await settle()
    XCTAssertNil(f.model.amounts)
  }
  func testQuoteCompletingAfterTheInputAmountChangesIsDiscarded() async {
    let f = make()
    f.fees.holding = true
    f.model.updateDetails(
      params: f.params, quote: SwapValues(amount: "2000000", route: [f.xor, f.val]), dexId: 0)
    await waitFees(f, 1)
    f.model.inputedFirstAmount = 2
    f.fees.release(0)
    await settle()
    XCTAssertNil(f.model.amounts)
  }
  func testReverseActionSwapsTokensAndMovesFocusToTheOtherAmount() async {
    let f = make()
    f.model.viewDidLoad()
    await settle()
    f.model.focusedField = .one
    f.model.inputedFirstAmount = 3
    f.model.middleButtonActionHandler?()
    XCTAssertEqual(f.model.firstAssetId, f.val)
    XCTAssertEqual(f.model.secondAssetId, f.xor)
    XCTAssertEqual(f.view.focused, .two)
    XCTAssertEqual(f.model.inputedSecondAmount, 3)
  }
}
private final class SwapEditorFixture {
  let xor = WalletAssetId.xor.rawValue, val = WalletAssetId.val.rawValue,
    pswap = WalletAssetId.pswap.rawValue
  let assets = SwapEditorAssets(), balances = SwapEditorBalances(), fees = SwapEditorFees(),
    interactor = SwapEditorInteractor(), routes = SwapEditorRoutes(), view = SwapEditorView(),
    fiat = SwapEditorFiat()
  let model: SwapViewModel
  var params: PolkaswapMainInteractorQuoteParams {
    .init(
      fromAssetId: xor, toAssetId: val, amount: "1000000000000000000", swapVariant: .desiredInput,
      liquiditySources: [], filterMode: .disabled)
  }
  init() {
    model = SwapViewModel(
      selectedTokenId: xor, selectedSecondTokenId: val, wireframe: routes, fiatService: fiat,
      assetManager: assets, detailsFactory: DetailViewModelFactory(assetManager: assets),
      eventCenter: EventCenter(), interactor: interactor, networkFacade: nil,
      assetsProvider: balances, lpServiceFee: SwapEditorLPFee(), polkaswapNetworkFacade: nil,
      marketCapService: SwapEditorMarket(), feeProvider: fees)
    model.view = view
    model.firstAssetId = xor
    model.secondAssetId = val
    model.inputedFirstAmount = 1
  }
}
private final class SwapEditorBalances: AssetProviderProtocol {
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
private final class SwapEditorFees: FeeProviderProtocol {
  var value: Decimal = 1, holding = false
  private let lock = NSLock()
  private var completions = [CheckedContinuation<Decimal, Never>?]()
  var count: Int {
    lock.lock()
    defer { lock.unlock() }
    return completions.count
  }
  func releaseAll() {
    lock.lock()
    let pending = completions
    completions = []
    lock.unlock()
    pending.forEach { $0?.resume(returning: value) }
  }
  func release(_ index: Int) {
    lock.lock()
    guard completions.indices.contains(index) else {
      lock.unlock()
      XCTFail("Missing pending fee request")
      return
    }
    let completion = completions[index]
    completions[index] = nil
    lock.unlock()
    completion?.resume(returning: value)
  }
  func getFee(for type: TransactionType, completion: @escaping (Decimal) -> Void) {
    completion(value)
  }
  func getFee(for type: InputRewardAmountType, completion: @escaping (Decimal) -> Void) {
    completion(value)
  }
  func getFee(for call: any RuntimeCallable) async -> Decimal { value }
  func getFee(for type: TransactionType) async -> Decimal {
    guard holding else { return value }
    return await withCheckedContinuation { continuation in
      lock.lock()
      completions.append(continuation)
      lock.unlock()
    }
  }
}
private actor SwapEditorFiat: FiatServiceProtocol {
  func getFiat() async -> [PIExactFiatData] { [] }
}
private final class SwapEditorMarket: MarketCapServiceProtocol {
  func getMarketCap(for assets: [String]) async -> Set<MarketCapInfo> { [] }
}
private final class SwapEditorLPFee: LPFeeServiceProtocol {
  func getLpfee(with dex: UInt32) -> String { "0.3%" }
}

private final class SwapEditorAssets: AssetManagerProtocol {
  static var networkAssets: [AssetInfo] = []
  let assets = [(WalletAssetId.xor, "XOR"), (.val, "VAL"), (.pswap, "PSWAP")].map {
    AssetInfo(
      id: $0.0.rawValue, symbol: $0.1, chainId: "", precision: $0.0 == .val ? 6 : 18, icon: nil,
      displayName: $0.1, visible: true)
  }
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
private final class SwapEditorInteractor: PolkaswapMainInteractorInputProtocol {
  var paths = [(String, String)](), markets = [(String, String)]()
  func networkFeeValue(completion: @escaping (Decimal) -> Void) { completion(1) }
  func checkIsPathAvailable(fromAssetId: String, toAssetId: String) {
    paths.append((fromAssetId, toAssetId))
  }
  func loadMarketSources(fromAssetId: String, toAssetId: String) {
    markets.append((fromAssetId, toAssetId))
  }
  func quote(params: PolkaswapMainInteractorQuoteParams) {}
  func loadBalance(asset: AssetInfo) {}
  func unsubscribePoolXYK() {}
  func unsubscribePoolTBC() {}
  func subscribePoolXYK(assetId1: String, assetId2: String) {}
  func subscribePoolTBC(assetId: String) {}
  func setup() {}
  func stop() {}
}
private final class SwapEditorView: UIViewController, LiquidityViewProtocol {
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

private final class SwapEditorRoutes: LiquidityWireframeProtocol {
  var assetLists = [[String]](), assetCompletion: ((String) -> Void)?,
    reviews = [(String, String, Decimal, Decimal, Decimal)]()
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
  ) {}

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
