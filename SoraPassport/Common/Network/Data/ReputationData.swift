import Foundation

struct ReputationData: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case reputation
        case rank
        case ranksCount = "totalRank"
    }

    var reputation: String?
    var rank: UInt?
    var ranksCount: UInt?
}
