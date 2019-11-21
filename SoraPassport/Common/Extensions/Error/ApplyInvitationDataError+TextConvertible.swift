/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

extension ApplyInvitationDataError: ErrorContentConvertible {
    func toErrorContent() -> ErrorContent {
        switch self {
        case .userNotFound:
            return ErrorContent(title: R.string.localizable.errorTitle(),
                                message: R.string.localizable.userNotFoundMessage())
        case .wrongUserStatus:
            return ErrorContent(title: R.string.localizable.errorTitle(),
                                message: R.string.localizable.userStatusInvalidMessage())
        case .codeNotFound:
            return ErrorContent(title: R.string.localizable.errorTitle(),
                                message: R.string.localizable.inviteCodeNotFoundMessage())
        case .invitationAcceptingWindowClosed:
            return ErrorContent(title: R.string.localizable.errorTitle(),
                                message: R.string.localizable.inviteCodeInputExpiredMessage())
        case .inviterRegisteredAfterInvitee:
            return ErrorContent(title: R.string.localizable.errorTitle(),
                                message: R.string.localizable.inviteCodeParentYoungMessage())
        case .parentAlreadyExists:
            return ErrorContent(title: R.string.localizable.errorTitle(),
                                message: R.string.localizable.inviteCodeParentExistsMessage())
        case .selfInvitation:
            return ErrorContent(title: R.string.localizable.errorTitle(),
                                message: R.string.localizable.inviteCodeSelfMessage())
        }
    }
}
