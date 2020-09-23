/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import XCTest
@testable import SoraPassport
import CommonWallet
import SoraKeystore
import SoraFoundation

class WalletSoranetTransferValidatorTests: XCTestCase {
    func testTransferValidationFromXORtoXOR() throws {
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

        XCTAssertEqual(transferInfo.amount.decimalValue, sending)

        XCTAssertEqual(transferInfo.fees.count, 1)

        guard let xorFee = transferInfo.fees.first else {
            XCTFail("Unexpected fee")
            return
        }

        XCTAssertEqual(xorFee.value, feeValue)
        XCTAssertEqual(xorFee.feeDescription.identifier, SoranetFeeId.transfer.rawValue)

        let sendingTokens = TokenBalancesData(sendingContext: transferInfo.context ?? [:])

        XCTAssertEqual(sendingTokens.soranet, sending)

        XCTAssertNotNil(transferInfo.context?[WalletOperationContextKey.SoranetTransfer.balance])
        XCTAssertNil(transferInfo.context?[WalletOperationContextKey.SoranetWithdraw.balance])
        XCTAssertNil(transferInfo.context?[WalletOperationContextKey.ERC20Transfer.balance])
        XCTAssertNil(transferInfo.context?[WalletOperationContextKey.ERC20Withdraw.balance])
    }

    func testTransferValidationFromERC20toXOR() throws {
        // given

               let feeValue = AmountDecimal(value: 0.1)
               let tokens = TokenBalancesData(soranet: 0, ethereum: 300)
               let sending: Decimal = 201
               let ethBalance = AmountDecimal(value: 0.5)

               // when

               let transferInfo = try performValidationSending(amount: sending,
                                                               tokens: tokens,
                                                               ethBalance: ethBalance,
                                                               soranetFee: feeValue)

               // then

               checkThatERC20toXOR(transferInfo: transferInfo, sending: sending, feeValue: feeValue)
    }

    func testTransferValidationFromXORERC20toXORWhenUnsufficientXOR() throws {
        // given

        let feeValue = AmountDecimal(value: 0.1)
        let tokens = TokenBalancesData(soranet: 200, ethereum: 300)
        let sending: Decimal = 201
        let ethBalance = AmountDecimal(value: 0.5)

        // when

        let transferInfo = try performValidationSending(amount: sending,
                                                        tokens: tokens,
                                                        ethBalance: ethBalance,
                                                        soranetFee: feeValue)

        // then

        checkThatXORERC20toXOR(transferInfo: transferInfo, sending: sending, feeValue: feeValue)
    }

    func testTransferValidationFromXORERC20toXORWhenUnsufficientFee() throws {
        // given

        let feeValue = AmountDecimal(value: 0.1)
        let tokens = TokenBalancesData(soranet: 200, ethereum: 300)
        let sending: Decimal = 200
        let ethBalance = AmountDecimal(value: 0.5)

        // when

        let transferInfo = try performValidationSending(amount: sending,
                                                        tokens: tokens,
                                                        ethBalance: ethBalance,
                                                        soranetFee: feeValue)

        // then

        checkThatXORERC20toXOR(transferInfo: transferInfo, sending: sending, feeValue: feeValue)
    }

    func testTransferValidationFromXORERC20toXOR() throws {
        // given

        let feeValue = AmountDecimal(value: 0.1)
        let tokens = TokenBalancesData(soranet: 200, ethereum: 200)
        let sending: Decimal = 200
        let ethBalance = AmountDecimal(value: 0.5)

        // when

        let transferInfo = try performValidationSending(amount: sending,
                                                        tokens: tokens,
                                                        ethBalance: ethBalance,
                                                        soranetFee: feeValue)

        // then

        checkThatXORERC20toXOR(transferInfo: transferInfo, sending: sending, feeValue: feeValue)
    }

