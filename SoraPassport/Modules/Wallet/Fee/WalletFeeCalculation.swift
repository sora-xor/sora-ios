/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet

enum WalletFeeCalculationError: Error {
    case unexpectedFeeDescriptionContext
}

enum WalletFeeType: String {
    case fixed = "FIXED"
    case factor = "FACTOR"
}

typealias FeeIntermediateResult = (amount: Decimal, fee: Decimal)

struct WalletFeeCalculatorFactory: FeeCalculationFactoryProtocol {
    let xorPrecision: Int16
    let ethPrecision: Int16

    func createTransferFeeStrategyForDescriptions(_ feeDescriptions: [FeeDescription],
                                                  assetId: String,
                                                  precision: Int16) throws -> FeeCalculationStrategyProtocol {
        if
            let xorDescription = feeDescriptions.first(where: { $0.identifier == SoranetFeeId.transfer.rawValue }),
            let ethDescription = feeDescriptions
                .first(where: { $0.identifier == WalletNetworkConstants.ethFeeIdentifier }) {
            return SoranetFeeCalculationStrategy(xorDescription: xorDescription,
                                                 ethDescription: ethDescription,
                                                 xorPrecision: xorPrecision,
                                                 ethPrecision: ethPrecision)
        }

        if
            let xorDescription = feeDescriptions.first(where: { $0.identifier == SoranetFeeId.withdraw.rawValue }),
            let ethDescription = feeDescriptions
                .first(where: { $0.identifier == WalletNetworkConstants.ethFeeIdentifier }) {

            return EthereumFeeCalculationStrategy(xorDescription: xorDescription,
                                                  ethDescription: ethDescription,
                                                  xorPrecision: xorPrecision,
                                                  ethPrecision: ethPrecision)
        }

        return NoFeeCalculationStrategy()
    }
}

protocol WalletFeeCalculationStrategyProtocol: FeeCalculationStrategyProtocol {}

extension WalletFeeCalculationStrategyProtocol {
    func calculateForAmount(_ amount: Decimal,
                            feeDescription: FeeDescription,
                            decimalHandler: NSDecimalNumberHandler) throws -> FeeIntermediateResult {
        guard let feeType = WalletFeeType(rawValue: feeDescription.type) else {
            throw FeeCalculationError.unknownFeeType
        }

        switch feeType {
        case .fixed:
            return try calculateFixedFeeForAmount(amount,
                                                  feeDescription: feeDescription,
                                                  decimalHandler: decimalHandler)
        case .factor:
            return try calculateFactorFeeForAmount(amount,
                                                   feeDescription: feeDescription,
                                                   decimalHandler: decimalHandler)
        }
    }

    private func calculateFixedFeeForAmount(_ amount: Decimal,
                                            feeDescription: FeeDescription,
                                            decimalHandler: NSDecimalNumberHandler) throws -> FeeIntermediateResult {

        guard let value = feeDescription.parameters.first?.decimalValue else {
            throw FeeCalculationError.invalidParameters
        }

        let feeNumber = NSDecimalNumber(decimal: value).rounding(accordingToBehavior: decimalHandler)
        let amountNumber = NSDecimalNumber(decimal: amount).rounding(accordingToBehavior: decimalHandler)

        return FeeIntermediateResult(amount: amountNumber.decimalValue, fee: feeNumber.decimalValue)
    }

    private func calculateFactorFeeForAmount(_ amount: Decimal,
                                             feeDescription: FeeDescription,
                                             decimalHandler: NSDecimalNumberHandler) throws -> FeeIntermediateResult {

        guard let rate = feeDescription.parameters.first?.decimalValue else {
            throw FeeCalculationError.invalidParameters
        }

        let amountNumber = NSDecimalNumber(decimal: amount).rounding(accordingToBehavior: decimalHandler)
        let feeNumber = NSDecimalNumber(decimal: rate).multiplying(by: amountNumber, withBehavior: decimalHandler)

        return FeeIntermediateResult(amount: amountNumber.decimalValue, fee: feeNumber.decimalValue)
    }

    func calculateERC20MintFee(_ feeDescription: FeeDescription, decimalHandler: NSDecimalNumberHandler) -> Decimal {
        calculateEthFee(gasLimit: feeDescription.parameters.mintGas,
                        gasPrice: feeDescription.parameters.gasPrice,
                        decimalHandler: decimalHandler)
    }

