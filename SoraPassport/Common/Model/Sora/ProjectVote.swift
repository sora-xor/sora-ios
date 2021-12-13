import Foundation

struct ProjectVote: Equatable, Codable {
    enum CodingKeys: String, CodingKey {
        case projectId
        case votes
    }

    var projectId: String
    var votes: String
}
