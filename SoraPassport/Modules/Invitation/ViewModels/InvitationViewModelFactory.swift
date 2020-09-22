import Foundation
import SoraFoundation

protocol InvitationViewModelFactoryProtocol: class {
    func createActionListViewModel(from userData: UserData?,
                                   parentInfo: ParentInfoData?,
                                   layout: InvitationViewLayout,
                                   locale: Locale) -> InvitationActionListViewModel
    func createActionAccessory(from remainedInterval: TimeInterval,
                               notificationInterval: TimerNotificationInterval) -> String
    func createActivatedInvitationViewModel(from data: ActivatedInvitationsData) -> [InvitedViewModel]
}

class InvitationViewModelFactory: InvitationViewModelFactoryProtocol {
    let integerFormatter: LocalizableResource<NumberFormatter>

    init(integerFormatter: LocalizableResource<NumberFormatter>) {
        self.integerFormatter = integerFormatter
    }

    func createActionListViewModel(from userData: UserData?,
                                   parentInfo: ParentInfoData?,
                                   layout: InvitationViewLayout,
                                   locale: Locale) -> InvitationActionListViewModel {
        let headerText = R.string.localizable.inviteTitle(preferredLanguages: locale.rLanguages)

        var actions: [InvitationActionViewModel] = []

        let title = R.string.localizable.inviteSendInvite(preferredLanguages: locale.rLanguages)
        let sendAction = InvitationActionViewModel(title: title,
                                                   icon: R.image.iconSendInvite(),
                                                   accessoryText: nil,
                                                   style: .normal)

        actions.append(sendAction)

        var footerText: String?

        if let userData = userData {
            if let parent = parentInfo?.fullName {
                footerText = R.string.localizable
                    .inviteParentInvitationTemplate(parent,
                                                    preferredLanguages: locale.rLanguages)
            } else if userData.canAcceptInvitation {
                let title = layout == .default ?
                    R.string.localizable
                        .inviteEnterInvitationCode(preferredLanguages: locale.rLanguages) :
                    R.string.localizable
                        .inviteEnterInvitationCodeCompact(preferredLanguages: locale.rLanguages)
                let enterCodeAction = InvitationActionViewModel(title: title,
                                                                icon: R.image.imageInvitation(),
                                                                accessoryText: nil,
                                                                style: .normal)
                actions.append(enterCodeAction)

                footerText = R.string.localizable
                    .inviteEnterCodeDescription(preferredLanguages: locale.rLanguages)
            }
        }

        let viewModel = InvitationActionListViewModel(headerText: headerText,
                                                      actions: actions,
                                                      footerText: footerText)

        return viewModel
    }

    func createActionAccessory(from remainedInterval: TimeInterval,
                               notificationInterval: TimerNotificationInterval) -> String {
        let timeFormatter: TimeFormatterProtocol

        switch notificationInterval {
        case .second:
            timeFormatter = MinuteSecondFormatter()
        case .minute:
            timeFormatter = HourMinuteFormatter()
        }

        return (try? timeFormatter.string(from: remainedInterval)) ?? ""
    }

    func createActivatedInvitationViewModel(from data: ActivatedInvitationsData) -> [InvitedViewModel] {
        return data.invitedUsers.map { invitation in
            let fullname = "\(invitation.firstName) \(invitation.lastName)"
            return InvitedViewModel(fullName: fullname)
        }
    }
}
