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
  private let quoteLock = NSLock()
  private var capturedQuotes = [PolkaswapMainInteractorQuoteParams]()
  var quotes: [PolkaswapMainInteractorQuoteParams] { quoteLock.lock(); defer { quoteLock.unlock() }; return capturedQuotes }
  var paths = [(String, String)](), markets = [(String, String)]()
  func networkFeeValue(completion: @escaping (Decimal) -> Void) { completion(1) }
  func checkIsPathAvailable(fromAssetId: String, toAssetId: String) {
    paths.append((fromAssetId, toAssetId))
  }
  func loadMarketSources(fromAssetId: String, toAssetId: String) {
    markets.append((fromAssetId, toAssetId))
  }
  func quote(params: PolkaswapMainInteractorQuoteParams) { quoteLock.lock(); capturedQuotes.append(params); quoteLock.unlock() }
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
  var slippages = [PolkaswapSlippage](), slippageCompletion: ((PolkaswapSlippage) -> Void)?
  var offeredMarkets = [[LiquiditySourceType]](), selectedMarkets = [LiquiditySourceType](), marketCompletion: ((LiquiditySourceType) -> Void)?
  var alerts = [(String?, String?, String?)](), alertHosts = [UIViewController?]()
  func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?) {
    alerts.append((message, title, closeAction)); alertHosts.append(view?.controller)
  }
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
  ) { slippages.append(currentLocale); slippageCompletion = completion }

  func showChoiсeMarket(
    on controller: UINavigationController?,
    selectedMarket: LiquiditySourceType,
    markets: [LiquiditySourceType],
    completion: @escaping (LiquiditySourceType) -> Void
  ) { offeredMarkets.append(markets); selectedMarkets.append(selectedMarket); marketCompletion = completion }

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

