import Foundation

struct VotesData: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case value = "votes"
        case lastReceived = "lastReceivedVotes"
    }

    var value: String
    var lastReceived: String?
}
