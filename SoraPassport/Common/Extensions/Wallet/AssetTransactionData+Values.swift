import Foundation
import CommonWallet
import BigInt
import IrohaCrypto

extension AssetTransactionData {

    var transactionType: TransactionType {
        return TransactionType(rawValue: self.type) ?? TransactionType.extrinsic
    }
}
