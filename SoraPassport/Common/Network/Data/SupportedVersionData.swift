import Foundation

struct SupportedVersionData: Codable {
    enum CodingKeys: String, CodingKey {
        case supported = "result"
        case updateUrl = "url"
    }

    var supported: Bool
    var updateUrl: URL?
}
