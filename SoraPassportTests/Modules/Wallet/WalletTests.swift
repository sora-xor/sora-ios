import XCTest
@testable import SoraPassport
import SoraKeystore
import BigInt
import SoraFoundation

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

/// A swap has two assets, and each amount is in the units of its own asset.
/// With a fixed output the user enters the destination amount and the node
/// quotes the source amount; these tests use a source with 2 decimals and a
/// destination with 4 so that a mixed-up scale cannot pass.
final class SwapAmountPrecisionTests: XCTestCase {
    private let fromAssetId = "0x" + String(repeating: "01", count: 32)
    private let toAssetId = "0x" + String(repeating: "02", count: 32)
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

    // MARK: Quote

    func testFixedOutputQuoteScalesTheEnteredAmountByTheDestinationAndTheQuoteByTheSource() throws {
        let amounts = try XCTUnwrap(quoteAmounts(.desiredOutput, entered: "25000", quoted: "1001"))

        XCTAssertEqual(amounts.fromAmount, Decimal(string: "2.5"))
        XCTAssertEqual(amounts.toAmount, Decimal(string: "10.01"))
        // The decimals travel with the amounts, by asset and not by field.
        XCTAssertEqual(amounts.sourcePrecision, 2)
        XCTAssertEqual(amounts.destinationPrecision, 4)
    }

    func testFixedInputQuoteScalesTheEnteredAmountByTheSourceAndTheQuoteByTheDestination() throws {
        let amounts = try XCTUnwrap(quoteAmounts(.desiredInput, entered: "1001", quoted: "25000"))

        XCTAssertEqual(amounts.fromAmount, Decimal(string: "10.01"))
        XCTAssertEqual(amounts.toAmount, Decimal(string: "2.5"))
        XCTAssertEqual(amounts.sourcePrecision, 2)
        XCTAssertEqual(amounts.destinationPrecision, 4)
    }

    func testEqualDecimalsGiveTheSameQuoteAmountsInBothDirections() throws {
        for variant in [SwapVariant.desiredInput, .desiredOutput] {
            let amounts = try XCTUnwrap(
                quoteAmounts(
                    variant,
                    entered: "1000000000000000000",
                    quoted: "90872510487562233976",
                    sourcePrecision: 18,
                    destinationPrecision: 18
                )
            )

            XCTAssertEqual(amounts.fromAmount, 1, variant.rawValue)
            XCTAssertEqual(amounts.toAmount, Decimal(string: "90.872510487562233976"), variant.rawValue)
        }
    }

    func testQuoteWithDecimalsTheRuntimeCannotHoldOrMalformedUnitsHasNoAmounts() {
        for variant in [SwapVariant.desiredInput, .desiredOutput] {
            XCTAssertNil(quoteAmounts(variant, entered: "1", quoted: "1", sourcePrecision: 19))
            XCTAssertNil(quoteAmounts(variant, entered: "1", quoted: "1", destinationPrecision: 19))
            XCTAssertNil(quoteAmounts(variant, entered: "1.5", quoted: "1"))
            XCTAssertNil(quoteAmounts(variant, entered: "1", quoted: "-1"))
        }
    }

    // MARK: Rates shown on the swap and review screens

    func testFixedOutputDetailsShowSourcePerDestinationRatesAndTheMaximumSold() throws {
        let details = swapDetails(.desiredOutput, entered: Decimal(string: "2.5")!, quoted: 10)

        XCTAssertEqual(details.count, 5)
        XCTAssertEqual(details[0].title, SwapVariant.desiredOutput.title)
        XCTAssertEqual(details[0].assetAmountText.text, "10.05 FROM")
        XCTAssertEqual(details[1].title, "FROM / TO")
        XCTAssertEqual(details[1].assetAmountText.text, "4")
        XCTAssertEqual(details[2].title, "TO / FROM")
        XCTAssertEqual(details[2].assetAmountText.text, "0.25")
    }

