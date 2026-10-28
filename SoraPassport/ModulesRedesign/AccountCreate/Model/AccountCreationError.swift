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

enum AccountCreationError: Error {
    case unsupportedNetwork
    case invalidDerivationHardSoftPassword
    case invalidDerivationHardPassword
    case invalidDerivationHardSoft
    case invalidDerivationHard
}
//probably unneeded
extension AccountCreationError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let title: String
        let message: String

        switch self {
        case .unsupportedNetwork:
            title = R.string.localizable
                .commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)
            message = "commonUnsupportedNetworkMessage"//R.string.localizable
                //.commonUnsupportedNetworkMessage(preferredLanguages: locale?.rLanguages)
        case .invalidDerivationHardSoftPassword:
            title = "commonInvalidPathTitle"//R.string.localizable
                //.commonInvalidPathTitle(preferredLanguages: locale?.rLanguages)
            message = "commonInvalidPathWithSoftMessage"//R.string.localizable
                //.commonInvalidPathWithSoftMessage(preferredLanguages: locale?.rLanguages)
        case .invalidDerivationHardPassword:
            title = "commonInvalidPathTitle"//R.string.localizable
                //.commonInvalidPathTitle(preferredLanguages: locale?.rLanguages)
            message = "commonInvalidPathWithoutSoftMessage"//R.string.localizable
                //.commonInvalidPathWithoutSoftMessage(preferredLanguages: locale?.rLanguages)
        case .invalidDerivationHardSoft:
            title = "commonInvalidPathTitle"//R.string.localizable
                //.commonInvalidPathTitle(preferredLanguages: locale?.rLanguages)
            message = "commonInvalidHardSoftMessage"//R.string.localizable
                //.commonInvalidHardSoftMessage(preferredLanguages: locale?.rLanguages)
        case .invalidDerivationHard:
            title = "commonInvalidPathTitle"//R.string.localizable
                //.commonInvalidPathTitle(preferredLanguages: locale?.rLanguages)
            message = "commonInvalidHardMessage"//R.string.localizable
                //.commonInvalidHardMessage(preferredLanguages: locale?.rLanguages)
        }

        return ErrorContent(title: title, message: message)
    }
}
