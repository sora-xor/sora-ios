import Foundation

struct ProjectDetailsData: Equatable, Codable {
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case title = "name"
        case annotation = "description"
        case discussionLink
        case favorite
        case favoriteCount
        case votedFriendsCount
        case details = "detailedDescription"
        case fundingTarget
        case fundingCurrent
        case fundingDeadline
        case imageLink
        case link = "projectLink"
        case email
        case gallery
        case status
        case statusUpdateTime
        case votes
    }

    var identifier: String
    var title: String
    var annotation: String
    var details: String?
    var discussionLink: LinkData?
    var favorite: Bool
    var favoriteCount: Int32
    var votedFriendsCount: Int32
    var fundingTarget: String
    var fundingCurrent: String
    var fundingDeadline: Int64
    var imageLink: URL?
    var link: URL?
    var email: String?
    var gallery: [MediaItemData]?
    var status: ProjectDataStatus
    var statusUpdateTime: Int64
    var votes: String
}

extension ProjectDetailsData {
    var isVoted: Bool {
        if let votesDecimal = Decimal(string: votes), votesDecimal > 0.0 {
            return true
        } else {
            return false
        }
    }
}
