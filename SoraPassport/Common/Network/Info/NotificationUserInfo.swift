import Foundation

struct NotificationUserInfo: Codable {
    enum CodingKeys: String, CodingKey {
        case tokens = "pushTokens"
        case allowedDecentralizedIds = "didsForPermit"
    }

    var tokens: [String]
    var allowedDecentralizedIds: [String]
}
