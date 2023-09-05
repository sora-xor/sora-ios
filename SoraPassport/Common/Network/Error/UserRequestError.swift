// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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
