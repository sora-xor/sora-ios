import Foundation

struct AnnouncementData: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case timestamp = "publicationDate"
        case message
    }

    var timestamp: Int64
    var message: String
}
