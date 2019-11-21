/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
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
    case ambigious
    case notFound

    static func error(from status: StatusData) -> InvitationCheckDataError? {
        switch status.code {
        case "AMBIGUOUS_RESULT":
            return .ambigious
        case "INVITATION_CODE_NOT_FOUND":
            return .notFound
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

enum ApplyInvitationDataError: Error {
    case codeNotFound
    case wrongUserStatus
    case inviterRegisteredAfterInvitee
    case invitationAcceptingWindowClosed
    case parentAlreadyExists
    case selfInvitation
    case userNotFound

    static func error(from status: StatusData) -> ApplyInvitationDataError? {
        switch status.code {
        case "INVITATION_CODE_NOT_FOUND":
            return .codeNotFound
        case "WRONG_USER_STATUS":
            return .wrongUserStatus
        case "INVITER_REGISTERED_AFTER_INVITEE":
            return .inviterRegisteredAfterInvitee
        case "INVITATION_ACCEPTING_WINDOW_CLOSED":
            return .invitationAcceptingWindowClosed
        case "PARENT_ALREADY_EXISTS":
            return .parentAlreadyExists
        case "SELF_INVITATION":
            return .selfInvitation
        case "USER_NOT_FOUND":
            return .userNotFound
        default:
            return nil
        }
    }
}
