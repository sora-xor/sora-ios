import Foundation

extension ResultDataError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let message = R.string.localizable
            .commonErrorGeneralMessage(preferredLanguages: locale?.rLanguages)

        let title: String

        switch self {
        case .missingStatusField:
            title = R.string.localizable.commonErrorNotFoundTitle(preferredLanguages: locale?.rLanguages)
        case .unexpectedNumberOfFields:
            title = R.string.localizable.resultAmbiguousErrorTitle(preferredLanguages: locale?.rLanguages)
        }

        return ErrorContent(title: title, message: message)
    }
}
