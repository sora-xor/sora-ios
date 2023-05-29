import Foundation

struct UserServiceData: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case userId
        case serviceType
        case serviceId = "serviceDid"
    }

    var userId: String
    var serviceType: String
    var serviceId: String
}
