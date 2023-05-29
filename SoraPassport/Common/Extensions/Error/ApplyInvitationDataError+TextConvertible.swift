import Foundation

extension ApplyInvitationDataError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let title: String
        let message: String

        switch self {
        case .userNotFound:
            title = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable.userNotFoundMessage(preferredLanguages: locale?.rLanguages)
        case .wrongUserStatus:
            title = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable.userStatusInvalidMessage(preferredLanguages: locale?.rLanguages)
        case .codeNotFound:
            title = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable.personalInfoInvitationIsInvalid(preferredLanguages: locale?.rLanguages)
        case .invitationAcceptingWindowClosed:
            title = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable.inviteEnterErrorTimeIsUp(preferredLanguages: locale?.rLanguages)
        case .inviterRegisteredAfterInvitee:
            title = R.string.localizable
                .commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable
                .inviteCodeParentYoungMessage(preferredLanguages: locale?.rLanguages)
        case .parentAlreadyExists:
            title = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable
                .inviteEnterErrorAlreadyApplied(preferredLanguages: locale?.rLanguages)
        case .selfInvitation:
            title = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable.inviteCodeSelfMessage(preferredLanguages: locale?.rLanguages)
        }

        return ErrorContent(title: title, message: message)
    }
}
