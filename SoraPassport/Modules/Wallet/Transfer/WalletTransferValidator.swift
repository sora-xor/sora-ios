import Foundation
import CommonWallet

struct TransferAmountState {
    let soranetBalance: Decimal
    let erc20Balance: Decimal
    let sendingAmount: Decimal
    let feeAmount: Decimal

    var totalAmount: Decimal {
        sendingAmount + feeAmount
    }
}

struct WalletTransferValidator: TransferValidating {
    func validate(info: TransferInfo,
                  balances: [BalanceData],
                  metadata: TransferMetaData) throws -> TransferInfo {

        guard info.amount.decimalValue > 0 else {
            throw TransferValidatingError.zeroAmount
        }

        guard let sendingAssetBalance = balances.first(where: { $0.identifier == info.asset }) else {
            throw TransferValidatingError.missingBalance(assetId: info.asset)
        }

        let totalFee: Decimal = info.fees.reduce(Decimal(0)) { (result, fee) in
            if fee.feeDescription.assetId == info.asset {
                return result + fee.value.decimalValue
            } else {
                return result
            }
        }

        let totalAmount = info.amount.decimalValue + totalFee

        let isCurrentReceiver = metadata.feeDescriptions
            .first(where: { $0.context?[WalletOperationContextKey.Receiver.isMine] != nil }) != nil

        let totalBalance = TokenBalancesData(balanceContext: sendingAssetBalance.context ?? [:])

        let availableBalance: Decimal

        if isCurrentReceiver {
            if NSPredicate.ethereumAddress.evaluate(with: info.destination) {
                availableBalance = totalBalance.soranet
            } else {
                availableBalance = totalBalance.ethereum
            }
        } else {
            availableBalance = totalBalance.soranet + totalBalance.ethereum
        }

        guard totalAmount <= availableBalance else {
            throw TransferValidatingError.unsufficientFunds(assetId: info.asset,
                                                            available: availableBalance)
        }

        if
            let ethFee = info.fees
                .first(where: { $0.feeDescription.identifier == WalletNetworkConstants.ethFeeIdentifier}),
            ethFee.value.decimalValue > ethFee.feeDescription.parameters.balance.decimalValue {
            let available = ethFee.feeDescription.parameters.balance.decimalValue
            throw TransferValidatingError.unsufficientFunds(assetId: ethFee.feeDescription.assetId,
                                                            available: available)
        }

        let state = TransferAmountState(soranetBalance: totalBalance.soranet,
                                        erc20Balance: totalBalance.ethereum,
                                        sendingAmount: info.amount.decimalValue,
                                        feeAmount: totalFee)

        if isCurrentReceiver {
            return addingContextToMyAccount(transferInfo: info, amountState: state, metadata: metadata)
        } else {
            return addingContextToOtherAccount(transferInfo: info, amountState: state, metadata: metadata)
        }
    }

    private func addingContextToOtherAccount(transferInfo: TransferInfo,
                                             amountState: TransferAmountState,
                                             metadata: TransferMetaData) -> TransferInfo {
        var context: [String: String] = transferInfo.context ?? [:]

        if NSPredicate.ethereumAddress.evaluate(with: transferInfo.destination) {
            if amountState.totalAmount <= amountState.erc20Balance {
                context[WalletOperationContextKey.ERC20Transfer.balance] =
                    amountState.sendingAmount.stringWithPointSeparator
            } else if amountState.totalAmount <= amountState.soranetBalance {
                context[WalletOperationContextKey.SoranetWithdraw.balance] =
                    amountState.sendingAmount.stringWithPointSeparator

                context[WalletOperationContextKey.SoranetWithdraw.provider] =
                    metadata.context?[WalletOperationContextKey.SoranetWithdraw.provider]
            } else {
                if amountState.erc20Balance > 0 {
                    context[WalletOperationContextKey.ERC20Transfer.balance] =
                        amountState.erc20Balance.stringWithPointSeparator
                }

                let remaining = amountState.sendingAmount - amountState.erc20Balance
                context[WalletOperationContextKey.SoranetWithdraw.balance] = remaining.stringWithPointSeparator

                context[WalletOperationContextKey.SoranetWithdraw.provider] =
                    metadata.context?[WalletOperationContextKey.SoranetWithdraw.provider]
            }
        } else {
            if amountState.totalAmount <= amountState.soranetBalance {
                context[WalletOperationContextKey.SoranetTransfer.balance] =
                    amountState.sendingAmount.stringWithPointSeparator
            } else if amountState.soranetBalance == 0 {
                context[WalletOperationContextKey.ERC20Withdraw.balance] =
                    amountState.totalAmount.stringWithPointSeparator
            } else {
                context[WalletOperationContextKey.SoranetTransfer.balance] =
                    amountState.soranetBalance.stringWithPointSeparator

                let remaining = amountState.totalAmount - amountState.soranetBalance
                context[WalletOperationContextKey.ERC20Withdraw.balance] = remaining.stringWithPointSeparator
            }
        }

        return TransferInfo(source: transferInfo.source,
                            destination: transferInfo.destination,
                            amount: transferInfo.amount,
                            asset: transferInfo.asset,
                            details: transferInfo.details,
                            fees: transferInfo.fees,
                            context: context)
    }

    private func addingContextToMyAccount(transferInfo: TransferInfo,
                                          amountState: TransferAmountState,
                                          metadata: TransferMetaData) -> TransferInfo {
        var context: [String: String] = transferInfo.context ?? [:]

        if NSPredicate.ethereumAddress.evaluate(with: transferInfo.destination) {
            context[WalletOperationContextKey.SoranetWithdraw.balance] =
                amountState.sendingAmount.stringWithPointSeparator

            context[WalletOperationContextKey.SoranetWithdraw.provider] =
                metadata.context?[WalletOperationContextKey.SoranetWithdraw.provider]
        } else {
            context[WalletOperationContextKey.ERC20Withdraw.balance] =
                amountState.totalAmount.stringWithPointSeparator
        }

        return TransferInfo(source: transferInfo.source,
                            destination: transferInfo.destination,
                            amount: transferInfo.amount,
                            asset: transferInfo.asset,
                            details: transferInfo.details,
                            fees: transferInfo.fees,
                            context: context)
    }
}