extension SwapEditorFlowTests {
    private func awaitQuote(_ f: SwapEditorFixture, count: Int = 1) async throws -> PolkaswapMainInteractorQuoteParams {
        let deadline = Date().addingTimeInterval(3)
        while f.interactor.quotes.count < count && Date() < deadline { try? await Task.sleep(nanoseconds: 20_000_000) }
        return try XCTUnwrap(f.interactor.quotes.last)
    }
    func testCurrentMarketDiscoveryBuildsAnExactInputQuote() async throws {
        let f = make(); f.model.didLoadMarketSources([LiquiditySourceType.xyk.rawValue], fromAssetId: f.xor, toAssetId: f.val)
        let quote = try await awaitQuote(f)
        XCTAssertEqual(quote.fromAssetId, f.xor); XCTAssertEqual(quote.toAssetId, f.val)
        XCTAssertEqual(quote.amount, "1000000000000000000"); XCTAssertEqual(quote.swapVariant, .desiredInput)
        XCTAssertEqual(quote.filterMode, .disabled); XCTAssertEqual(quote.liquiditySources, [LiquiditySourceType.xyk.rawValue])
        XCTAssertFalse(f.view.marketLoading)
    }
    func testExactOutputQuoteUsesTheRequestedTokensPrecision() async throws {
        let f = make(); f.model.swapVariant = .desiredOutput; f.model.inputedSecondAmount = Decimal(string: "1.234567")!
        f.model.didLoadMarketSources([LiquiditySourceType.xyk.rawValue], fromAssetId: f.xor, toAssetId: f.val)
        let quote = try await awaitQuote(f)
        XCTAssertEqual(quote.amount, "1234567"); XCTAssertEqual(quote.swapVariant, .desiredOutput)
    }
    func testExplicitMarketQuoteEnablesTheSelectedSourceFilter() async throws {
        let f = make(); f.model.selectedMarket = .tbc
        f.model.didLoadMarketSources([LiquiditySourceType.tbc.rawValue], fromAssetId: f.xor, toAssetId: f.val)
        let quote = try await awaitQuote(f)
        XCTAssertEqual(quote.filterMode, .allowSelected); XCTAssertEqual(quote.liquiditySources, [LiquiditySourceType.tbc.rawValue])
    }
    func testObsoleteMarketDiscoveryDoesNotChangeTheCurrentMarketOrScheduleAQuote() async {
        let f = make(); f.view.marketLoading = true
        f.model.didLoadMarketSources([LiquiditySourceType.tbc.rawValue], fromAssetId: f.val, toAssetId: f.pswap)
        await settle(); XCTAssertFalse(f.model.marketSourcer?.isLoaded() == true)
        XCTAssertTrue(f.interactor.quotes.isEmpty); XCTAssertTrue(f.view.marketLoading)
    }
    func testMissingMarketSourceCannotProcessADiscoveryResult() {
        let f = make(); f.model.marketSourcer = nil
        f.model.didLoadMarketSources([LiquiditySourceType.xyk.rawValue], fromAssetId: f.xor, toAssetId: f.val)
        XCTAssertTrue(f.interactor.quotes.isEmpty)
    }
    func testMarketRemovalSelectsTheLastAvailableSource() {
        let f = make(); let sources = SwapMarketSourcer(fromAssetId: f.xor, toAssetId: f.val)
        sources.setMarketSources([.xyk, .tbc]); f.model.marketSourcer = sources; f.model.selectedMarket = .smart
        f.model.updateSelectedMarketSourceIfNecessary(); XCTAssertEqual(f.model.selectedMarket, .tbc)
    }
    func testEmptyOrMissingMarketListFallsBackWithoutEnablingReview() {
        let f = make(); let sources = SwapMarketSourcer(fromAssetId: f.xor, toAssetId: f.val)
        sources.setMarketSources([]); f.model.marketSourcer = sources; f.model.selectedMarket = .tbc
        f.model.updateSelectedMarketSourceIfNecessary(); XCTAssertEqual(f.model.selectedMarket, .smart)
        XCTAssertFalse(f.model.updateButtonState()); XCTAssertFalse(f.view.enabled)
        f.model.marketSourcer = nil; f.model.updateSelectedMarketSourceIfNecessary(); XCTAssertEqual(f.model.selectedMarket, .smart)
    }
    func testSlippagePickerReceivesTheCurrentValueAndAppliesItsResult() throws {
        let f = make(); let chosen = try XCTUnwrap(PolkaswapSlippage(basisPoints: 125))
        f.model.changeSlippageTolerance(); XCTAssertEqual(f.routes.slippages, [.defaultValue])
        try XCTUnwrap(f.routes.slippageCompletion)(chosen); XCTAssertEqual(f.model.slippageTolerance, chosen)
    }
    func testMarketPickerOffersOnlySmartAndBondingCurveSources() throws {
        let f = make(); let sources = SwapMarketSourcer(fromAssetId: f.xor, toAssetId: f.val)
        sources.setMarketSources([.xyk, .tbc, .smart]); f.model.marketSourcer = sources
        f.model.changeMarket(); XCTAssertEqual(f.routes.offeredMarkets, [[.tbc, .smart]])
        XCTAssertEqual(f.routes.selectedMarkets, [.smart]); try XCTUnwrap(f.routes.marketCompletion)(.tbc)
        XCTAssertEqual(f.model.selectedMarket, .tbc)
    }
    func testMissingMarketProviderStillOffersSmartRouting() {
        let f = make(); f.model.marketSourcer = nil; f.model.changeMarket()
        XCTAssertEqual(f.routes.offeredMarkets, [[.smart]])
    }
    func testNewBlockRefreshInvalidatesOldAmountsBeforeRequestingAnotherQuote() async throws {
        let f = make(); await ready(f); XCTAssertNotNil(f.model.amounts)
        f.model.marketSourcer?.didLoad([LiquiditySourceType.xyk.rawValue])
        f.model.processNewBlockAppeared(event: NewBlockEvent())
        XCTAssertNil(f.model.amounts); XCTAssertFalse(f.view.enabled)
        _ = try await awaitQuote(f)
    }
    func testPoolNotificationsCoalesceIntoOneCurrentQuote() async throws {
        let f = make(); f.model.marketSourcer?.didLoad([LiquiditySourceType.xyk.rawValue])
        f.model.didUpdatePoolSubscription(); f.model.didUpdatePoolSubscription()
        _ = try await awaitQuote(f); XCTAssertEqual(f.interactor.quotes.count, 1)
    }
    func testSwappingSidesWhileEditingOutputMovesThatAmountToTheInput() async {
        let f = make(); f.model.viewDidLoad(); await settle(); f.model.focusedField = .two
        f.model.inputedSecondAmount = 7; f.model.middleButtonActionHandler?()
        XCTAssertEqual(f.model.firstAssetId, f.val); XCTAssertEqual(f.model.secondAssetId, f.xor)
        XCTAssertEqual(f.model.inputedFirstAmount, 7); XCTAssertEqual(f.view.focused, .one)
    }
    func testExactOutputWithNoPositiveRequestedAmountIsNotReady() {
        let f = make(); f.model.swapVariant = .desiredOutput; f.model.inputedSecondAmount = 0
        XCTAssertFalse(f.model.updateButtonState()); XCTAssertFalse(f.view.enabled)
    }
    func testExactOutputCannotUseAnUnquotedSlippageLimit() {
        let f = make(); f.model.swapVariant = .desiredOutput; f.model.inputedSecondAmount = 1
        XCTAssertFalse(f.model.checkBalances()); XCTAssertFalse(f.view.enabled)
    }
    func testThreeFeeInfoActionsKeepTheirMessagesAndHostTogether() {
        let f = make(); f.model.minMaxReceivedInfoButtonTapped(); f.model.networkFeeInfoButtonTapped(); f.model.swapFeeInfoButtonTapped()
        XCTAssertEqual(f.routes.alerts.count, 3); XCTAssertEqual(f.routes.alerts.first?.0, f.model.swapVariant.message)
        XCTAssertEqual(f.routes.alerts.first?.1, f.model.swapVariant.title)
        XCTAssertTrue(f.routes.alerts.allSatisfy { !($0.0 ?? "").isEmpty && !($0.1 ?? "").isEmpty && $0.2 != nil })
        XCTAssertTrue(f.routes.alertHosts.allSatisfy { $0 === f.view })
    }
    func testSuccessfulCurrentQuoteEnablesReviewAfterItsFeeArrives() async {
        let f = make(); f.model.didLoadQuote(SwapValues(amount: "2000000", route: [f.xor, f.val]), dexId: 4, params: f.params)
        let deadline = Date().addingTimeInterval(2)
        while !f.view.enabled && Date() < deadline { try? await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertTrue(f.view.enabled); XCTAssertEqual(f.model.amounts?.fromAmount, 1); XCTAssertEqual(f.model.amounts?.toAmount, 2)
    }
    func testSuccessfulQuoteCannotEnableReviewAfterFundsDisappear() async {
        let f = make(); f.balances.values[f.xor] = 0; f.model.processBalance(data: [])
        f.model.didLoadQuote(SwapValues(amount: "2000000", route: [f.xor, f.val]), dexId: 4, params: f.params)
        let deadline = Date().addingTimeInterval(2)
        while f.model.amounts == nil && Date() < deadline { try? await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertNotNil(f.model.amounts); XCTAssertFalse(f.view.enabled)
    }
}