    func testFixedInputDetailsShowTheSameRatesAndTheMinimumReceived() throws {
        let details = swapDetails(.desiredInput, entered: 10, quoted: Decimal(string: "2.5")!)

        XCTAssertEqual(details.count, 5)
        XCTAssertEqual(details[0].title, SwapVariant.desiredInput.title)
        XCTAssertEqual(details[0].assetAmountText.text, "2.4875 TO")
        XCTAssertEqual(details[1].title, "FROM / TO")
        XCTAssertEqual(details[1].assetAmountText.text, "4")
        XCTAssertEqual(details[2].title, "TO / FROM")
        XCTAssertEqual(details[2].assetAmountText.text, "0.25")
    }

    /// The limit a screen shows is the limit that is signed: whole units of
    /// its asset, the most sold rounded up and the least received rounded
    /// down.
    func testDetailsShowTheLimitInWholeUnitsOfItsAsset() throws {
        // 10.01 FROM quoted, 0.5 %: 10.06005, and FROM has two decimals.
        let fixedOutput = swapDetails(.desiredOutput, entered: Decimal(string: "2.5")!, quoted: Decimal(string: "10.01")!)
        XCTAssertEqual(fixedOutput[0].assetAmountText.text, "10.07 FROM")
        // 2.5001 TO quoted, 0.5 %: 2.4875995, and TO has four decimals.
        let fixedInput = swapDetails(.desiredInput, entered: Decimal(string: "10.01")!, quoted: Decimal(string: "2.5001")!)
        XCTAssertEqual(fixedInput[0].assetAmountText.text, "2.4875 TO")

        let slippage = PolkaswapSlippage.defaultValue
        XCTAssertEqual(slippage.maximumAmount(for: Decimal(string: "10.01")!, precision: 2), Decimal(string: "10.07"))
        XCTAssertEqual(slippage.minimumAmount(for: Decimal(string: "2.5001")!, precision: 4), Decimal(string: "2.4875"))
        XCTAssertEqual(slippage.maximumAmount(for: 10, precision: 2), Decimal(string: "10.05"))
        XCTAssertEqual(slippage.minimumAmount(for: 10, precision: 18), Decimal(string: "9.95"))
        XCTAssertEqual(slippage.minimumAmount(for: Decimal(string: "0.01")!, precision: 2), 0, "Less than one unit")
    }

    /// The rate labels were also reversed for a fixed output between two
    /// assets with 18 decimals each.
    /// NumberFormatter writes fifteen significant digits at most and rounds to the nearest there, whatever its
    /// rounding mode. Amounts are first rounded in exact decimal arithmetic: sold up, received down.
    func testWrittenAmountsAreNeverBetterThanTheSignedOnes() {
        func kept(_ value: String, _ fractionDigits: Int, up: Bool) -> Decimal {
            SwapAmountText.displayed(Decimal(string: value)!, fractionDigits: fractionDigits, roundingUp: up)
        }
        XCTAssertEqual(kept("1.000000000000000001", 18, up: true), Decimal(string: "1.00000000000001"))
        XCTAssertEqual(kept("1.23456789012345678", 18, up: false), Decimal(string: "1.23456789012345"))
        XCTAssertEqual(kept("12345678.123456789", 8, up: false), Decimal(string: "12345678.1234567"))
        XCTAssertEqual(kept("1.005000000000000002", 8, up: true), Decimal(string: "1.00500001"))
        XCTAssertEqual(kept("123456789012.123456789", 18, up: true), Decimal(string: "123456789012.124"))
        XCTAssertEqual(kept("0.0123456789012345678", 18, up: false), Decimal(string: "0.0123456789012345"))
        XCTAssertEqual(kept("0.000000000000000001", 18, up: false), Decimal(string: "0.000000000000000001"))
        XCTAssertEqual(kept("10.07", 8, up: true), Decimal(string: "10.07"))
        // Far beyond any chain amount, the search for the magnitude still ends.
        XCTAssertEqual(kept("1e100", 8, up: false), Decimal(string: "1e100"))
        XCTAssertEqual(kept("1e-100", 18, up: false), 0)
        let formatter = NumberFormatter.inputedAmoutFormatter(with: 18); formatter.locale = Locale(identifier: "en_US")
        XCTAssertEqual(SwapAmountText.string(Decimal(string: "1.000000000000000001")!, formatter: formatter, roundingUp: true), "1.00000000000001")
        XCTAssertEqual(SwapAmountText.string(Decimal(string: "1.23456789012345678")!, formatter: formatter, roundingUp: false), "1.23456789012345")
    }

