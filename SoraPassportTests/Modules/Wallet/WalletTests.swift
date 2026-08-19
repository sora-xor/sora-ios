import XCTest
@testable import SoraPassport
import SoraKeystore
import BigInt
import RobinHood
import sorawallet
import UIKit

class WalletTests: XCTestCase {
    private(set) var keystore = Keychain()
    private(set) var settings = SettingsManager.shared

    override func setUp() {
        try? keystore.deleteAll(for: "")
        settings.removeAll()
    }

    override func tearDown() {
        try? keystore.deleteAll(for: "")
        settings.removeAll()
    }
}

final class SwapTransactionTests: XCTestCase {
    private let fromAssetId = "0x" + String(repeating: "01", count: 32)
    private let toAssetId = "0x" + String(repeating: "02", count: 32)

    func testDesiredInputUsesMinimumOutputAndAssetPrecisions() throws {
        let info = makeSwapInfo(
            amount: "12.34",
            estimatedAmount: "99.5",
            minMaxAmount: "99.4999",
            variant: .desiredInput
        )

        let amount = try XCTUnwrap(
            info.amountCall(sourcePrecision: 2, destinationPrecision: 3)?[.desiredInput]
        )

        XCTAssertEqual(amount.desired, BigUInt(1234))
        XCTAssertEqual(amount.slip, BigUInt(99499))
    }

    func testDesiredOutputUsesSlippageMaximumAndRoundsInputUp() throws {
        let info = makeSwapInfo(
            amount: "10",
            estimatedAmount: "2.50",
            minMaxAmount: "10.001",
            variant: .desiredOutput
        )

        let amount = try XCTUnwrap(
            info.amountCall(sourcePrecision: 2, destinationPrecision: 2)?[.desiredOutput]
        )

        XCTAssertEqual(amount.desired, BigUInt(250))
        XCTAssertEqual(amount.slip, BigUInt(1001))
    }

    func testDesiredOutputQuoteUsesTargetForEnteredAndSourceForQuotedPrecision() throws {
        let fromAsset = makeAsset(id: fromAssetId, precision: 2)
        let toAsset = makeAsset(id: toAssetId, precision: 4)
        let params = PolkaswapMainInteractorQuoteParams(
            fromAssetId: fromAssetId,
            toAssetId: toAssetId,
            amount: "25000",
            swapVariant: .desiredOutput,
            liquiditySources: [],
            filterMode: .disabled
        )
        let quote = SwapValues(amount: "1001", route: [fromAssetId, toAssetId])

        let amounts = try XCTUnwrap(
            SwapQuoteAmountsFactory().createAmounts(
                fromAsset: fromAsset,
                toAsset: toAsset,
                params: params,
                quote: quote
            )
        )

        XCTAssertEqual(amounts.fromAmount, Decimal(string: "2.5"))
        XCTAssertEqual(amounts.toAmount, Decimal(string: "10.01"))
    }

    func testDesiredOutputDetailsKeepSourceTargetRateOrientation() throws {
        let fromAsset = makeAsset(id: fromAssetId, precision: 2, symbol: "FROM")
        let toAsset = makeAsset(id: toAssetId, precision: 4, symbol: "TO")
        let assetManager = SwapTestAssetManager(assets: [fromAsset, toAsset])
        let details = DetailViewModelFactory(assetManager: assetManager)
            .createSwapViewModels(
                fromAsset: fromAsset,
                toAsset: toAsset,
                slippage: 0.5,
                amount: 2.5,
                quote: SwapQuoteAmounts(fromAmount: 2.5, toAmount: 10),
                direction: .desiredOutput,
                fiatData: [],
                swapFee: 0,
                route: "FROM → TO",
                viewModel: SwapTestDetailsDelegate()
            )

        XCTAssertEqual(details[1].title, "FROM / TO")
        XCTAssertEqual(details[1].assetAmountText.text, "4")
        XCTAssertEqual(details[2].title, "TO / FROM")
        XCTAssertEqual(details[2].assetAmountText.text, "0.25")
    }

