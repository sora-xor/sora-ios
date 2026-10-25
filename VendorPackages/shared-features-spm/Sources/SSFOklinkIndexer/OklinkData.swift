import Foundation

struct OklinkData: Codable {
    let page, limit, totalPage, chainFullName: String
    let chainShortName: String
    let transactionLists: [OklinkTransactionItem]
}
