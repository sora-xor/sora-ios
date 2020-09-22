import XCTest
@testable import SoraPassport
import CommonWallet
import SoraKeystore
import SoraFoundation

class WalletSoranetFeeTransferTests: XCTestCase {

    func testXORtoXORTransfer() throws {
        // given

        let feeValue = AmountDecimal(value: 0.1)
        let tokens = TokenBalancesData(soranet: 200, ethereum: 200)
        let sending: Decimal = 100
        let ethBalance = AmountDecimal(value: 0.5)

        // when

        let strategy = try createStrategy(tokens: tokens,
                                          ethBalance: ethBalance,
                                          soranetFee: feeValue)

        let result = try strategy.calculate(for: sending)

        // then

        XCTAssertEqual(result.sending, sending)
        XCTAssertEqual(result.total, sending + feeValue.decimalValue)
        XCTAssertEqual(result.fees.count, 1)

        guard let xorFee = result.fees.first else {
            XCTFail("Unexpected fee")
            return
        }

        XCTAssertEqual(xorFee.value, feeValue)
        XCTAssertEqual(xorFee.feeDescription.identifier, SoranetFeeId.transfer.rawValue)
    }

    func testERC20toXORTransfer() throws {
        // given

        let feeValue = AmountDecimal(value: 0.1)
        let tokens = TokenBalancesData(soranet: 200, ethereum: 300)
        let sending: Decimal = 200
        let ethBalance = AmountDecimal(value: 0.5)

        // when

        let strategy = try createStrategy(tokens: tokens,
                                          ethBalance: ethBalance,
                                          soranetFee: feeValue)

        let result = try strategy.calculate(for: sending)

        // then

        XCTAssertEqual(result.sending, sending)
        XCTAssertEqual(result.total, sending + feeValue.decimalValue)
        XCTAssertEqual(result.fees.count, 2)

        guard let xorFee = result.fees.first(where: { $0.feeDescription.identifier == SoranetFeeId.transfer.rawValue }) else {
            XCTFail("Missing xor fee")
            return
        }

        XCTAssertEqual(xorFee.value, feeValue)

        guard let ethFee = result.fees
            .first(where: { $0.feeDescription.identifier == WalletNetworkConstants.ethFeeIdentifier }) else {
            XCTFail("Missing eth fee")
            return
        }

        let expectedFee = ethFee.feeDescription.parameters.transferGas.decimalValue *
            ethFee.feeDescription.parameters.gasPrice.decimalValue
        XCTAssertEqual(ethFee.value.decimalValue, expectedFee)
    }

    func testXORERC20toXORWhenUnsufficientBalanceInXOR() throws {
        // given

        let feeValue = AmountDecimal(value: 0.1)
        let tokens = TokenBalancesData(soranet: 200, ethereum: 200)
        let sending: Decimal = 300
        let ethBalance = AmountDecimal(value: 0.5)

        // when

        let strategy = try createStrategy(tokens: tokens,
                                          ethBalance: ethBalance,
                                          soranetFee: feeValue)

        let result = try strategy.calculate(for: sending)

        // then

        XCTAssertEqual(result.sending, sending)
        XCTAssertEqual(result.total, sending + feeValue.decimalValue)
        XCTAssertEqual(result.fees.count, 2)

        guard let xorFee = result.fees.first(where: { $0.feeDescription.identifier == SoranetFeeId.transfer.rawValue }) else {
            XCTFail("Missing xor fee")
            return
        }

        XCTAssertEqual(xorFee.value, feeValue)

        guard let ethFee = result.fees
            .first(where: { $0.feeDescription.identifier == WalletNetworkConstants.ethFeeIdentifier }) else {
            XCTFail("Missing eth fee")
            return
        }

        let expectedFee = ethFee.feeDescription.parameters.transferGas.decimalValue *
            ethFee.feeDescription.parameters.gasPrice.decimalValue
        XCTAssertEqual(ethFee.value.decimalValue, expectedFee)
    }

