/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

enum InformationDataError: Error {
    case sectionNotFound

    static func error(from status: StatusData) -> InformationDataError? {
        switch status.code {
        case "SECTION_NOT_FOUND":
            return .sectionNotFound
        default:
            return nil
        }
    }
}
