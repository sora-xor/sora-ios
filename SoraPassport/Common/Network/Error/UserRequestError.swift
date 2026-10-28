// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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
