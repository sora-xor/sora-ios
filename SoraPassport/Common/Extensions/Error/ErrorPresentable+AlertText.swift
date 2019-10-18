/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

typealias ErrorContent = (title: String, message: String)

protocol ErrorContentConvertible {
    func toErrorContent() -> ErrorContent
}

extension ErrorPresentable where Self: AlertPresentable {
    func present(error: Error, from view: ControllerBackedProtocol?) -> Bool {
        var optionalContent: ErrorContent?

        if let contentConvertibleError = error as? ErrorContentConvertible {
            optionalContent = contentConvertibleError.toErrorContent()
        }

        if error as? BaseOperationError != nil {
            optionalContent = ErrorContent(title: R.string.localizable.operationErrorTitle(),
                                           message: R.string.localizable.operationErrorMessage())
        }

        if (error as NSError).domain == NSURLErrorDomain {
            optionalContent = ErrorContent(title: R.string.localizable.connectionErrorTitle(),
                                           message: R.string.localizable.connectionErrorMessage())
        }

        guard let content = optionalContent else {
            return false
        }

        present(message: content.message, title: content.title, closeAction: R.string.localizable.close(), from: view)

        return true
    }
}
