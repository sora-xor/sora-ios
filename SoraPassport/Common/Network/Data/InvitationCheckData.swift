import Foundation

struct InvitationCheckData: Codable {
    enum CodingKeys: String, CodingKey {
        case code = "invitationCode"
    }

    let code: String?
}
