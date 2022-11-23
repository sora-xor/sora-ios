import Foundation

enum AccountCreateError: Error {
    case invalidMnemonicSize
    case invalidMnemonicFormat
    case invalidSeed
    case invalidKeystore
    case unsupportedNetwork
    case duplicated
}

extension AccountCreateError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let title: String
        let message: String

        switch self {
        case .invalidMnemonicSize:
            title = R.string.localizable.mnemonicInvalidTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable
                .accessRestoreWordsErrorMessage(preferredLanguages: locale?.rLanguages)
        case .invalidMnemonicFormat:
            title = R.string.localizable.mnemonicInvalidTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable
                .accessRestorePhraseErrorMessage(preferredLanguages: locale?.rLanguages)
        case .invalidSeed:
            title = R.string.localizable.commonErrorSeedIsNotValidTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable.commonErrorSeedIsNotValid(preferredLanguages: locale?.rLanguages)
        case .duplicated:
            title = R.string.localizable.accountAlreadyImported(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable.accountAlreadyImportedDescription(preferredLanguages: locale?.rLanguages)
        case .invalidKeystore, .unsupportedNetwork:
            title = R.string.localizable.accountImportDefaultError(preferredLanguages: locale?.rLanguages)
            message = "" // TODO: no design
        }

        return ErrorContent(title: title, message: message)
    }
}