    func testUnavailableSignerStopsSwapBeforeWalletService() {
        let walletService = SwapTestWalletService()
        let wireframe = SwapTestConfirmWireframe()
        var recoveryPresentationCount = 0
        let viewModel = makeConfirmViewModel(
            walletService: walletService,
            wireframe: wireframe,
            signingAvailability: .recoveryRequired,
            signingRecoveryPresenter: { _ in recoveryPresentationCount += 1 }
        )

        viewModel.submit()

        XCTAssertEqual(walletService.transferCount, 0)
        XCTAssertEqual(wireframe.activityIndicatorCount, 0)
        XCTAssertEqual(wireframe.presentedAlertCount, 1)
        XCTAssertEqual(wireframe.presentedAlert?.actions.count, 1)
        XCTAssertEqual(wireframe.presentedAlert?.closeAction,
                       R.string.localizable.commonCancel(preferredLanguages: .currentLocale))

        wireframe.presentedAlert?.actions.first?.handler?()
        XCTAssertEqual(recoveryPresentationCount, 1)
    }

    func testAvailableSignerSubmitsSwapExactlyOnce() {
        let walletService = SwapTestWalletService()
        let wireframe = SwapTestConfirmWireframe()
        let viewModel = makeConfirmViewModel(
            walletService: walletService,
            wireframe: wireframe,
            signingAvailability: .available
        )

        viewModel.submit()

        XCTAssertEqual(walletService.transferCount, 1)
        XCTAssertEqual(wireframe.activityIndicatorCount, 1)
        XCTAssertEqual(wireframe.presentedAlertCount, 0)
    }

    private func makeSwapInfo(
        amount: String,
        estimatedAmount: String,
        minMaxAmount: String,
        variant: SwapVariant
    ) -> TransferInfo {
        TransferInfo(
            source: "",
            destination: toAssetId,
            amount: AmountDecimal(string: amount)!,
            asset: fromAssetId,
            details: "",
            fees: [],
            context: [
                TransactionContextKeys.transactionType: TransactionType.swap.rawValue,
                TransactionContextKeys.estimatedAmount: estimatedAmount,
                TransactionContextKeys.desire: variant.rawValue,
                TransactionContextKeys.minMaxValue: minMaxAmount
            ]
        )
    }

    private func makeAsset(
        id: String,
        precision: UInt32,
        symbol: String = "TEST"
    ) -> AssetInfo {
        AssetInfo(
            id: id,
            symbol: symbol,
            chainId: "",
            precision: precision,
            icon: nil,
            displayName: "Test",
            visible: true
        )
    }

    private func makeConfirmViewModel(
        walletService: SwapTestWalletService,
        wireframe: SwapTestConfirmWireframe,
        signingAvailability: WalletTransactionSigningAvailability,
        signingRecoveryPresenter: @escaping (UIViewController?) -> Void = { _ in }
    ) -> ConfirmSwapViewModel {
        let fromAsset = makeAsset(id: fromAssetId, precision: 18, symbol: "FROM")
        let toAsset = makeAsset(id: toAssetId, precision: 18, symbol: "TO")

        return ConfirmSwapViewModel(
            wireframe: wireframe,
            firstAssetId: fromAssetId,
            secondAssetId: toAssetId,
            assetManager: SwapTestAssetManager(assets: [fromAsset, toAsset]),
            eventCenter: EventCenter.shared,
            firstAssetAmount: 1,
            secondAssetAmount: 2,
            slippageTolerance: 0.5,
            details: [],
            market: .smart,
            amounts: SwapQuoteAmounts(fromAmount: 1, toAmount: 2),
            walletService: walletService,
            fee: 0.01,
            swapVariant: .desiredInput,
            minMaxValue: 1.99,
            dexId: 0,
            interactor: SwapTestInteractor(),
            quoteParams: PolkaswapMainInteractorQuoteParams(
                fromAssetId: fromAssetId,
                toAssetId: toAssetId,
                amount: "1000000000000000000",
                swapVariant: .desiredInput,
                liquiditySources: [],
                filterMode: .disabled
            ),
            assetsProvider: nil,
            fiatData: [],
            signingAvailabilityProvider: { signingAvailability },
            signingRecoveryPresenter: signingRecoveryPresenter
        )
    }
}

private final class SwapTestCancellableCall: CancellableCall {
    func cancel() {}
}

