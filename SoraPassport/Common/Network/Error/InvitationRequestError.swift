/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

enum InvitationCodeDataError: Error {
    case userValuesNotFound
    case notEnoughInvitations

    static func error(from status: StatusData) -> InvitationCodeDataError? {
        switch status.code {
        case "USER_VALUES_NOT_FOUND":
            return .userValuesNotFound
        case "NOT_ENOUGH_INVITATIONS":
            return .notEnoughInvitations
        default:
            return nil
        }
    }
}

enum InvitationCheckDataError: Error {
    case codeNotFound

    static func error(from status: StatusData) -> InvitationCheckDataError? {
        switch status.code {
        case "INVITATION_CODE_NOT_FOUND":
            return .codeNotFound
        default:
            return nil
        }
    }
}

enum InvitationMarkDataError: Error {
    case codeNotFound
    case userValuesNotFound
    case notEnoughInvitations

    static func error(from status: StatusData) -> InvitationMarkDataError? {
        switch status.code {
        case "INVITATION_CODE_NOT_FOUND":
            return .codeNotFound
        case "USER_VALUES_NOT_FOUND":
            return .userValuesNotFound
        case "NOT_ENOUGH_INVITATIONS":
            return .notEnoughInvitations
        default:
            return nil
        }
    }
}
