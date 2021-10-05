import Foundation

struct ParentInfoData: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case userId
        case walletAccountId
        case timestamp = "registrationDate"
    }

    var userId: String
    var walletAccountId: String
    var timestamp: Int64
}

extension ParentInfoData {
    var registrationDate: Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp))
    }
}