    func testRatesKeepTheirDirectionWhenBothAssetsHaveEighteenDecimals() throws {
        for (variant, entered, quoted) in [(SwapVariant.desiredInput, Decimal(10), Decimal(string: "2.5")!),
                                           (.desiredOutput, Decimal(string: "2.5")!, Decimal(10))] {
            let details = swapDetails(
                variant,
                entered: entered,
                quoted: quoted,
                sourcePrecision: 18,
                destinationPrecision: 18
            )

            XCTAssertEqual(details[1].title, "FROM / TO", variant.rawValue)
            XCTAssertEqual(details[1].assetAmountText.text, "4", variant.rawValue)
            XCTAssertEqual(details[2].title, "TO / FROM", variant.rawValue)
            XCTAssertEqual(details[2].assetAmountText.text, "0.25", variant.rawValue)
        }
    }

    // MARK: Signed amounts

    func testFixedInputSignsTheInputInSourceUnitsAndTheMinimumOutputInDestinationUnits() throws {
        let info = swapInfo(.desiredInput, amount: "10.01", estimated: "2.5", limit: "2.4875")

        let amount = try XCTUnwrap(
            info.amountCall(sourcePrecision: 2, destinationPrecision: 4)?[.desiredInput]
        )

        XCTAssertEqual(amount.desired, BigUInt(1001))
        XCTAssertEqual(amount.slip, BigUInt(24875))
    }

    func testFixedOutputSignsTheOutputInDestinationUnitsAndTheMaximumInputInSourceUnits() throws {
        // 10.01 quoted, 0.5 % slippage: at most 10.06005, which two decimals
        // can only hold rounded up.
        let info = swapInfo(.desiredOutput, amount: "10.01", estimated: "2.5", limit: "10.06005")

        let amount = try XCTUnwrap(
            info.amountCall(sourcePrecision: 2, destinationPrecision: 4)?[.desiredOutput]
        )

        XCTAssertEqual(amount.desired, BigUInt(25000))
        XCTAssertEqual(amount.slip, BigUInt(1007))
    }

    /// The review submits the limit in whole units; the unrounded limit is
    /// still accepted. Both sign the same units, and no other limit is signed.
    func testTheLimitIsSignedFromEitherFormOfTheSameReviewedLimit() throws {
        for limit in ["10.06005", "10.07"] {
            let amount = try XCTUnwrap(
                swapInfo(.desiredOutput, amount: "10.01", estimated: "2.5", limit: limit)
                    .amountCall(sourcePrecision: 2, destinationPrecision: 4)?[.desiredOutput]
            )
            XCTAssertEqual(amount.desired, BigUInt(25000), limit)
            XCTAssertEqual(amount.slip, BigUInt(1007), limit)
        }
        for limit in ["2.4875995", "2.4875"] {
            let amount = try XCTUnwrap(
                swapInfo(.desiredInput, amount: "10.01", estimated: "2.5001", limit: limit)
                    .amountCall(sourcePrecision: 2, destinationPrecision: 4)?[.desiredInput]
            )
            XCTAssertEqual(amount.slip, BigUInt(24875), limit)
        }
        for limit in ["10.06", "10.08", "10.01", "100.7"] {
            XCTAssertNil(swapInfo(.desiredOutput, amount: "10.01", estimated: "2.5", limit: limit)
                .amountCall(sourcePrecision: 2, destinationPrecision: 4), limit)
        }
        for limit in ["2.4876", "2.4874", "2.5001"] {
            XCTAssertNil(swapInfo(.desiredInput, amount: "10.01", estimated: "2.5001", limit: limit)
                .amountCall(sourcePrecision: 2, destinationPrecision: 4), limit)
        }
    }

    func testMinimumOutputIsRoundedDownToTheDestinationUnits() throws {
        // 2.5001 estimated, 0.5 % slippage: at least 2.48759950.
        let info = swapInfo(.desiredInput, amount: "10.01", estimated: "2.5001", limit: "2.4875995")

        let amount = try XCTUnwrap(
            info.amountCall(sourcePrecision: 2, destinationPrecision: 4)?[.desiredInput]
        )

        XCTAssertEqual(amount.desired, BigUInt(1001))
        XCTAssertEqual(amount.slip, BigUInt(24875))
    }