    func testUnsufficientXORBalance() throws {
        // given

        let primitiveFactory = WalletPrimitiveFactory(keychain: InMemoryKeychain(),
                                                      settings: InMemorySettingsManager(),
                                                      localizationManager: LocalizationManager.shared)

        let xorAsset = try primitiveFactory.createXORAsset()

        let feeValue = AmountDecimal(value: 0.1)
        let tokens = TokenBalancesData(soranet: 200, ethereum: 1)
        let sending: Decimal = 201
        let ethBalance = AmountDecimal(value: 0.5)

        // when

        do {
            _ = try performValidationSending(amount: sending,
                                             tokens: tokens,
                                             ethBalance: ethBalance,
                                             soranetFee: feeValue)
            XCTFail("Unexpected unsufficient funds exception")
        } catch {
            if
                let validationError = error as? TransferValidatingError,
                case .unsufficientFunds(let assetId, let balance) = validationError {
                XCTAssertEqual(assetId, xorAsset.identifier)
                XCTAssertEqual(balance, tokens.soranet + tokens.ethereum)
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testUnsufficientETHBalance() throws {
        // given

        let primitiveFactory = WalletPrimitiveFactory(keychain: InMemoryKeychain(),
                                                      settings: InMemorySettingsManager(),
                                                      localizationManager: LocalizationManager.shared)

        let ethAsset = try primitiveFactory.createETHAsset()

        let feeValue = AmountDecimal(value: 0.1)
        let tokens = TokenBalancesData(soranet: 200, ethereum: 300)
        let sending: Decimal = 201
        let ethBalance = AmountDecimal(value: 0.000000000000000001)

        // when

        do {
            _ = try performValidationSending(amount: sending,
                                             tokens: tokens,
                                             ethBalance: ethBalance,
                                             soranetFee: feeValue)
            XCTFail("Unexpected unsufficient funds exception")
        } catch {
            if
                let validationError = error as? TransferValidatingError,
                case .unsufficientFunds(let assetId, let balance) = validationError {
                XCTAssertEqual(assetId, ethAsset.identifier)
                XCTAssertEqual(balance, ethBalance.decimalValue)
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    // MARK: Private

    private func checkThatERC20toXOR(transferInfo: TransferInfo,
                                        sending: Decimal,
                                        feeValue: AmountDecimal) {
        XCTAssertEqual(transferInfo.amount.decimalValue, sending)

        XCTAssertEqual(transferInfo.fees.count, 2)

        guard let xorFee = transferInfo.fees.first(where: { $0.feeDescription.identifier == SoranetFeeId.transfer.rawValue}) else {
            XCTFail("Missing xor fee")
            return
        }

        XCTAssertEqual(xorFee.value, feeValue)
        XCTAssertEqual(xorFee.feeDescription.identifier, SoranetFeeId.transfer.rawValue)

        guard let ethFee = transferInfo.fees
            .first(where: { $0.feeDescription.identifier == WalletNetworkConstants.ethFeeIdentifier }) else {
            XCTFail("Missing eth fee")
            return
        }

        let expectedFee = ethFee.feeDescription.parameters.transferGas.decimalValue *
            ethFee.feeDescription.parameters.gasPrice.decimalValue
        XCTAssertEqual(ethFee.value.decimalValue, expectedFee)

        let sendingTokens = TokenBalancesData(sendingContext: transferInfo.context ?? [:])

        XCTAssertEqual(sendingTokens.ethereum, sending + feeValue.decimalValue)
        XCTAssertEqual(sendingTokens.soranet, 0)

        XCTAssertNil(transferInfo.context?[WalletOperationContextKey.SoranetTransfer.balance])
        XCTAssertNil(transferInfo.context?[WalletOperationContextKey.SoranetWithdraw.balance])
        XCTAssertNil(transferInfo.context?[WalletOperationContextKey.ERC20Transfer.balance])
        XCTAssertNotNil(transferInfo.context?[WalletOperationContextKey.ERC20Withdraw.balance])
    }

    private func checkThatXORERC20toXOR(transferInfo: TransferInfo,
                                        sending: Decimal,
                                        feeValue: AmountDecimal) {
        XCTAssertEqual(transferInfo.amount.decimalValue, sending)

        XCTAssertEqual(transferInfo.fees.count, 2)

        guard let xorFee = transferInfo.fees.first(where: { $0.feeDescription.identifier == SoranetFeeId.transfer.rawValue}) else {
            XCTFail("Missing xor fee")
            return
        }

        XCTAssertEqual(xorFee.value, feeValue)
        XCTAssertEqual(xorFee.feeDescription.identifier, SoranetFeeId.transfer.rawValue)

        guard let ethFee = transferInfo.fees
            .first(where: { $0.feeDescription.identifier == WalletNetworkConstants.ethFeeIdentifier }) else {
            XCTFail("Missing eth fee")
            return
        }

        let expectedFee = ethFee.feeDescription.parameters.transferGas.decimalValue *
            ethFee.feeDescription.parameters.gasPrice.decimalValue
        XCTAssertEqual(ethFee.value.decimalValue, expectedFee)

        let sendingTokens = TokenBalancesData(sendingContext: transferInfo.context ?? [:])

        XCTAssertEqual(sendingTokens.ethereum + sendingTokens.soranet, sending + feeValue.decimalValue)

        XCTAssertNotNil(transferInfo.context?[WalletOperationContextKey.SoranetTransfer.balance])
        XCTAssertNil(transferInfo.context?[WalletOperationContextKey.SoranetWithdraw.balance])
        XCTAssertNil(transferInfo.context?[WalletOperationContextKey.ERC20Transfer.balance])
        XCTAssertNotNil(transferInfo.context?[WalletOperationContextKey.ERC20Withdraw.balance])
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
                                        destination: Constants.dummyOtherWalletAccountId,
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

}
