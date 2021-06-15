import Foundation

struct DeviceInfo: Codable {
    enum CodingKeys: String, CodingKey {
        case model
        case osVersion
        case screenWidth
        case screenHeight
        case language
        case country
        case timezone
    }

    let model: String
    let osVersion: String
    let screenWidth: Int
    let screenHeight: Int
    let language: String
    let country: String
    let timezone: Int
}
