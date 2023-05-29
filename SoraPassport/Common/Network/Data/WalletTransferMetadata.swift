import Foundation

struct WalletTransferMetadata: Codable {
    let feeAccountId: String?
    let feeType: String
    let feeRate: Amount
}
