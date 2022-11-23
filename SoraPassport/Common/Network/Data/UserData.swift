import Foundation

struct UserData: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case userId
        case firstName
        case lastName
        case username
        case inviteAcceptExpirationMoment
        case country
        case phone
        case parentId
        case status
        case services = "userServices"
        case values = "userValues"
    }

    var userId: String
    var firstName: String
    var lastName: String
    var username: String?
    var country: String?
    var phone: String?
    var inviteAcceptExpirationMoment: Int64?
    var parentId: String?
    var status: String?
    var services: [UserServiceData]?
    var values: UserValuesData
}

extension UserData {
    var canAcceptInvitation: Bool {
        guard parentId == nil else {
            return false
        }

        guard let inviteAcceptExpirationMoment = inviteAcceptExpirationMoment else {
            return true
        }

        return TimeInterval(inviteAcceptExpirationMoment) > Date().timeIntervalSince1970
    }

    var invitationExpirationInterval: TimeInterval? {
        guard parentId == nil, let moment = inviteAcceptExpirationMoment else {
            return nil
        }

        let currentTimestamp = Date().timeIntervalSince1970

        if TimeInterval(moment) > currentTimestamp {
            return TimeInterval(moment) - currentTimestamp
        } else {
            return nil
        }
    }
}
