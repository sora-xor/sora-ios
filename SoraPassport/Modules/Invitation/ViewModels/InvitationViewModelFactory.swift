/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

protocol InvitationViewModelFactoryProtocol {
    func createActionListViewModel(from userData: UserData?,
                                   parentInfo: ParentInfoData?,
                                   layout: InvitationViewLayout) -> InvitationActionListViewModel
    func createActionAccessory(from remainedInterval: TimeInterval,
                               notificationInterval: TimerNotificationInterval) -> String
    func createActivatedInvitationViewModel(from data: ActivatedInvitationsData) -> [InvitedViewModel]
}

struct InvitationViewModelFactory: InvitationViewModelFactoryProtocol {
    let integerFormatter: NumberFormatter

    func createActionListViewModel(from userData: UserData?,
                                   parentInfo: ParentInfoData?,
                                   layout: InvitationViewLayout) -> InvitationActionListViewModel {
        let headerText = R.string.localizable.inviteHeaderTitle()

        var sendActionAccessory: String?

        if let invitationsCount = userData?.values.invitations, invitationsCount >= 0 {
            if let invitationsTitle = integerFormatter.string(from: NSNumber(value: invitationsCount)) {
                sendActionAccessory = R.string.localizable.inviteActionSendAccessoryFormat(invitationsTitle)
            }
        }

        var actions: [InvitationActionViewModel] = []

        let sendAction = InvitationActionViewModel(title: R.string.localizable.inviteActionSendTitle(),
                                                   icon: R.image.iconSendInvite(),
                                                   accessoryText: sendActionAccessory,
                                                   style: .normal)

        actions.append(sendAction)

        var footerText: String?

        if let userData = userData {
            if let parent = parentInfo?.fullName {
                footerText = R.string.localizable.inviteFooterParentTitle(parent)
            } else if userData.canAcceptInvitation {
                let title = layout == .default ? R.string.localizable.inviteActionEnterCodeTitle()
                    : R.string.localizable.inviteActionCompactEnterCodeTitle()
                let enterCodeAction = InvitationActionViewModel(title: title,
                                                                icon: R.image.imageInvitation(),
                                                                accessoryText: nil,
                                                                style: .normal)
                actions.append(enterCodeAction)

                footerText = R.string.localizable.inviteFooterCodeTitle()
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