private final class SwapTestWalletService: WalletServiceProtocol {
    private(set) var transferCount = 0

    func fetchBalance(
        for assets: [String],
        runCompletionIn queue: DispatchQueue,
        completionBlock: @escaping BalanceCompletionBlock
    ) -> CancellableCall { SwapTestCancellableCall() }

    func fetchTransactionHistory(
        for filter: WalletHistoryRequest,
        pagination: Pagination,
        runCompletionIn queue: DispatchQueue,
        completionBlock: @escaping TransactionHistoryBlock
    ) -> CancellableCall { SwapTestCancellableCall() }

    func fetchTransferMetadata(
        for info: TransferMetadataInfo,
        runCompletionIn queue: DispatchQueue,
        completionBlock: @escaping TransferMetadataCompletionBlock
    ) -> CancellableCall { SwapTestCancellableCall() }

    func transfer(
        info: TransferInfo,
        runCompletionIn queue: DispatchQueue,
        completionBlock: @escaping DataResultCompletionBlock
    ) -> CancellableCall {
        transferCount += 1
        return SwapTestCancellableCall()
    }

    func search(
        for searchString: String,
        runCompletionIn queue: DispatchQueue,
        completionBlock: @escaping SearchCompletionBlock
    ) -> CancellableCall { SwapTestCancellableCall() }

    func fetchContacts(
        runCompletionIn queue: DispatchQueue,
        completionBlock: @escaping SearchCompletionBlock
    ) -> CancellableCall { SwapTestCancellableCall() }

    func fetchWithdrawalMetadata(
        for info: WithdrawMetadataInfo,
        runCompletionIn queue: DispatchQueue,
        completionBlock: @escaping WithdrawalMetadataCompletionBlock
    ) -> CancellableCall { SwapTestCancellableCall() }

    func withdraw(
        info: WithdrawInfo,
        runCompletionIn queue: DispatchQueue,
        completionBlock: @escaping DataResultCompletionBlock
    ) -> CancellableCall { SwapTestCancellableCall() }
}

private final class SwapTestConfirmWireframe: ConfirmWireframeProtocol {
    private(set) var activityIndicatorCount = 0
    private(set) var presentedAlertCount = 0
    private(set) var presentedAlert: AlertPresentableViewModel?

    func showActivityIndicator() { activityIndicatorCount += 1 }
    func hideActivityIndicator() {}

    func showActivityDetails(
        on controller: UIViewController?,
        model: Transaction,
        assetManager: AssetManagerProtocol,
        completion: (() -> Void)?
    ) {}

    func present(
        message: String?,
        title: String?,
        closeAction: String?,
        from view: ControllerBackedProtocol?
    ) {
        XCTFail("Signing failures must present a recovery action, not an OK-only message")
    }

    func present(
        viewModel: AlertPresentableViewModel,
        style: UIAlertController.Style,
        from view: ControllerBackedProtocol?
    ) {
        presentedAlertCount += 1
        presentedAlert = viewModel
    }
}

private final class SwapTestInteractor: PolkaswapMainInteractorInputProtocol {
    func networkFeeValue(completion: @escaping (Decimal) -> Void) {}
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

private final class SwapTestDetailsDelegate: DetailViewModelDelegate {
    func networkFeeInfoButtonTapped() {}
    func swapFeeInfoButtonTapped() {}
    func minMaxReceivedInfoButtonTapped() {}
}

private final class SwapTestAssetManager: AssetManagerProtocol {
    static var networkAssets: [AssetInfo] = []
    private var assets: [AssetInfo]

    init(assets: [AssetInfo]) {
        self.assets = assets
    }

    func assetInfo(for identifier: String) -> AssetInfo? {
        assets.first { $0.identifier == identifier }
    }

    func getAssetList() -> [AssetInfo]? { assets }
    func updateAssetList(_ list: [AssetInfo]) { assets = list }
    func saveAssetList(_ list: [AssetInfo]) { assets = list }
    func sortedAssets(_ list: [WalletAsset], onlyVisible: Bool) -> [WalletAsset] { list }
    func visibleCount() -> UInt { UInt(assets.filter(\.visible).count) }
    func setup(for accountSettings: SelectedWalletSettings) {}
}
