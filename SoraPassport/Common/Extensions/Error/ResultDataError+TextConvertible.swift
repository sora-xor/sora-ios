/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

extension ResultDataError: ErrorContentConvertible {
    func toErrorContent() -> ErrorContent {
        let message = R.string.localizable.serverErrorMessage()

        switch self {
        case .missingStatusField:
            return ErrorContent(title: R.string.localizable.resourceUnavailableErrorTitle(), message: message)
        case .unexpectedNumberOfFields:
            return ErrorContent(title: R.string.localizable.resultAmbiguousErrorTitle(), message: message)
        }
    }
}
