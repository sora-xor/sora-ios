/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

extension DecentralizedDocumentCreationDataError: ErrorContentConvertible {
    func toErrorContent() -> ErrorContent {
        switch self {
        case .decentralizedIdDuplicated:
            return ErrorContent(title: R.string.localizable.didResolverIdDuplicatedErrorTitle(),
                                message: R.string.localizable.didResolverErrorMessage())
        case .decentralizedIdTooLong:
            return ErrorContent(title: R.string.localizable.didResolverIdTooLongErrorTitle(),
                                message: R.string.localizable.didResolverErrorMessage())
        case .invalidProof:
            return ErrorContent(title: R.string.localizable.didResolverInvalidProofFormatErrorTitle(),
                                message: R.string.localizable.didResolverErrorMessage())
        case .proofVerificationFailed:
            return ErrorContent(title: R.string.localizable.didResolverProofVerificationErrorTitle(),
                                message: R.string.localizable.didResolverErrorMessage())
        case .publicKeyNotFound:
            return ErrorContent(title: R.string.localizable.didResolverPublicKeyNotFoundErrorTitle(),
                                message: R.string.localizable.didResolverErrorMessage())
        }
    }
}
