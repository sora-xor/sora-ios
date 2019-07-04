/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

enum RegistrationDataError: Error {
    case applicationFormNotFound
    case invitationCodeNotFound

    static func error(from status: StatusData) -> RegistrationDataError? {
        switch status.code {
        case "APPLICATION_FORM_NOT_FOUND":
            return .applicationFormNotFound
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
        case "USER_NOT_FOUND":
            return .userNotFound
        case "USER_VALUES_NOT_FOUND":
            return .userValuesNotFound
        default:
            return nil
        }
    }
}

enum PersonalUpdateDataError: Error {
    case userNotFound

    static func error(from status: StatusData) -> PersonalUpdateDataError? {
        switch status.code {
        case "USER_NOT_FOUND":
            return .userNotFound
        default:
            return nil
        }
    }
}

enum VotesCountDataError: Error {
    case userNotFound

    static func error(from status: StatusData) -> VotesCountDataError? {
        switch status.code {
        case "USER_NOT_FOUND":
            return .userNotFound
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
