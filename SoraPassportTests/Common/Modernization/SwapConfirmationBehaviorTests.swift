// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause
import RobinHood
import SoraFoundation
import SoraUIKit
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class SwapConfirmationBehaviorTests: XCTestCase {
    private var language = "en"
    private let xor = WalletAssetId.xor.rawValue
    private let val = WalletAssetId.val.rawValue
    private let pswap = WalletAssetId.pswap.rawValue
    override func setUp() { super.setUp(); language = LocalizationManager.shared.selectedLocalization; LocalizationManager.shared.selectedLocalization = "en" }
    override func tearDown() { LocalizationManager.shared.selectedLocalization = language; super.tearDown() }
    private final class Fixture {
        let model: ConfirmSwapViewModel; let provider: SwapReviewBalances; let wallet: SwapReviewNetwork; let interactor: SwapReviewInteractor
        var rows: [SoramitsuTableViewItemProtocol] = []
        let params: PolkaswapMainInteractorQuoteParams
        init(from: String, to: String, direction: SwapVariant, fee: Decimal, values: [String: Decimal]) {
            provider = SwapReviewBalances(values: values); wallet = SwapReviewNetwork(); interactor = SwapReviewInteractor()
            let manager = SwapReviewAssets(); let tolerance = PolkaswapSlippage.defaultValue
            params = PolkaswapMainInteractorQuoteParams(fromAssetId: from, toAssetId: to, amount: "5000000000000000000", swapVariant: direction, liquiditySources: [], filterMode: .disabled)
            model = ConfirmSwapViewModel(wireframe: nil, firstAssetId: from, secondAssetId: to, assetManager: manager,
                eventCenter: EventCenter(), firstAssetAmount: direction == .desiredInput ? 5 : 10,
                secondAssetAmount: direction == .desiredInput ? 10 : 5, slippageTolerance: tolerance, details: [], market: .xyk,
                amounts: SwapQuoteAmounts(fromAmount: 5, toAmount: 10), walletService: wallet, fee: fee, swapVariant: direction,
                minMaxValue: direction == .desiredInput ? tolerance.minimumAmount(for: 10) : tolerance.maximumAmount(for: 10), dexId: 0,
                interactor: interactor, quoteParams: params, assetsProvider: provider, fiatData: [])
            model.setupItems = { [weak self] in self?.rows = $0 }; model.reloadItems = { [weak self] in self?.rows = $0 }; model.viewDidLoad()
        }
        var button: SoramitsuButtonItem? { rows.compactMap { $0 as? SoramitsuButtonItem }.first }
        var assets: ConfirmAssetsItem? { rows.compactMap { $0 as? ConfirmAssetsItem }.first }
    }
    private func fixture(from: String? = nil, to: String? = nil, direction: SwapVariant = .desiredInput, fee: Decimal = 1, values: [String: Decimal]) -> Fixture {
        Fixture(from: from ?? xor, to: to ?? val, direction: direction, fee: fee, values: values)
    }
    func testXORSwapRequiresTheInputAndFeeTogether() {
        XCTAssertFalse(fixture(values: [xor: 5, val: 0]).button?.isEnable == true)
        XCTAssertTrue(fixture(values: [xor: 6, val: 0]).button?.isEnable == true)
    }
    func testOutputXORCanPayFeeOnlyFromItsGuaranteedMinimum() {
        XCTAssertTrue(fixture(from: val, to: xor, fee: 9, values: [val: 5, xor: 0]).button?.isEnable == true)
        XCTAssertFalse(fixture(from: val, to: xor, fee: 10, values: [val: 5, xor: 0]).button?.isEnable == true)
    }
    func testThirdTokenSwapRequiresASeparateXORFeeBalance() {
        XCTAssertTrue(fixture(from: val, to: pswap, values: [val: 5, pswap: 0, xor: 1]).button?.isEnable == true)
        XCTAssertFalse(fixture(from: val, to: pswap, values: [val: 5, pswap: 0, xor: 0]).button?.isEnable == true)
    }
    func testExactOutputBudgetIncludesSlippageAndNetworkFee() {
        XCTAssertFalse(fixture(direction: .desiredOutput, values: [xor: 11, val: 0]).button?.isEnable == true)
        XCTAssertTrue(fixture(direction: .desiredOutput, values: [xor: Decimal(string: "11.05")!, val: 0]).button?.isEnable == true)
    }
    func testInvalidFeeAndSameAssetNeverEnableSwap() {
        for fee in [Decimal.zero, Decimal(-1), Decimal.nan] {
            XCTAssertFalse(fixture(fee: fee, values: [xor: 20, val: 0]).button?.isEnable == true)
        }
        XCTAssertFalse(fixture(to: xor, values: [xor: 20]).button?.isEnable == true)
    }
    func testDisappearingInputBalanceInvalidatesTheReview() {
        let f = fixture(values: [xor: 6, val: 0]); XCTAssertTrue(f.button?.isEnable == true)
        f.provider.values[xor] = nil; f.model.processBalance(data: [])
        XCTAssertFalse(f.button?.isEnable == true)
    }
    func testDisappearingFeeBalanceInvalidatesTheReview() {
        let f = fixture(from: val, to: pswap, values: [val: 5, pswap: 0, xor: 1]); XCTAssertTrue(f.button?.isEnable == true)
        f.provider.values[xor] = nil; f.model.processBalance(data: [])
        XCTAssertFalse(f.button?.isEnable == true)
    }
    func testSubmitRechecksTheCurrentProviderBeforeSending() {
        let f = fixture(values: [xor: 6, val: 0]); f.provider.values[xor] = 0; f.model.submit()
        XCTAssertTrue(f.wallet.transfers.isEmpty); XCTAssertFalse(f.button?.isEnable == true)
    }
    func testFailedQuoteCannotBeResubmittedFromTheOldQuote() {
        let f = fixture(values: [xor: 6, val: 0]); f.model.didLoadQuote(nil, dexId: 0, params: f.params)
        XCTAssertFalse(f.button?.isEnable == true); f.model.submit(); XCTAssertTrue(f.wallet.transfers.isEmpty)
    }
    func testBalanceUpdateCannotReenableAnUnavailableQuote() {
        let f = fixture(values: [xor: 6, val: 0]); f.model.didLoadQuote(nil, dexId: 0, params: f.params)
        f.model.processBalance(data: []); XCTAssertFalse(f.button?.isEnable == true)
    }
    func testIdenticalSuccessfulQuoteRecoversAfterTransientFailure() {
        let f = fixture(values: [xor: 6, val: 0]); f.model.didLoadQuote(nil, dexId: 0, params: f.params)
        f.model.didLoadQuote(SwapValues(amount: "10000000000000000000", route: [xor, val]), dexId: 0, params: f.params)
        XCTAssertTrue(f.button?.isEnable == true)
    }
    func testQuoteForDifferentPairCannotReplaceTheCurrentReview() {
        let f = fixture(values: [xor: 6, val: 0])
        let unrelated = PolkaswapMainInteractorQuoteParams(fromAssetId: xor, toAssetId: pswap, amount: f.params.amount, swapVariant: .desiredInput, liquiditySources: [], filterMode: .disabled)
        f.model.didLoadQuote(SwapValues(amount: "999000000000000000000", route: [xor, pswap]), dexId: 0, params: unrelated)
        XCTAssertEqual(f.model.secondAssetAmount, 10); XCTAssertEqual(f.assets?.secondAssetImageModel.amountText, "10")
    }
    func testQuoteForDifferentAmountCannotReplaceTheCurrentReview() {
        let f = fixture(values: [xor: 6, val: 0])
        let unrelated = PolkaswapMainInteractorQuoteParams(fromAssetId: xor, toAssetId: val, amount: "9000000000000000000", swapVariant: .desiredInput, liquiditySources: [], filterMode: .disabled)
        f.model.didLoadQuote(SwapValues(amount: "99000000000000000000", route: [xor, val]), dexId: 0, params: unrelated)
        XCTAssertEqual(f.model.secondAssetAmount, 10)
    }
    func testNewExactInputQuoteUpdatesOutputAndLimitsTogether() {
        let f = fixture(values: [xor: 6, val: 0])
        f.model.didLoadQuote(SwapValues(amount: "20000000000000000000", route: [xor, val]), dexId: 7, params: f.params)
        XCTAssertEqual(f.model.secondAssetAmount, 20); XCTAssertEqual(f.model.minMaxValue, Decimal(string: "19.9"))
        XCTAssertEqual(f.assets?.secondAssetImageModel.amountText, "20"); XCTAssertEqual(f.model.details.count, 5)
    }
    func testNewExactOutputQuoteUpdatesMaximumSpendAndAvailability() {
        let f = fixture(direction: .desiredOutput, values: [xor: 12, val: 0])
        f.model.didLoadQuote(SwapValues(amount: "20000000000000000000", route: [xor, val]), dexId: 7, params: f.params)
        XCTAssertEqual(f.model.firstAssetAmount, 20); XCTAssertEqual(f.model.minMaxValue, Decimal(string: "20.1"))
        XCTAssertEqual(f.assets?.firstAssetImageModel.amountText, "20"); XCTAssertFalse(f.button?.isEnable == true)
    }
    func testUpdatedQuoteRebuildsTheDisplayedGuaranteedMinimum() {
        let f = fixture(values: [xor: 6, val: 0])
        f.model.didLoadQuote(SwapValues(amount: "20000000000000000000", route: [xor, val]), dexId: 0, params: f.params)
        let text = f.rows.compactMap { $0 as? SoraTextItem }.first?.text.attributedString.string
        XCTAssertTrue(text?.contains("19.9") == true)
        XCTAssertFalse(text?.contains("9.95") == true)
    }
    func testMalformedQuoteDisablesReviewUntilAValidQuoteArrives() {
        let f = fixture(values: [xor: 6, val: 0])
        f.model.didLoadQuote(SwapValues(amount: "invalid", route: [xor, val]), dexId: 0, params: f.params)
        XCTAssertFalse(f.button?.isEnable == true); f.model.submit(); XCTAssertTrue(f.wallet.transfers.isEmpty)
        f.model.didLoadQuote(SwapValues(amount: "10000000000000000000", route: [xor, val]), dexId: 0, params: f.params)
        XCTAssertTrue(f.button?.isEnable == true)
    }
    func testReviewPreservesAmountsSmallerThanEightDecimals() {
        let f = fixture(values: [xor: 6, val: 0])
        f.model.firstAssetAmount = Decimal(string: "0.000000001")!
        f.model.secondAssetAmount = Decimal(string: "0.000000002")!
        f.model.setupContent()
        XCTAssertEqual(f.assets?.firstAssetImageModel.amountText, "0.000000001")
        XCTAssertEqual(f.assets?.secondAssetImageModel.amountText, "0.000000002")
    }
    func testUnrelatedQuoteFailureDoesNotInvalidateTheReviewedPair() {
        let f = fixture(values: [xor: 6, val: 0])
        let unrelated = PolkaswapMainInteractorQuoteParams(fromAssetId: xor, toAssetId: pswap, amount: f.params.amount, swapVariant: .desiredInput, liquiditySources: [], filterMode: .disabled)
        f.model.didLoadQuote(nil, dexId: 0, params: unrelated)
        XCTAssertTrue(f.button?.isEnable == true)
    }
    func testSuccessfulSwapBuildsTheReviewedExactContextWithoutLiveTransport() throws {
        let f = fixture(values: [xor: 6, val: 0]); f.model.submit()
        let info = try XCTUnwrap(f.wallet.transfers.first)
        XCTAssertEqual(info.asset, xor); XCTAssertEqual(info.destination, val); XCTAssertEqual(info.amount.decimalValue, 5)
        XCTAssertEqual(info.context?[TransactionContextKeys.minMaxValue], "9.95")
        XCTAssertEqual(info.context?[TransactionContextKeys.dex], "0")
    }
}
private final class SwapReviewBalances: AssetProviderProtocol {
    var values: [String: Decimal]; init(values: [String: Decimal]) { self.values = values }
    func getBalances(with assetIds: [String]) -> [BalanceData] { assetIds.compactMap { id in values[id].map { BalanceData(identifier: id, balance: AmountDecimal(value: $0)) } } }
    func add(observer: AssetProviderObserverProtocol) {}
    func remove(observer: AssetProviderObserverProtocol) {}
}
private final class SwapReviewAssets: AssetManagerProtocol {
    static var networkAssets: [AssetInfo] = []
    let assets = [(WalletAssetId.xor, "XOR"), (.val, "VAL"), (.pswap, "PSWAP")].map {
        AssetInfo(id: $0.0.rawValue, symbol: $0.1, chainId: "", precision: 18, icon: nil, displayName: $0.1, visible: true)
    }
    func assetInfo(for identifier: String) -> AssetInfo? { assets.first { $0.identifier == identifier } }
    func getAssetList() -> [AssetInfo]? { assets }
    func updateAssetList(_ list: [AssetInfo]) {}
    func saveAssetList(_ list: [AssetInfo]) {}
    func sortedAssets(_ list: [WalletAsset], onlyVisible: Bool) -> [WalletAsset] { list }
    func visibleCount() -> UInt { 3 }
    func setup(for accountSettings: SelectedWalletSettings) {}
}
private final class SwapReviewInteractor: PolkaswapMainInteractorInputProtocol {
    func networkFeeValue(completion: @escaping (Decimal) -> Void) { completion(1) }
    func checkIsPathAvailable(fromAssetId: String, toAssetId: String) {}
    func loadMarketSources(fromAssetId: String, toAssetId: String) {}
    func quote(params: PolkaswapMainInteractorQuoteParams) {}
    func loadBalance(asset: AssetInfo) {}
    func unsubscribePoolXYK() {}
    func unsubscribePoolTBC() {}
    func subscribePoolXYK(assetId1: String, assetId2: String) {}
    func subscribePoolTBC(assetId: String) {}
    func setup() {}
    func stop() {}
}
private final class SwapReviewCall: CancellableCall { var cancellations = 0; func cancel() { cancellations += 1 } }
private final class SwapReviewNetwork: WalletServiceProtocol {
    var transfers: [TransferInfo] = []
    var queries: [String] = []; var completions: [SearchCompletionBlock] = []; var calls: [SwapReviewCall] = []
    private let unused = WalletService(operationFactory: WalletNetworkOperationFactoryProtocolMock())
    func search(for searchString: String, runCompletionIn queue: DispatchQueue, completionBlock: @escaping SearchCompletionBlock) -> CancellableCall {
        queries.append(searchString); completions.append(completionBlock); let call = SwapReviewCall(); calls.append(call); return call
    }
    func fetchBalance(for assets: [String], runCompletionIn queue: DispatchQueue, completionBlock: @escaping BalanceCompletionBlock) -> CancellableCall { unused.fetchBalance(for: assets, runCompletionIn: queue, completionBlock: completionBlock) }
    func fetchTransactionHistory(for filter: WalletHistoryRequest, pagination: Pagination, runCompletionIn queue: DispatchQueue, completionBlock: @escaping TransactionHistoryBlock) -> CancellableCall { unused.fetchTransactionHistory(for: filter, pagination: pagination, runCompletionIn: queue, completionBlock: completionBlock) }
    func fetchTransferMetadata(for info: TransferMetadataInfo, runCompletionIn queue: DispatchQueue, completionBlock: @escaping TransferMetadataCompletionBlock) -> CancellableCall { unused.fetchTransferMetadata(for: info, runCompletionIn: queue, completionBlock: completionBlock) }
    func transfer(info: TransferInfo, runCompletionIn queue: DispatchQueue, completionBlock: @escaping DataResultCompletionBlock) -> CancellableCall { transfers.append(info); return SwapReviewCall() }
    func prepareTransferSubmission(for info: TransferInfo, preSigningValidation: @escaping () throws -> Void) async throws -> PreparedSora2TransferSubmission { XCTFail("Scanner attempted to sign"); throw CancellationError() }
    func submitPreparedTransfer(_ submission: PreparedSora2TransferSubmission, info: TransferInfo, preTransportValidation: @escaping () throws -> Void) async throws -> Data { XCTFail("Scanner attempted a submission"); throw CancellationError() }
    func fetchContacts(runCompletionIn queue: DispatchQueue, completionBlock: @escaping SearchCompletionBlock) -> CancellableCall { unused.fetchContacts(runCompletionIn: queue, completionBlock: completionBlock) }
    func fetchWithdrawalMetadata(for info: WithdrawMetadataInfo, runCompletionIn queue: DispatchQueue, completionBlock: @escaping WithdrawalMetadataCompletionBlock) -> CancellableCall { unused.fetchWithdrawalMetadata(for: info, runCompletionIn: queue, completionBlock: completionBlock) }
    func withdraw(info: WithdrawInfo, runCompletionIn queue: DispatchQueue, completionBlock: @escaping DataResultCompletionBlock) -> CancellableCall { XCTFail("Scanner attempted withdrawal"); return SwapReviewCall() }
}

