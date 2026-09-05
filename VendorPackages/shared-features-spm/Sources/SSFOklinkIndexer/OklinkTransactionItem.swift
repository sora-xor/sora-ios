import Foundation

struct OklinkTransactionItem: Codable {
    let txID, methodID, blockHash, height: String
    let transactionTime, from, to: String
    let isFromContract, isToContract: Bool
    let amount, transactionSymbol, txFee, state: String
    let tokenID, tokenContractAddress, challengeStatus, l1OriginHash: String

    enum CodingKeys: String, CodingKey {
        case txID = "txId"
        case methodID = "methodId"
        case blockHash, height, transactionTime, from, to, isFromContract, isToContract, amount,
             transactionSymbol, txFee, state
        case tokenID = "tokenId"
        case tokenContractAddress, challengeStatus, l1OriginHash
    }
}
