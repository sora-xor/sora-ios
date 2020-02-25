/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

extension NetworkResponseError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let title: String
        let message: String

        switch self {
        case .authorizationError:
            title = R.string.localizable
                .commonErrorUnauthorizedTitle(preferredLanguages: locale?.rLanguages)

            message = R.string.localizable
                .commonErrorUnauthorizedBody(preferredLanguages: locale?.rLanguages)
        case .internalServerError:
            title = R.string.localizable
                .commonErrorInternalErrorTitle(preferredLanguages: locale?.rLanguages)

            message = R.string.localizable
                .commonErrorInternalErrorBody(preferredLanguages: locale?.rLanguages)
        case .invalidParameters:
            title = R.string.localizable
                .commonErrorInvalidParameters(preferredLanguages: locale?.rLanguages)

            message = R.string.localizable
                .commonErrorInvalidParametersBody(preferredLanguages: locale?.rLanguages)
        case .resourceNotFound:
            title = R.string.localizable
                .commonErrorNotFoundTitle(preferredLanguages: locale?.rLanguages)

            message = R.string.localizable
                .commonErrorNotFoundBody(preferredLanguages: locale?.rLanguages)
        case .unexpectedStatusCode:
            title = R.string.localizable
                .commonErrorUnexpectedStatusTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable
                .commonErrorGeneralMessage(preferredLanguages: locale?.rLanguages)
        }

        return ErrorContent(title: title, message: message)
    }
}
