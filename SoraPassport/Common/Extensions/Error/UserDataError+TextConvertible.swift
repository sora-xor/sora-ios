import Foundation

extension UserDataError: ErrorContentConvertible {
    func toErrorContent() -> ErrorContent {
        switch self {
        case .userNotFound:
            return ErrorContent(title: R.string.localizable.errorTitle(),
                                message: R.string.localizable.userNotFoundMessage())
        case .userValuesNotFound:
            return ErrorContent(title: R.string.localizable.errorTitle(),
                                message: R.string.localizable.userValuesNotFoundMessage())
        }
    }
}

extension UserCreationError: ErrorContentConvertible {
    func toErrorContent() -> ErrorContent {
        switch self {
        case .alreadyExists:
            return ErrorContent(title: R.string.localizable.errorTitle(),
                                message: R.string.localizable.userCreatePhoneRegisteredErrorMessage())
        case .verified:
            return ErrorContent(title: R.string.localizable.errorTitle(),
                                message: R.string.localizable.userCreatePhoneVerifiedErrorMessage())
        case .invalid:
            return ErrorContent(title: R.string.localizable.errorTitle(),
                                message: R.string.localizable.userCreatePhoneInvalidMessage())
        case .unexpectedUser:
            return ErrorContent(title: R.string.localizable.errorTitle(),
                                message: R.string.localizable.userCreateUnexpectedMessage())
        }
    }
}
