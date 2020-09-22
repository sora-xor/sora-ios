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
