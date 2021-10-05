import Foundation

struct ApplicationFormData: Codable {
    enum CodingKeys: String, CodingKey {
        case identifier = "uid"
        case firstName
        case lastName
        case phone
        case email
        case motivation
        case socialLinks
        case invitee = "invitedBy"
        case status
    }

    var identifier: String
    var firstName: String?
    var lastName: String?
    var phone: String?
    var email: String?
    var motivation: String?
    var socialLinks: [String]?
    var invitee: String?
    var status: String
}
