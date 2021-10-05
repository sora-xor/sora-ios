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

        let fee = info.fees.first!

        guard let feeBalance = balances.first(where: { $0.identifier == fee.feeDescription.identifier}) else {
            throw TransferValidatingError.missingBalance(assetId: fee.feeDescription.identifier)
        }

        let totalFee: Decimal = info.fees.reduce(Decimal(0)) { (result, fee) in
            return result + fee.value.decimalValue
        }

        guard totalFee <= feeBalance.balance.decimalValue else {
            throw TransferValidatingError.unsufficientFunds(assetId: fee.feeDescription.identifier,
                                                            available: feeBalance.balance.decimalValue)
        }

        let balanceContext = BalanceContext(context: sendingAssetBalance.context ?? [:])

        let sendingAmount = info.amount.decimalValue
        let totalAmount =  sendingAssetBalance == feeBalance ? sendingAmount + totalFee : sendingAmount
        let availableBalance = balanceContext.available

        guard totalAmount <= availableBalance else {
            throw TransferValidatingError.unsufficientFunds(assetId: info.asset,
                                                            available: availableBalance)
        }

        let transferMetadataContext = TransferMetadataContext(context: metadata.context ?? [:])

        let receiverTotalAfterTransfer = transferMetadataContext.receiverBalance + sendingAmount
        let chain: Chain = .sora
        guard receiverTotalAfterTransfer >= chain.existentialDeposit() else {
            throw TransferValidatingError.unsufficientFunds(assetId: info.asset,
                                                                  available: availableBalance)
        }

        return TransferInfo(source: info.source,
                            destination: info.destination,
                            amount: info.amount,
                            asset: info.asset,
                            details: info.details,
                            fees: info.fees,
                            context: balanceContext.toContext())
    }

}
