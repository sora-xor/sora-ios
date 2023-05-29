import Foundation

enum NotificationRegisterDataError: Error {
    case userAlreadyExists

    static func error(from status: StatusData) -> NotificationRegisterDataError? {
        switch status.code {
        case "CUSTOMER_ALREADY_EXIST":
            return .userAlreadyExists
        default:
            return nil
        }
    }
}

enum NotificationTokenExchangeDataError: Error {
    case userNotFound
    case tokenNotFound
    case tokenAlreadyExists

    static func error(from status: StatusData) -> NotificationTokenExchangeDataError? {
        switch status.code {
        case "CUSTOMER_NOT_FOUND":
            return .userNotFound
        case "TOKEN_NOT_FOUND":
            return .tokenNotFound
        case "TOKEN_ALREADY_EXIST":
            return .tokenAlreadyExists
        default:
            return nil
        }
    }
}

enum NotificationEnablePermissionsDataError: Error {
    case userNotFound

    static func error(from status: StatusData) -> NotificationEnablePermissionsDataError? {
        switch status.code {
        case "CUSTOMER_NOT_FOUND":
            return .userNotFound
        default:
            return nil
        }
    }
}
