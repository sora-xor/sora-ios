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
        case .accessForbidden(let data):
            title = "403"
            message = R.string.localizable
                .commonErrorGeneralMessage(preferredLanguages: locale?.rLanguages)
        }

        return ErrorContent(title: title, message: message)
    }
}

extension NetworkResponseError: WalletErrorContentConvertible {
    public func toErrorContent(for locale: Locale?) -> WalletErrorContentProtocol {
        let errorContent: ErrorContent = toErrorContent(for: locale)
        return errorContent
    }
}