    func calculateERC20TransferFee(_ feeDescription: FeeDescription,
                                   decimalHandler: NSDecimalNumberHandler) -> Decimal {
        calculateEthFee(gasLimit: feeDescription.parameters.transferGas,
                        gasPrice: feeDescription.parameters.gasPrice,
                        decimalHandler: decimalHandler)
    }

    private func calculateEthFee(gasLimit: AmountDecimal,
                                 gasPrice: AmountDecimal,
                                 decimalHandler: NSDecimalNumberHandler) -> Decimal {
        NSDecimalNumber(decimal: gasLimit.decimalValue)
            .multiplying(by: NSDecimalNumber(decimal: gasPrice.decimalValue), withBehavior: decimalHandler)
            .decimalValue
    }
}

struct NoFeeCalculationStrategy: WalletFeeCalculationStrategyProtocol {
    func calculate(for amount: Decimal) throws -> FeeCalculationResult {
        return FeeCalculationResult(sending: amount, fees: [], total: amount)
    }
}

struct SoranetFeeCalculationStrategy: WalletFeeCalculationStrategyProtocol {
    let xorDescription: FeeDescription
    let ethDescription: FeeDescription
    let xorDecimalHandler: NSDecimalNumberHandler
    let ethDecimalHandler: NSDecimalNumberHandler

    init(xorDescription: FeeDescription, ethDescription: FeeDescription, xorPrecision: Int16, ethPrecision: Int16) {
        self.xorDescription = xorDescription
        self.ethDescription = ethDescription
        self.xorDecimalHandler = NSDecimalNumberHandler.walletHandler(precision: xorPrecision)
        self.ethDecimalHandler = NSDecimalNumberHandler.walletHandler(precision: ethPrecision)
    }

    func calculate(for amount: Decimal) throws -> FeeCalculationResult {
        if xorDescription.context?[WalletOperationContextKey.Receiver.isMine] != nil {
            return try calculateTransferToMyAccount(amount)
        } else {
            return try calculateTransferToOtherAccount(amount)
        }
    }

    private func calculateTransferToMyAccount(_ amount: Decimal) throws -> FeeCalculationResult {
        let ethFeeValue = calculateERC20TransferFee(ethDescription, decimalHandler: ethDecimalHandler)

        let fees: [Fee]

        if ethFeeValue > 0 {
            let ethFee = Fee(value: AmountDecimal(value: ethFeeValue), feeDescription: ethDescription)
            fees = [ethFee]
        } else {
            fees = []
        }

        return FeeCalculationResult(sending: amount,
                                    fees: fees,
                                    total: amount)
    }

    private func calculateTransferToOtherAccount(_ amount: Decimal) throws -> FeeCalculationResult {
        let balances = TokenBalancesData(balanceContext: xorDescription.context ?? [:])

        let soranetTransferResult = try calculateForAmount(amount,
                                                           feeDescription: xorDescription,
                                                           decimalHandler: xorDecimalHandler)

        if soranetTransferResult.amount + soranetTransferResult.fee <= balances.soranet {
            let fees: [Fee]

            if soranetTransferResult.fee > 0 {
                let fee = Fee(value: AmountDecimal(value: soranetTransferResult.fee), feeDescription: xorDescription)
                fees = [fee]
            } else {
                fees = []
            }

            return FeeCalculationResult(sending: soranetTransferResult.amount,
                                        fees: fees,
                                        total: soranetTransferResult.amount + soranetTransferResult.fee)
        }

        let ethFeeValue = calculateERC20TransferFee(ethDescription, decimalHandler: ethDecimalHandler)

        var fees: [Fee] = []

        if ethFeeValue > 0 {
            let ethFee = Fee(value: AmountDecimal(value: ethFeeValue), feeDescription: ethDescription)
            fees.append(ethFee)
        }

        if soranetTransferResult.fee > 0 {
            let soranetFee = Fee(value: AmountDecimal(value: soranetTransferResult.fee), feeDescription: xorDescription)
            fees.append(soranetFee)
        }

        return FeeCalculationResult(sending: soranetTransferResult.amount,
                                    fees: fees,
                                    total: soranetTransferResult.amount + soranetTransferResult.fee)
    }
}

struct EthereumFeeCalculationStrategy: WalletFeeCalculationStrategyProtocol {
    let xorDescription: FeeDescription
    let ethDescription: FeeDescription
    let xorDecimalHandler: NSDecimalNumberHandler
    let ethDecimalHandler: NSDecimalNumberHandler

