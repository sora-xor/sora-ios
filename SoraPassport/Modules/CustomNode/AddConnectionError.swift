/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import IrohaCrypto

enum AddConnectionError: Error {
    case alreadyExists
    case invalidConnection
    case unsupportedChain(_ supported: [SNAddressType])
}

extension AddConnectionError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let message: String

        switch self {
        case .alreadyExists: break
            message = R.string.localizable.selectNodeAlreadyExist(preferredLanguages: locale?.rLanguages)
        case .invalidConnection: break
            message = ""
        case let .unsupportedChain(supported):
            let supported: String = supported
                .map { $0.titleForLocale(locale ?? Locale.current) }
                .joined(separator: ", ")

            message = ""
        }

        let title = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)

        return ErrorContent(title: title, message: "")
    }
}
