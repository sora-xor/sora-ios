import Foundation
import CommonWallet
import BigInt

extension TransferInfo {
    var type: TransactionType {
        if let context = self.context,
           let type = context[TransactionContextKeys.transactionType] {
            return TransactionType(rawValue: type) ?? TransactionType.outgoing
        }
        return TransactionType.outgoing
    }

    var amountCall: [SwapVariant: SwapAmount]? {
        if type == .swap,
           let context = self.context,
           let raw = context[TransactionContextKeys.desire],
           let desire = SwapVariant(rawValue: raw),
           let estimated =  context[TransactionContextKeys.estimatedAmount],
           let estimatedAmount = AmountDecimal(string: estimated),
           let minMax = context[TransactionContextKeys.minMaxValue],
           let minMaxAmount = AmountDecimal(string: minMax) {
            let desired: BigUInt
            let slip: BigUInt
            switch desire {
            case .desiredInput:
                desired = self.amount.decimalValue.toSubstrateAmount(precision: 18) ?? 0
                slip = minMaxAmount.decimalValue.toSubstrateAmount(precision: 18) ?? 0
            case .desiredOutput:
                desired = estimatedAmount.decimalValue.toSubstrateAmount(precision: 18) ?? 0
                slip = self.amount.decimalValue.toSubstrateAmount(precision: 18) ?? 0
            }

            return [desire: SwapAmount(type: desire, desired: desired, slip:slip)]
        }
        return nil
    }
}
