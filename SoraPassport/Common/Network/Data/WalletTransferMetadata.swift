import Foundation
import CommonWallet

struct WalletTransferMetadata: Codable {
    let feeAccountId: String?
    let feeType: String
    let feeRate: AmountDecimal
}
