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
