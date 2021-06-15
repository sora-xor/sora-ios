import Foundation

struct WithdrawProofData: Codable {
    enum CodingKeys: String, CodingKey {
        case proofId = "id"
        case timestamp = "txTime"
        case intentionHash = "irohaTxHash"
        case destination = "to"
        case block = "blockNum"
        case transactionIndex = "txIndex"
        case accountId = "accountIdToNotify"
        case tokenContractAddress = "tokenContractAddress"
        case amount
        case relay
        case proofs
    }

    let proofId: String
    let timestamp: Int64
    let intentionHash: String
    let destination: String
    let block: Int
    let transactionIndex: Int
    let accountId: String
    let tokenContractAddress: String
    let amount: String
    let relay: String
    let proofs: [EthereumSignature]
}