    func testEqualDecimalsSignTheSameUnitsAsBefore() throws {
        let input = swapInfo(.desiredInput, amount: "1", estimated: "2", limit: "1.99")
        let output = swapInfo(.desiredOutput, amount: "1", estimated: "2", limit: "1.005")
        let unit = BigUInt(10).power(18)

        let fixedInput = try XCTUnwrap(
            input.amountCall(sourcePrecision: 18, destinationPrecision: 18)?[.desiredInput]
        )
        XCTAssertEqual(fixedInput.desired, unit)
        XCTAssertEqual(fixedInput.slip, unit * 199 / 100)

        let fixedOutput = try XCTUnwrap(
            output.amountCall(sourcePrecision: 18, destinationPrecision: 18)?[.desiredOutput]
        )
        XCTAssertEqual(fixedOutput.desired, unit * 2)
        XCTAssertEqual(fixedOutput.slip, unit * 1005 / 1000)
    }

    func testAFixedAmountTheAssetCannotHoldExactlyIsNotSigned() {
        // 10.015 of an asset with two decimals would be signed as 10.01.
        let input = swapInfo(.desiredInput, amount: "10.015", estimated: "2.5", limit: "2.4875")
        XCTAssertNil(input.amountCall(sourcePrecision: 2, destinationPrecision: 4))
        XCTAssertNotNil(input.amountCall(sourcePrecision: 3, destinationPrecision: 4))

        // 2.50001 of an asset with four decimals would be signed as 2.5.
        let output = swapInfo(.desiredOutput, amount: "10.01", estimated: "2.50001", limit: "10.06005")
        XCTAssertNil(output.amountCall(sourcePrecision: 2, destinationPrecision: 4))
        XCTAssertNotNil(output.amountCall(sourcePrecision: 2, destinationPrecision: 5))
    }

    func testDecimalsTheRuntimeCannotHoldAreNotSigned() {
        let info = swapInfo(.desiredInput, amount: "10.01", estimated: "2.5", limit: "2.4875")

        XCTAssertNil(info.amountCall(sourcePrecision: 19, destinationPrecision: 4))
        XCTAssertNil(info.amountCall(sourcePrecision: 2, destinationPrecision: 19))
        XCTAssertNil(info.amountCall(sourcePrecision: -1, destinationPrecision: 4))
        XCTAssertNil(info.amountCall(sourcePrecision: 2, destinationPrecision: -1))
    }

    func testSwapDecimalsComeFromTheAccountAssetsWithPredefinedAssetsPinned() throws {
        let xor = WalletAssetId.xor.rawValue
        let assets = [walletAsset(fromAssetId, precision: 2), walletAsset(toAssetId, precision: 4),
                      // A node could report 6 decimals for XOR; the runtime's 18 are used.
                      walletAsset(xor, precision: 6), walletAsset("unholdable", precision: 19)]
        func precisions(_ source: String, _ destination: String, reviewed: (Int, Int)?) -> SwapAssetPrecisions? {
            SwapAssetPrecisions(info: swapInfo(.desiredInput, amount: "1", estimated: "2", limit: "1.99",
                                               source: source, destination: destination, reviewed: reviewed), assets: assets)
        }

        XCTAssertEqual(precisions(fromAssetId, toAssetId, reviewed: (2, 4)), SwapAssetPrecisions(source: 2, destination: 4))
        XCTAssertEqual(precisions(toAssetId, fromAssetId, reviewed: (4, 2)), SwapAssetPrecisions(source: 4, destination: 2))
        XCTAssertEqual(precisions(xor, toAssetId, reviewed: (18, 4)), SwapAssetPrecisions(source: 18, destination: 4))
        XCTAssertEqual(precisions(fromAssetId, xor, reviewed: (2, 18)), SwapAssetPrecisions(source: 2, destination: 18))
        XCTAssertNil(precisions(fromAssetId, fromAssetId, reviewed: (2, 2)))
        XCTAssertNil(precisions(fromAssetId, "unlisted", reviewed: (2, 4)))
        XCTAssertNil(precisions("unlisted", toAssetId, reviewed: (2, 4)))
        XCTAssertNil(precisions(fromAssetId, "unholdable", reviewed: (2, 19)))
        // The signer signs only with the decimals the review used.
        XCTAssertNil(precisions(fromAssetId, toAssetId, reviewed: (4, 4)), "Reviewed with other decimals for the source")
        XCTAssertNil(precisions(fromAssetId, toAssetId, reviewed: (2, 2)), "Reviewed with other decimals for the destination")
        XCTAssertNil(precisions(xor, toAssetId, reviewed: (6, 4)), "A review that took a node's 6 decimals for XOR")
        XCTAssertNil(precisions(fromAssetId, toAssetId, reviewed: nil), "A swap that does not name its reviewed decimals")
    }