    func testXORERC20toXORWhenUnsufficientBalanceForFeeInXOR() throws {
        // given

        let feeValue = AmountDecimal(value: 0.1)
        let tokens = TokenBalancesData(soranet: 300, ethereum: 0.1)
        let sending: Decimal = 300
        let ethBalance = AmountDecimal(value: 0.5)

        // when

        let strategy = try createStrategy(tokens: tokens,
                                          ethBalance: ethBalance,
                                          soranetFee: feeValue)

        let result = try strategy.calculate(for: sending)

        // then

        XCTAssertEqual(result.sending, sending)
        XCTAssertEqual(result.total, sending + feeValue.decimalValue)
        XCTAssertEqual(result.fees.count, 2)

        guard let xorFee = result.fees.first(where: { $0.feeDescription.identifier == SoranetFeeId.transfer.rawValue }) else {
            XCTFail("Missing xor fee")
            return
        }

        XCTAssertEqual(xorFee.value, feeValue)

        guard let ethFee = result.fees
            .first(where: { $0.feeDescription.identifier == WalletNetworkConstants.ethFeeIdentifier }) else {
            XCTFail("Missing eth fee")
            return
        }

        let expectedFee = ethFee.feeDescription.parameters.transferGas.decimalValue *
            ethFee.feeDescription.parameters.gasPrice.decimalValue
        XCTAssertEqual(ethFee.value.decimalValue, expectedFee)
    }

    func testXORERC20toXORWhenUnsufficientFundsInTotal() throws {
        // given

        let feeValue = AmountDecimal(value: 0.1)
        let tokens = TokenBalancesData(soranet: 300, ethereum: 0.0)
        let sending: Decimal = 300
        let ethBalance = AmountDecimal(value: 0.5)

        // when

        let strategy = try createStrategy(tokens: tokens,
                                          ethBalance: ethBalance,
                                          soranetFee: feeValue)

        let result = try strategy.calculate(for: sending)

        // then

        XCTAssertEqual(result.sending, sending)
        XCTAssertEqual(result.total, sending + feeValue.decimalValue)
        XCTAssertEqual(result.fees.count, 2)

        guard let xorFee = result.fees.first(where: { $0.feeDescription.identifier == SoranetFeeId.transfer.rawValue }) else {
            XCTFail("Missing xor fee")
            return
        }

        XCTAssertEqual(xorFee.value, feeValue)

        guard let ethFee = result.fees
            .first(where: { $0.feeDescription.identifier == WalletNetworkConstants.ethFeeIdentifier }) else {
            XCTFail("Missing eth fee")
            return
        }

        let expectedFee = ethFee.feeDescription.parameters.transferGas.decimalValue *
            ethFee.feeDescription.parameters.gasPrice.decimalValue
        XCTAssertEqual(ethFee.value.decimalValue, expectedFee)
    }

    // MARK: Private

    private func createStrategy(tokens: TokenBalancesData,
                                ethBalance: AmountDecimal,
                                soranetFee: AmountDecimal) throws -> FeeCalculationStrategyProtocol {
        let primitiveFactory = WalletPrimitiveFactory(keychain: InMemoryKeychain(),
                                                      settings: InMemorySettingsManager(),
                                                      localizationManager: LocalizationManager.shared)

        let xorAsset = try primitiveFactory.createXORAsset()
        let ethAsset = try primitiveFactory.createETHAsset()

        let context: [String: String] = [
            WalletOperationContextKey.Balance.soranet: tokens.soranet.stringWithPointSeparator,
            WalletOperationContextKey.Balance.erc20: tokens.ethereum.stringWithPointSeparator
        ]

        let xorFeeDescription = FeeDescription(identifier: SoranetFeeId.transfer.rawValue,
                                               assetId: xorAsset.identifier,
                                               type: WalletFeeType.fixed.rawValue,
                                               parameters: [soranetFee],
                                               context: context)

        let ethParameters = EthFeeParameters(transferGas: AmountDecimal(value: Decimal(EthereumGasLimit.estimated.transfer)),
                                             mintGas: AmountDecimal(value: Decimal(EthereumGasLimit.estimated.mint)),
                                             gasPrice: AmountDecimal(value: 0.0000000001),
                                             balance: ethBalance)

        let ethFeeDescription = FeeDescription(identifier: WalletNetworkConstants.ethFeeIdentifier,
                                               assetId: ethAsset.identifier,
                                               type: WalletFeeType.fixed.rawValue,
                                               parameters: ethParameters)

        let feeFactory = WalletFeeCalculatorFactory(xorPrecision: xorAsset.precision,
                                                    ethPrecision: ethAsset.precision)

        return try feeFactory.createTransferFeeStrategyForDescriptions([xorFeeDescription, ethFeeDescription],
                                                                       assetId: xorAsset.identifier,
                                                                       precision: xorAsset.precision)
    }
}