    init(xorDescription: FeeDescription,
         ethDescription: FeeDescription,
         xorPrecision: Int16,
         ethPrecision: Int16) {
        self.xorDescription = xorDescription
        self.ethDescription = ethDescription
        self.xorDecimalHandler = NSDecimalNumberHandler.walletHandler(precision: xorPrecision)
        self.ethDecimalHandler = NSDecimalNumberHandler.walletHandler(precision: ethPrecision)
    }

    func calculate(for amount: Decimal) throws -> FeeCalculationResult {
        if xorDescription.context?[WalletOperationContextKey.Receiver.isMine] != nil {
            return try calculateTransferToMyAccount(amount)
        } else {
            return try calculateTransferToOtherAccount(amount)
        }
    }

    private func calculateTransferToMyAccount(_ amount: Decimal) throws -> FeeCalculationResult {
        let transferResult = try calculateForAmount(amount,
                                                    feeDescription: xorDescription,
                                                    decimalHandler: xorDecimalHandler)

        let ethFeeValue = calculateERC20MintFee(ethDescription, decimalHandler: ethDecimalHandler)

        var fees: [Fee] = []

        if ethFeeValue > 0 {
            let mintFee = Fee(value: AmountDecimal(value: ethFeeValue), feeDescription: ethDescription)
            fees.append(mintFee)
        }

        if transferResult.fee > 0 {
            let transferFee = Fee(value: AmountDecimal(value: transferResult.fee), feeDescription: xorDescription)
            fees.append(transferFee)
        }

        return FeeCalculationResult(sending: transferResult.amount,
                                    fees: fees,
                                    total: transferResult.amount + transferResult.fee)
    }

    private func calculateTransferToOtherAccount(_ amount: Decimal) throws -> FeeCalculationResult {
        let balances = TokenBalancesData(balanceContext: xorDescription.context ?? [:])

        if amount <= balances.ethereum {
            let ethFeeValue = calculateERC20TransferFee(ethDescription, decimalHandler: ethDecimalHandler)

            var fees: [Fee] = []

            if ethFeeValue > 0 {
                let fee = Fee(value: AmountDecimal(value: ethFeeValue), feeDescription: ethDescription)
                fees.append(fee)
            }

            return FeeCalculationResult(sending: amount, fees: fees, total: amount)
        }

        let transferResult = try calculateForAmount(amount,
                                                    feeDescription: xorDescription,
                                                    decimalHandler: xorDecimalHandler)

        if transferResult.amount + transferResult.fee <= balances.soranet {
            let ethFeeValue = calculateERC20MintFee(ethDescription, decimalHandler: ethDecimalHandler)

            var fees: [Fee] = []

            if ethFeeValue > 0 {
                let mintFee = Fee(value: AmountDecimal(value: ethFeeValue), feeDescription: ethDescription)
                fees.append(mintFee)
            }

            if transferResult.fee > 0 {
                let transferFee = Fee(value: AmountDecimal(value: transferResult.fee), feeDescription: xorDescription)
                fees.append(transferFee)
            }

            return FeeCalculationResult(sending: transferResult.amount,
                                        fees: fees,
                                        total: transferResult.amount + transferResult.fee)
        }

        let ethTransferFeeValue = calculateERC20TransferFee(ethDescription, decimalHandler: ethDecimalHandler)

        let withdrawResult = try calculateForAmount(amount,
                                                    feeDescription: xorDescription,
                                                    decimalHandler: xorDecimalHandler)

        let ethMintFeeValue = calculateERC20MintFee(ethDescription, decimalHandler: ethDecimalHandler)

        var fees: [Fee] = []

        if ethTransferFeeValue + ethMintFeeValue > 0 {
            let ethFee = Fee(value: AmountDecimal(value: ethTransferFeeValue + ethMintFeeValue),
                             feeDescription: ethDescription)
            fees.append(ethFee)
        }

        if withdrawResult.fee > 0 {
            let withdrawFee = Fee(value: AmountDecimal(value: withdrawResult.fee), feeDescription: xorDescription)
            fees.append(withdrawFee)
        }

        return FeeCalculationResult(sending: withdrawResult.amount,
                                    fees: fees,
                                    total: withdrawResult.amount + withdrawResult.fee)
    }
}
