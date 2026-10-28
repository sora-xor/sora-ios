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

struct ErrorContent {
    let title: String
    let message: String
}

protocol ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent
}

extension ErrorPresentable where Self: AlertPresentable {
    func present(error: Swift.Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool {
        var optionalContent: ErrorContent?

        if let contentConvertibleError = error as? ErrorContentConvertible {
            optionalContent = contentConvertibleError.toErrorContent(for: locale)
        }

        if error as? BaseOperationError != nil {
            let title = R.string.localizable.operationErrorTitle(preferredLanguages: locale?.rLanguages)
            let message = R.string.localizable.operationErrorMessage(preferredLanguages: locale?.rLanguages)

            optionalContent = ErrorContent(title: title, message: message)
        }

        if (error as NSError).domain == NSURLErrorDomain {
            let title = R.string.localizable.connectionErrorTitle(preferredLanguages: locale?.rLanguages)
            let message = R.string.localizable.connectionErrorMessage(preferredLanguages: locale?.rLanguages)

            optionalContent = ErrorContent(title: title, message: message)
        }

        guard let content = optionalContent else {
            return false
        }

        let closeAction = R.string.localizable.commonOk(preferredLanguages: locale?.rLanguages)

        present(message: content.message, title: content.title, closeAction: closeAction, from: view)

        return true
    }
    
    func present(error: Swift.Error, from view: ControllerBackedProtocol?, locale: Locale?, completion: @escaping () -> Void) -> Bool {
        var optionalContent: ErrorContent?

        if let contentConvertibleError = error as? ErrorContentConvertible {
            optionalContent = contentConvertibleError.toErrorContent(for: locale)
        }

        if error as? BaseOperationError != nil {
            let title = R.string.localizable.operationErrorTitle(preferredLanguages: locale?.rLanguages)
            let message = R.string.localizable.operationErrorMessage(preferredLanguages: locale?.rLanguages)

            optionalContent = ErrorContent(title: title, message: message)
        }

        if (error as NSError).domain == NSURLErrorDomain {
            let title = R.string.localizable.connectionErrorTitle(preferredLanguages: locale?.rLanguages)
            let message = R.string.localizable.connectionErrorMessage(preferredLanguages: locale?.rLanguages)

            optionalContent = ErrorContent(title: title, message: message)
        }

        guard let content = optionalContent else {
            return false
        }

        let closeAction = R.string.localizable.commonOk(preferredLanguages: locale?.rLanguages)

        present(message: content.message, title: content.title, closeAction: closeAction, from: view, completion: completion)

        return true
    }
}