@MainActor
final class LiquidityReviewPresentationTests: XCTestCase {
    private var language = "en"
    private let manager = SwapReviewAssets()
    private let pools = ReviewPools()
    private var rows: [SoramitsuTableViewItemProtocol] = []
    override func setUp() { super.setUp(); language = LocalizationManager.shared.selectedLocalization; LocalizationManager.shared.selectedLocalization = "en" }
    override func tearDown() { LocalizationManager.shared.selectedLocalization = language; super.tearDown() }
    private func supply(_ type: TransactionType = .liquidityAdd, amount: Decimal = 2) -> ConfirmSupplyLiquidityViewModel {
        let model = ConfirmSupplyLiquidityViewModel(wireframe: nil, baseAssetId: WalletAssetId.xor.rawValue, targetAssetId: WalletAssetId.val.rawValue,
            poolsService: pools, assetManager: manager, firstAssetAmount: amount, secondAssetAmount: 7, slippageTolerance: .defaultValue, details: [],
            transactionType: type, fee: 1, operationFactory: WalletNetworkOperationFactoryProtocolMock(), feeChangeHandler: {}, walletService: SwapReviewNetwork())
        model.setupItems = { [weak self] in self?.rows = $0 }; model.viewDidLoad(); return model
    }
    private func remove(amount: Decimal = 2) -> ConfirmRemoveLiquidityViewModel {
        let model = ConfirmRemoveLiquidityViewModel(wireframe: nil,
            poolInfo: PoolInfo(baseAssetId: WalletAssetId.xor.rawValue, targetAssetId: WalletAssetId.val.rawValue, poolId: "pool", accountId: ""),
            poolsService: pools, assetManager: manager, firstAssetAmount: amount, secondAssetAmount: 7, slippageTolerance: .defaultValue, details: [],
            operationFactory: WalletNetworkOperationFactoryProtocolMock(), feeChangeHandler: {}, walletService: SwapReviewNetwork(), fee: 1)
        model.setupItems = { [weak self] in self?.rows = $0 }; model.viewDidLoad(); return model
    }
    private var pair: ConfirmAssetsItem? { rows.compactMap { $0 as? ConfirmAssetsItem }.first }
    func testSupplyReviewKeepsAmountsAndTokensPaired() {
        let model = supply(); XCTAssertNotNil(model.title); XCTAssertNil(model.imageName)
        XCTAssertEqual(pair?.firstAssetImageModel.amountText, "2"); XCTAssertEqual(pair?.firstAssetImageModel.symbol, "XOR")
        XCTAssertEqual(pair?.secondAssetImageModel.amountText, "7"); XCTAssertEqual(pair?.secondAssetImageModel.symbol, "VAL")
        XCTAssertEqual(rows.compactMap { $0 as? ConfirmOptionsItem }.first?.toleranceText, "0.5%")
    }
    func testSupplyReviewDoesNotRoundATransferableAmountDownToZero() {
        let model = supply(amount: Decimal(string: "0.000000001")!)
        XCTAssertEqual(pair?.firstAssetImageModel.amountText, "0.000000001"); withExtendedLifetime(model) {}
    }
    func testRemoveReviewDoesNotRoundATransferableAmountDownToZero() {
        let model = remove(amount: Decimal(string: "0.000000001")!)
        XCTAssertEqual(pair?.firstAssetImageModel.amountText, "0.000000001"); withExtendedLifetime(model) {}
    }
    func testOnlyFirstSupplyToAPoolDisplaysThePoolWarning() {
        for type in [TransactionType.liquidityAdd, .liquidityAddNewPool, .liquidityAddToExistingPoolFirstTime] {
            let model = supply(type)
            XCTAssertEqual(rows.contains { $0 is WarningItem }, type != .liquidityAdd)
            withExtendedLifetime(model) {}
        }
    }
    func testRemovalReviewIncludesBothTokensAndSlippage() {
        let model = remove(); XCTAssertNotNil(model.title); XCTAssertNil(model.imageName)
        XCTAssertEqual(pair?.firstAssetImageModel.symbol, "XOR"); XCTAssertEqual(pair?.secondAssetImageModel.symbol, "VAL")
        XCTAssertEqual(rows.compactMap { $0 as? ConfirmOptionsItem }.first?.toleranceText, "0.5%")
        XCTAssertFalse(rows.contains { $0 is WarningItem })
    }
    private func descendants<T: UIView>(_ type: T.Type, in view: UIView) -> [T] {
        ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { descendants(type, in: $0) }
    }
    func testPairCellRebindingUpdatesBothSymbolsAndAmounts() throws {
        let model = supply(); let cell = ConfirmAssetsCell(style: .default, reuseIdentifier: nil)
        cell.set(item: try XCTUnwrap(pair), context: nil)
        let update = ConfirmAssetsItem(firstAssetImageModel: ConfirmAssetViewModel(imageViewModel: nil, amountText: "11", symbol: "PSWAP"),
            secondAssetImageModel: ConfirmAssetViewModel(imageViewModel: nil, amountText: "12", symbol: "VAL"), operationImageName: "roundPlus")
        cell.set(item: update, context: nil)
        let views = descendants(ConfirmAssetView.self, in: cell)
        XCTAssertEqual(views.map { $0.symbolLabel.text }, ["PSWAP", "VAL"])
        XCTAssertEqual(views.map { $0.amountLabel.text }, ["11", "12"])
        withExtendedLifetime(model) {}
    }
    func testOptionsCellClearsMarketWhenReusedForLiquidity() throws {
        let cell = ConfirmOptionsCell(style: .default, reuseIdentifier: nil)
        cell.set(item: ConfirmOptionsItem(toleranceText: "1%", market: .xyk), context: nil)
        let options = try XCTUnwrap(descendants(OptionsView.self, in: cell).first)
        XCTAssertFalse(options.marketButton.isHidden)
        cell.set(item: ConfirmOptionsItem(toleranceText: "0.5%"), context: nil)
        XCTAssertTrue(options.marketButton.isHidden); XCTAssertTrue(options.marketLabel.isHidden)
        XCTAssertEqual(options.slipageButton.sora.title, "0.5%")
    }
}
private final class ReviewPools: PoolsServiceInputProtocol {
    let state = PoolNetworkState(isPresented: false, isEnabled: false)
    let pool: PoolInfo? = nil

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
