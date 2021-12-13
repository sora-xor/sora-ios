import Foundation

extension UserDataError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let title: String
        let message: String

        switch self {
        case .userNotFound:
            title = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable.userNotFoundMessage(preferredLanguages: locale?.rLanguages)
        case .userValuesNotFound:
            title = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable.userValuesNotFoundMessage(preferredLanguages: locale?.rLanguages)
        }

        return ErrorContent(title: title, message: message)
    }
}

extension UserCreationError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let title: String
        let message: String

        switch self {
        case .alreadyExists:
            title = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)

            message = R.string.localizable
                .userCreatePhoneRegisteredErrorMessage(preferredLanguages: locale?.rLanguages)
        case .verified:
            title = R.string.localizable
                .commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)

            message = R.string.localizable
                .userCreatePhoneVerifiedErrorMessage(preferredLanguages: locale?.rLanguages)
        case .invalid:
            title = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable
                .userCreatePhoneInvalidMessage(preferredLanguages: locale?.rLanguages)
        case .unexpectedUser:
            title = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable
                .userCreateUnexpectedMessage(preferredLanguages: locale?.rLanguages)
        }

        return ErrorContent(title: title, message: message)
    }
}
