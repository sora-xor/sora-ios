/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

final class InvitationPresenter {
    weak var view: InvitationViewProtocol?
    var interactor: InvitationInteractorInputProtocol!
    var wireframe: InvitationWireframeProtocol!

    private(set) var integerNumberFormatter: NumberFormatter

    var logger: LoggerProtocol?

    private var isSharingInvitation: Bool = false

    init(integerNumberFormatter: NumberFormatter) {
        self.integerNumberFormatter = integerNumberFormatter
    }

    private func invite(with code: String) {
        let invitationMessage = R.string.localizable.inviteTemplate(code)
        let source = TextSharingSource(message: invitationMessage,
                                       subject: R.string.localizable.invitationsSharingSubject())

        wireframe.share(source: source,
                        from: view) { [weak self] (completed) in
                            self?.isSharingInvitation = false

                            if completed {
                                self?.interactor.mark(invitationCode: code)
                            }
        }
    }

    private func updateViewWithInvitations(count: Int) {
        if let invitationsString = integerNumberFormatter.string(from: NSNumber(value: max(count, 0))) {
            view?.didReceive(leftInvitations: invitationsString)
        }
    }

    private func updateInvitedUsers(from invitationsData: ActivatedInvitationsData) {
        let viewModels: [InvitedViewModel] = invitationsData.invitedUsers.map { invitation in
            let fullname = "\(invitation.firstName) \(invitation.lastName)"
            return InvitedViewModel(fullName: fullname)
        }

        view?.didReceive(invitedUsers: viewModels)
    }

    private func updateParentInfo(from invitationsData: ActivatedInvitationsData) {
        if let parentInfo = invitationsData.parentInfo {
            let parentTitle = R.string.localizable.inviteParentTitle(parentInfo.fullName)
            view?.didReceive(parentTitle: parentTitle)
        }
    }
}

extension InvitationPresenter: InvitationPresenterProtocol {
    func viewIsReady() {
        interactor.setup()
    }

    func viewDidAppear() {
        interactor.refreshUserValues()
        interactor.refreshInvitedUsers()
    }

    func sendInvitation() {
        if !isSharingInvitation {
            isSharingInvitation = true
            interactor.loadInvitationCode()
        }
    }

    func openHelp() {
        wireframe.presentHelp(from: view)
    }
}

extension InvitationPresenter: InvitationInteractorOutputProtocol {
    func didLoad(userValues: UserValuesData) {
        updateViewWithInvitations(count: userValues.invitations)
    }

    func didReceiveValuesDataProvider(error: Error) {
        logger?.debug("Did receive values data provider \(error)")
    }

    func didLoad(invitationsData: ActivatedInvitationsData) {
        updateParentInfo(from: invitationsData)
        updateInvitedUsers(from: invitationsData)
    }

    func didReceiveInvitedUsersDataProvider(error: Error) {
        logger?.debug("Did receive invited users data provider \(error)")
    }

    func didLoad(invitationCodeData: InvitationCodeData) {
        if isSharingInvitation {
            invite(with: invitationCodeData.invitationCode)
        }

        updateViewWithInvitations(count: invitationCodeData.invitationsCount)
    }

    func didReceiveInvitationCode(error: Error) {
        isSharingInvitation = false

        if wireframe.present(error: error, from: view) {
            return
        }

        if let invitationCodeError = error as? InvitationCodeDataError {
            switch invitationCodeError {
            case .userValuesNotFound:
                wireframe.present(message: R.string.localizable.invitationsValuesNotFoundErrorMessage(),
                                  title: R.string.localizable.errorTitle(),
                                  closeAction: R.string.localizable.close(),
                                  from: view)
            case .notEnoughInvitations:
                wireframe.present(message: R.string.localizable.invitationsNotEnoughErrorMessage(),
                                  title: "",
                                  closeAction: R.string.localizable.close(),
                                  from: view)
            }
        }

        interactor.refreshUserValues()
    }

    func didMark(invitationCode: String) {
        interactor.refreshUserValues()
    }
}
