import Foundation
import CommonWallet
import BigInt
import IrohaCrypto

extension AssetTransactionData {

    var direction: TransactionType {
        return TransactionType(rawValue: self.type)!
    }
}
