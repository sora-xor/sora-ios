/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import XCTest
@testable import SoraPassport
import CommonWallet
import SoraKeystore
import SoraFoundation

class WalletEthereumFeeTransferTests: XCTestCase {

    func testERC20toERC20Transfer() throws {
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
        XCTAssertEqual(result.total, sending)
        XCTAssertEqual(result.fees.count, 1)

        guard let ethFee = result.fees.first else {
            XCTFail("Unexpected fee")
            return
        }

        XCTAssertEqual(ethFee.feeDescription.identifier, WalletNetworkConstants.ethFeeIdentifier)

        let expectedFee = ethFee.feeDescription.parameters.transferGas.decimalValue *
            ethFee.feeDescription.parameters.gasPrice.decimalValue
        XCTAssertEqual(ethFee.value.decimalValue, expectedFee)
    }

    func testXORtoERC20TransferWhenUnsufficientFundsInERC20() throws {
        // given

        let feeValue = AmountDecimal(value: 0.1)
        let tokens = TokenBalancesData(soranet: 400, ethereum: 200)
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

        guard let ethFee = result.fees.first(where: { $0.feeDescription.identifier == WalletNetworkConstants.ethFeeIdentifier}) else {
            XCTFail("Unexpected eth fee")
            return
        }

        guard let xorFee = result.fees.first(where: { $0.feeDescription.identifier == SoranetFeeId.withdraw.rawValue }) else {
            XCTFail("Unexpected eth fee")
            return
        }

        XCTAssertEqual(xorFee.value.decimalValue, feeValue.decimalValue)

        let expectedFee = ethFee.feeDescription.parameters.mintGas.decimalValue *
            ethFee.feeDescription.parameters.gasPrice.decimalValue
        XCTAssertEqual(ethFee.value.decimalValue, expectedFee)
    }

    func testXORERC20toERC20TransferWhenUnsufficientFundsForFee() throws {
        // given

        let feeValue = AmountDecimal(value: 0.1)
        let tokens = TokenBalancesData(soranet: 300, ethereum: 200)
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

        guard let ethFee = result.fees.first(where: { $0.feeDescription.identifier == WalletNetworkConstants.ethFeeIdentifier}) else {
            XCTFail("Unexpected eth fee")
            return
        }

        guard let xorFee = result.fees.first(where: { $0.feeDescription.identifier == SoranetFeeId.withdraw.rawValue }) else {
            XCTFail("Unexpected eth fee")
            return
        }

        XCTAssertEqual(xorFee.value.decimalValue, feeValue.decimalValue)

        let expectedFee = (ethFee.feeDescription.parameters.mintGas.decimalValue +
            ethFee.feeDescription.parameters.transferGas.decimalValue) * ethFee.feeDescription.parameters.gasPrice.decimalValue
        XCTAssertEqual(ethFee.value.decimalValue, expectedFee)
    }

    func testXORERC20toERC20TransferWhenUnsufficientFundsInTotal() throws {
        // given

        let feeValue = AmountDecimal(value: 0.1)
        let tokens = TokenBalancesData(soranet: 0.1, ethereum: 299)
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

        guard let ethFee = result.fees.first(where: { $0.feeDescription.identifier == WalletNetworkConstants.ethFeeIdentifier}) else {
            XCTFail("Unexpected eth fee")
            return
        }

        guard let xorFee = result.fees.first(where: { $0.feeDescription.identifier == SoranetFeeId.withdraw.rawValue }) else {
            XCTFail("Unexpected eth fee")
            return
        }

        XCTAssertEqual(xorFee.value.decimalValue, feeValue.decimalValue)

        let expectedFee = (ethFee.feeDescription.parameters.mintGas.decimalValue +
            ethFee.feeDescription.parameters.transferGas.decimalValue) * ethFee.feeDescription.parameters.gasPrice.decimalValue
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

        let feeFactory = WalletFeeCalculatorFactory(xorPrecision: xorAsset.precision,
                                                    ethPrecision: ethAsset.precision)

        return try feeFactory.createTransferFeeStrategyForDescriptions([xorFeeDescription, ethFeeDescription],
                                                                       assetId: xorAsset.identifier,
                                                                       precision: xorAsset.precision)
    }

}
