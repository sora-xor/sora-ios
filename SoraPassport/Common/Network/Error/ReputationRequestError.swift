/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

enum ReputationDataError: Error {
    case userNotFound

    static func error(from status: StatusData) -> ReputationDataError? {
        switch status.code {
        case "USER_NOT_FOUND":
            return .userNotFound
        default:
            return nil
        }
    }
}
