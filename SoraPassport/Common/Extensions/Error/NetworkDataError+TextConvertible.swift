/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

extension NetworkResponseError: ErrorContentConvertible {
    func toErrorContent() -> ErrorContent {
        switch self {
        case .authorizationError:
            return ErrorContent(title: R.string.localizable.authorizationErrorTitle(),
                                message: R.string.localizable.authorizationErrorMessage())
        case .internalServerError:
            return ErrorContent(title: R.string.localizable.internalServerErrorTitle(),
                                message: R.string.localizable.internalServerErrorMessage())
        case .invalidParameters:
            return ErrorContent(title: R.string.localizable.invalidParametersErrorTitle(),
                                message: R.string.localizable.invalidParametersErrorMessage())
        case .resourceNotFound:
            return ErrorContent(title: R.string.localizable.resourceUnavailableErrorTitle(),
                                message: R.string.localizable.resourceUnavailableErrorMessage())
        case .unexpectedStatusCode:
            return ErrorContent(title: R.string.localizable.unexpectedStatusErrorTitle(),
                                message: R.string.localizable.serverErrorMessage())
        }
    }
}
