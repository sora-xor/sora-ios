import Foundation

enum ProjectDataStatus: String, Codable {
    case open = "OPEN"
    case failed = "FAILED"
    case closed = "COMPLETED"
}

struct ProjectData: Equatable, Codable {
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case favorite
        case favoriteCount
        case unwatched
        case name
        case description
        case imageLink
        case link = "projectLink"
        case fundingTarget
        case fundingCurrent
        case fundingDeadline
        case status
        case statusUpdateTime
        case votedFriendsCount
        case votes
    }

    var identifier: String
    var favorite: Bool
    var favoriteCount: Int32
    var unwatched: Bool
    var name: String
    var description: String?
    var imageLink: URL?
    var link: URL?
    var fundingTarget: String
    var fundingCurrent: String
    var fundingDeadline: Int64
    var status: ProjectDataStatus
    var statusUpdateTime: Int64
    var votedFriendsCount: Int32
    var votes: String
}

extension ProjectData {
    var isVoted: Bool {
        if let votesDecimal = Decimal(string: votes), votesDecimal > 0.0 {
            return true
        } else {
            return false
        }
    }
}
