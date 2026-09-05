import Foundation

struct OklinkHistoryResponse: Codable {
    let code, msg: String
    let data: [OklinkData]
}
