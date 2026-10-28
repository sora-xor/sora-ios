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
