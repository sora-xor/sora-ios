import Foundation

enum ReferendumDataStatus: String, Codable {
    case open = "CREATED"
    case rejected = "REJECTED"
    case accepted = "ACCEPTED"
}

struct ReferendumData: Equatable, Codable {
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case name
        case shortDescription = "description"
        case detailedDescription
        case fundingDeadline
        case statusUpdateTime
        case imageLink
        case status
        case supportVotes
        case opposeVotes
        case userSupportVotes
        case userOpposeVotes
    }

    let identifier: String
    let name: String
    let shortDescription: String
    let detailedDescription: String
    let fundingDeadline: Int64
    let statusUpdateTime: Int64
    let imageLink: URL?
    let status: ReferendumDataStatus
    let supportVotes: String
    let opposeVotes: String
    let userSupportVotes: String
    let userOpposeVotes: String
}
