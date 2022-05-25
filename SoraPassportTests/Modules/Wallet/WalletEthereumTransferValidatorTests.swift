import XCTest
@testable import SoraPassport
import CommonWallet
import SoraKeystore
import SoraFoundation

class WalletEthereumTransferValidatorTests: XCTestCase {
/*
    func testTransferValidationFromERC20toERC20() throws {
        // given

        let feeValue = AmountDecimal(value: 0.1)
        let tokens = TokenBalancesData(soranet: 200, ethereum: 200)
        let sending: Decimal = 100
        let ethBalance = AmountDecimal(value: 0.5)

        // when

        let transferInfo = try performValidationSending(amount: sending,
                                                        tokens: tokens,
                                                        ethBalance: ethBalance,
                                                        soranetFee: feeValue)

        // then

        checkThatERC20toERC20(transferInfo: transferInfo, sending: AmountDecimal(value: sending))
    }

    func testTransferValidationFromXORtoERC20() throws {
        // given

        let feeValue = AmountDecimal(value: 0.1)
        let tokens = TokenBalancesData(soranet: 200, ethereum: 99)
        let sending: Decimal = 100
        let ethBalance = AmountDecimal(value: 0.5)

        // when

        let transferInfo = try performValidationSending(amount: sending,
                                                        tokens: tokens,
                                                        ethBalance: ethBalance,
                                                        soranetFee: feeValue)

        // then

        checkThatXORtoERC20(transferInfo: transferInfo, sending: AmountDecimal(value: sending), soranetFee: feeValue)
    }

    func testTransferValidationFromXORERC20toERC20() throws {
        // given

        let feeValue = AmountDecimal(value: 0.1)
        let tokens = TokenBalancesData(soranet: 2, ethereum: 99)
        let sending: Decimal = 100
        let ethBalance = AmountDecimal(value: 0.5)

        // when

        let transferInfo = try performValidationSending(amount: sending,
                                                        tokens: tokens,
                                                        ethBalance: ethBalance,
                                                        soranetFee: feeValue)

        // then

        checkThatXORERC20toERC20(transferInfo: transferInfo,
                                 sending: AmountDecimal(value: sending),
                                 soranetFee: feeValue)
    }


    // MARK: Private

    private func checkThatXORtoERC20(transferInfo: TransferInfo, sending: AmountDecimal, soranetFee: AmountDecimal) {
        XCTAssertEqual(transferInfo.amount, sending)
        XCTAssertEqual(transferInfo.fees.count, 2)

        guard let xorFee = transferInfo.fees
            .first(where: { $0.feeDescription.identifier == SoranetFeeId.withdraw.rawValue }) else {
            XCTFail("Missing xor fee")
            return
        }

        XCTAssertEqual(xorFee.value, soranetFee)

        guard let ethFee = transferInfo.fees
            .first(where: { $0.feeDescription.identifier == WalletNetworkConstants.ethFeeIdentifier}) else {
            XCTFail("Missing eth fee")
            return
        }

        let expectedFee = ethFee.feeDescription.parameters.mintGas.decimalValue *
            ethFee.feeDescription.parameters.gasPrice.decimalValue
        XCTAssertEqual(ethFee.value.decimalValue, expectedFee)

        let tokens = TokenBalancesData(sendingContext: transferInfo.context ?? [:])

        XCTAssertEqual(tokens.soranet, sending.decimalValue)

        XCTAssertNil(transferInfo.context?[WalletOperationContextKey.SoranetTransfer.balance])
        XCTAssertNotNil(transferInfo.context?[WalletOperationContextKey.SoranetWithdraw.balance])
        XCTAssertNil(transferInfo.context?[WalletOperationContextKey.ERC20Transfer.balance])
        XCTAssertNil(transferInfo.context?[WalletOperationContextKey.ERC20Withdraw.balance])
    }

    private func checkThatERC20toERC20(transferInfo: TransferInfo, sending: AmountDecimal) {
        XCTAssertEqual(transferInfo.amount, sending)
        XCTAssertEqual(transferInfo.fees.count, 1)

        guard let ethFee = transferInfo.fees.first else {
            XCTFail("Unexpected fee value")
            return
        }

        let expectedFee = ethFee.feeDescription.parameters.transferGas.decimalValue *
            ethFee.feeDescription.parameters.gasPrice.decimalValue
        XCTAssertEqual(ethFee.value.decimalValue, expectedFee)

        let tokens = TokenBalancesData(sendingContext: transferInfo.context ?? [:])

        XCTAssertEqual(tokens.ethereum, sending.decimalValue)

        XCTAssertNil(transferInfo.context?[WalletOperationContextKey.SoranetTransfer.balance])
        XCTAssertNil(transferInfo.context?[WalletOperationContextKey.SoranetWithdraw.balance])
        XCTAssertNotNil(transferInfo.context?[WalletOperationContextKey.ERC20Transfer.balance])
        XCTAssertNil(transferInfo.context?[WalletOperationContextKey.ERC20Withdraw.balance])
    }

    private func checkThatXORERC20toERC20(transferInfo: TransferInfo, sending: AmountDecimal, soranetFee: AmountDecimal) {
        XCTAssertEqual(transferInfo.amount, sending)
        XCTAssertEqual(transferInfo.fees.count, 2)

        guard let xorFee = transferInfo.fees
            .first(where: { $0.feeDescription.identifier == SoranetFeeId.withdraw.rawValue }) else {
            XCTFail("Missing xor fee")
            return
        }

        XCTAssertEqual(xorFee.value, soranetFee)

        guard let ethFee = transferInfo.fees
            .first(where: { $0.feeDescription.identifier == WalletNetworkConstants.ethFeeIdentifier}) else {
            XCTFail("Missing eth fee")
            return
        }

        let expectedFee = (ethFee.feeDescription.parameters.mintGas.decimalValue +
            ethFee.feeDescription.parameters.transferGas.decimalValue) *
            ethFee.feeDescription.parameters.gasPrice.decimalValue
        XCTAssertEqual(ethFee.value.decimalValue, expectedFee)

        let tokens = TokenBalancesData(sendingContext: transferInfo.context ?? [:])

        XCTAssertEqual(tokens.soranet + tokens.ethereum, sending.decimalValue)

        XCTAssertNil(transferInfo.context?[WalletOperationContextKey.SoranetTransfer.balance])
        XCTAssertNotNil(transferInfo.context?[WalletOperationContextKey.SoranetWithdraw.balance])
        XCTAssertNotNil(transferInfo.context?[WalletOperationContextKey.ERC20Transfer.balance])
        XCTAssertNil(transferInfo.context?[WalletOperationContextKey.ERC20Withdraw.balance])
    }

    private func performValidationSending(amount: Decimal,
                                          tokens: TokenBalancesData,
                                          ethBalance: AmountDecimal,
                                          soranetFee: AmountDecimal) throws -> TransferInfo {
        let primitiveFactory = WalletPrimitiveFactory(keychain: InMemoryKeychain(),
                                                      settings: InMemorySettingsManager(),
                                                      localizationManager: LocalizationManager.shared)

        let xorAsset = try primitiveFactory.createXORAsset()
        let ethAsset = try primitiveFactory.createETHAsset()

        let metadata = try createTransferMetadataFromTokens(tokens,
                                                            ethBalance: ethBalance,
                                                            soranetFee: soranetFee,
                                                            xorAsset: xorAsset,
                                                            ethAsset: ethAsset)

        let balances = try createBalancesFromTokens(tokens,
                                                    ethBalance: ethBalance,
                                                    xorAsset: xorAsset,
                                                    ethAsset: ethAsset)

        let feeResult = try calculateFeeForAmount(amount,
                                                  feeDescriptions: metadata.feeDescriptions,
                                                  xorAsset: xorAsset,
                                                  ethAsset: ethAsset)

        let transferInfo = TransferInfo(source: Constants.dummyWalletAccountId,
                                        destination: Constants.dummyEthAddress.soraHexWithPrefix,
                                        amount: AmountDecimal(value: amount),
                                        asset: xorAsset.identifier,
                                        details: "",
                                        fees: feeResult.fees)

        return try WalletTransferValidator().validate(info: transferInfo,
                                                      balances: balances,
                                                      metadata: metadata)
    }

    private func createBalancesFromTokens(_ tokens: TokenBalancesData,
                                          ethBalance: AmountDecimal,
                                          xorAsset: WalletAsset,
                                          ethAsset: WalletAsset) throws -> [BalanceData] {
        let context: [String: String] = [
            WalletOperationContextKey.Balance.soranet: tokens.soranet.stringWithPointSeparator,
            WalletOperationContextKey.Balance.erc20: tokens.ethereum.stringWithPointSeparator
        ]

        let xorBalance = BalanceData(identifier: xorAsset.identifier,
                                     balance: AmountDecimal(value: tokens.soranet + tokens.ethereum),
                                     context: context)

        let ethBalance = BalanceData(identifier: ethAsset.identifier,
                                     balance: ethBalance)

        return [xorBalance, ethBalance]
    }

    private func createTransferMetadataFromTokens(_ tokens: TokenBalancesData,
                                                  ethBalance: AmountDecimal,
                                                  soranetFee: AmountDecimal,
                                                  xorAsset: WalletAsset,
                                                  ethAsset: WalletAsset) throws -> TransferMetaData {
        let context: [String: String] = [
            WalletOperationContextKey.Balance.soranet: tokens.soranet.stringWithPointSeparator,
            WalletOperationContextKey.Balance.erc20: tokens.ethereum.stringWithPointSeparator
        ]

        let xorFeeDescription = FeeDescription(identifier: SoranetFeeId.withdraw.rawValue,
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

        return TransferMetaData(feeDescriptions: [xorFeeDescription, ethFeeDescription])
    }

    private func calculateFeeForAmount(_ amount: Decimal,
                                       feeDescriptions: [FeeDescription],
                                       xorAsset: WalletAsset,
                                       ethAsset: WalletAsset) throws -> FeeCalculationResult {
        let feeFactory = WalletFeeCalculatorFactory(xorPrecision: xorAsset.precision,
                                                    ethPrecision: ethAsset.precision)

        let strategy = try feeFactory.createTransferFeeStrategyForDescriptions(feeDescriptions,
                                                                               assetId: xorAsset.identifier,
                                                                               precision: xorAsset.precision)

        return try strategy.calculate(for: amount)
    }
 */
}
