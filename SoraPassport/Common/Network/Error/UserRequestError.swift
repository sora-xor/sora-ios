import Foundation

enum UserCreationError: Error {
    case alreadyExists
    case verified
    case invalid
    case unexpectedUser

    static func error(from status: StatusData) -> UserCreationError? {
        switch status.code {
        case "PHONE_ALREADY_REGISTERED":
            return .alreadyExists
        case "PHONE_ALREADY_VERIFIED":
            return .verified
        case "INCORRECT_QUERY_PARAMS":
            return .invalid
        case "WRONG_USER_STATUS":
            return .unexpectedUser
        default:
            return nil
        }
    }
}

enum RegistrationDataError: Error {
    case userNotFound
    case wrongUserStatus
    case invitationCodeNotFound

    static func error(from status: StatusData) -> RegistrationDataError? {
        switch status.code {
        case "USER_NOT_FOUND":
            return .userNotFound
        case "WRONG_USER_STATUS":
            return .wrongUserStatus
        case "INVITATION_CODE_NOT_FOUND":
            return .invitationCodeNotFound
        default:
            return nil
        }
    }
}

enum UserDataError: Error {
    case userNotFound
    case userValuesNotFound

    static func error(from status: StatusData) -> UserDataError? {
        switch status.code {
        case "USER_NOT_FOUND", "USER_NOT_REGISTERED":
            return .userNotFound
        case "USER_VALUES_NOT_FOUND":
            return .userValuesNotFound
        default:
            return nil
        }
    }
}

enum SmsCodeSendDataError: Error {
    case userNotFound
    case userValuesNotFound
    case tooFrequentRequest

    static func error(from status: StatusData) -> SmsCodeSendDataError? {
        switch status.code {
        case "USER_NOT_FOUND":
            return .userNotFound
        case "USER_VALUES_NOT_FOUND":
            return .userValuesNotFound
        case "TOO_FREQUENT_REQUEST":
            return .tooFrequentRequest
        default:
            return nil
        }
    }
}

enum SmsCodeVerifyDataError: Error {
    case userNotFound
    case smsCodeNotFound
    case smsCodeIncorrect
    case smsCodeExpired

    static func error(from status: StatusData) -> SmsCodeVerifyDataError? {
        switch status.code {
        case "USER_NOT_FOUND":
            return .userNotFound
        case "SMS_CODE_NOT_FOUND":
            return .smsCodeNotFound
        case "SMS_CODE_NOT_CORRECT":
            return .smsCodeIncorrect
        case "SMS_CODE_EXPIRED":
            return .smsCodeExpired
        default:
            return nil
        }
    }
}
