/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import RobinHood

extension NetworkResponseError: ErrorContentConvertible {
    func toErrorContent() -> ErrorContent {
        let message = R.string.localizable.serverErrorMessage()

        switch self {
        case .authorizationError:
            return ErrorContent(title: R.string.localizable.authorizationErrorTitle(),
                                message: message)
        case .internalServerError:
            return ErrorContent(title: R.string.localizable.internalServerErrorTitle(),
                                message: message)
        case .invalidParameters:
            return ErrorContent(title: R.string.localizable.invalidParametersErrorTitle(),
                                message: message)
        case .resourceNotFound:
            return ErrorContent(title: R.string.localizable.resourceUnavailableErrorTitle(),
                                message: message)
        case .unexpectedStatusCode:
            return ErrorContent(title: R.string.localizable.unexpectedStatusErrorTitle(),
                                message: message)
        }
    }
}
