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

extension DecentralizedDocumentCreationDataError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let title: String
        let message: String

        switch self {
        case .decentralizedIdDuplicated:
            title = R.string.localizable
                .didResolverIdDuplicatedErrorTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable
                .didResolverErrorMessage(preferredLanguages: locale?.rLanguages)
        case .decentralizedIdTooLong:
            title = R.string.localizable
                .didResolverIdTooLongErrorTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable.didResolverErrorMessage(preferredLanguages: locale?.rLanguages)
        case .invalidProof:
            title = R.string.localizable
                .didResolverInvalidProofFormatErrorTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable.didResolverErrorMessage(preferredLanguages: locale?.rLanguages)
        case .proofVerificationFailed:
            title = R.string.localizable
                .didResolverProofVerificationErrorTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable.didResolverErrorMessage(preferredLanguages: locale?.rLanguages)
        case .publicKeyNotFound:
            title = R.string.localizable
                .didResolverPublicKeyNotFoundErrorTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable.didResolverErrorMessage(preferredLanguages: locale?.rLanguages)
        }

        return ErrorContent(title: title, message: message)
    }
}
