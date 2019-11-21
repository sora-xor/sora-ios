/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

protocol InvitationViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(actionListViewModel: InvitationActionListViewModel)
    func didChange(accessoryTitle: String, at actionIndex: Int)
    func didChange(actionStyle: InvitationActionStyle, at actionIndex: Int)
    func didReceive(invitedUsers: [InvitedViewModelProtocol])
}

protocol InvitationPresenterProtocol: class {
    func viewIsReady(with layout: InvitationViewLayout)
    func viewDidAppear()
    func openHelp()
    func didSelectAction(at index: Int)
}

protocol InvitationInteractorInputProtocol: class {
    func setup()
    func refreshUser()
    func refreshInvitedUsers()
    func loadInvitationCode()
    func mark(invitationCode: String)
    func apply(invitationCode: String)
}

protocol InvitationInteractorOutputProtocol: class {
    func didLoad(user: UserData)
    func didReceiveUserDataProvider(error: Error)

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
ErrorPresentable, HelpPresentable, InputFieldPresentable {}

protocol InvitationViewFactoryProtocol: class {
    static func createView() -> InvitationViewProtocol?
}
