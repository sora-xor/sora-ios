import Foundation
import CommonWallet

struct WalletWithdrawMetadata: Codable {
    let providerAccountId: String
    let feeAccountId: String?
    let feeType: String
    let feeRate: AmountDecimal
}