    // MARK: Helpers

    private func quoteAmounts(
        _ variant: SwapVariant,
        entered: String,
        quoted: String,
        sourcePrecision: UInt32 = 2,
        destinationPrecision: UInt32 = 4
    ) -> SwapQuoteAmounts? {
        SwapQuoteAmountsFactory().createAmounts(
            fromAsset: asset(fromAssetId, precision: sourcePrecision, symbol: "FROM"),
            toAsset: asset(toAssetId, precision: destinationPrecision, symbol: "TO"),
            params: PolkaswapMainInteractorQuoteParams(
                fromAssetId: fromAssetId,
                toAssetId: toAssetId,
                amount: entered,
                swapVariant: variant,
                liquiditySources: [],
                filterMode: .disabled
            ),
            quote: SwapValues(amount: quoted, route: [fromAssetId, toAssetId])
        )
    }

    private func swapDetails(
        _ variant: SwapVariant,
        entered: Decimal,
        quoted: Decimal,
        sourcePrecision: UInt32 = 2,
        destinationPrecision: UInt32 = 4
    ) -> [DetailViewModel] {
        let fromAsset = asset(fromAssetId, precision: sourcePrecision, symbol: "FROM")
        let toAsset = asset(toAssetId, precision: destinationPrecision, symbol: "TO")
        return DetailViewModelFactory(assetManager: SwapPrecisionAssets(assets: [fromAsset, toAsset]))
            .createSwapViewModels(
                fromAsset: fromAsset,
                toAsset: toAsset,
                slippage: .defaultValue,
                amount: entered,
                quote: SwapQuoteAmounts(fromAmount: entered, toAmount: quoted),
                direction: variant,
                fiatData: [],
                swapFee: 0,
                route: "FROM → TO",
                viewModel: SwapPrecisionDetailsDelegate()
            )
    }

    private func swapInfo(
        _ variant: SwapVariant,
        amount: String,
        estimated: String,
        limit: String,
        source: String? = nil,
        destination: String? = nil,
        reviewed: (Int, Int)? = (2, 4)
    ) -> TransferInfo {
        var context = [
            TransactionContextKeys.transactionType: TransactionType.swap.rawValue,
            TransactionContextKeys.estimatedAmount: estimated,
            TransactionContextKeys.marketType: LiquiditySourceType.smart.rawValue,
            TransactionContextKeys.slippage: "0.5",
            TransactionContextKeys.desire: variant.rawValue,
            TransactionContextKeys.minMaxValue: limit,
            TransactionContextKeys.dex: "0"
        ]
        if let reviewed {
            context[TransactionContextKeys.sourcePrecision] = String(reviewed.0)
            context[TransactionContextKeys.destinationPrecision] = String(reviewed.1)
        }
        return TransferInfo(
            source: "",
            destination: destination ?? toAssetId,
            amount: AmountDecimal(string: amount)!,
            asset: source ?? fromAssetId,
            details: "",
            fees: [],
            context: context
        )
    }

    private func asset(_ id: String, precision: UInt32, symbol: String) -> AssetInfo {
        AssetInfo(id: id, symbol: symbol, chainId: "", precision: precision, icon: nil, displayName: symbol, visible: true)
    }

    private func walletAsset(_ id: String, precision: Int16) -> WalletAsset {
        WalletAsset(identifier: id, name: LocalizableResource { _ in id }, symbol: id, precision: precision)
    }
}

private final class SwapPrecisionDetailsDelegate: DetailViewModelDelegate {
    func networkFeeInfoButtonTapped() {}
    func swapFeeInfoButtonTapped() {}
    func minMaxReceivedInfoButtonTapped() {}
}

private final class SwapPrecisionAssets: AssetManagerProtocol {
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
