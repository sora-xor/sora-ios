import Foundation

struct LinkData: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case title
        case url = "link"
    }

    let title: String
    let url: URL
}
