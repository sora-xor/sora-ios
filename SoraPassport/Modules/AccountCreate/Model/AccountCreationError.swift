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
