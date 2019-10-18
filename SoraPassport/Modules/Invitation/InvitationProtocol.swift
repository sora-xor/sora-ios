/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

protocol InvitationViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(leftInvitations: String)
    func didReceive(parentTitle: String)
    func didReceive(invitedUsers: [InvitedViewModelProtocol])
}

protocol InvitationPresenterProtocol: class {
    func viewIsReady()
    func viewDidAppear()
    func sendInvitation()
    func openHelp()
}

protocol InvitationInteractorInputProtocol: class {
    func setup()
    func refreshUserValues()
    func refreshInvitedUsers()
    func loadInvitationCode()
    func mark(invitationCode: String)
}

protocol InvitationInteractorOutputProtocol: class {
    func didLoad(userValues: UserValuesData)
    func didReceiveValuesDataProvider(error: Error)

    func didLoad(invitationsData: ActivatedInvitationsData)
    func didReceiveInvitedUsersDataProvider(error: Error)

    func didLoad(invitationCodeData: InvitationCodeData)
    func didReceiveInvitationCode(error: Error)

    func didMark(invitationCode: String)
}

enum InvitationInteractorError: Error {
    case invalidatingPreviousCode
}

protocol InvitationWireframeProtocol: SharingPresentable, AlertPresentable,
ErrorPresentable, HelpPresentable {}

protocol InvitationViewFactoryProtocol: class {
    static func createView() -> InvitationViewProtocol?
}
