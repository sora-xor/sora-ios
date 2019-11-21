/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

final class InvitationHandlePresenter {
    weak var view: ControllerBackedProtocol?
    var interactor: InvitationHandleInteractorInputProtocol!
    var wireframe: InvitationHandleWireframeProtocol!

    private var userDataResult: Result<UserData, Error>?
    private(set) var pendingInvitationCode: String?

    var logger: LoggerProtocol?

    private func process() {
        guard let userDataResult = userDataResult else {
            return
        }

        do {
            if let invitationCode = pendingInvitationCode {
                self.pendingInvitationCode = nil

                let userData = try extractValue(result: userDataResult)

                if userData.parentId != nil {
                    throw ApplyInvitationDataError.parentAlreadyExists
                }

                if !userData.canAcceptInvitation {
                    throw ApplyInvitationDataError.invitationAcceptingWindowClosed
                }

                let message = R.string.localizable.inviteCodeApplyMessage(invitationCode)

                let cancelAction = AlertPresentableAction(title: R.string.localizable.cancel())

                let applyAction = AlertPresentableAction(title: R.string.localizable.apply()) { [weak self] in
                    self?.interactor.apply(invitationCode: invitationCode)
                }

                wireframe.present(message: message,
                                  title: nil,
                                  actions: [cancelAction, applyAction],
                                  from: view)
            }
        } catch {
            if !wireframe.present(error: error, from: view) {
                logger?.error("Did receive invitation processing error \(error) after user data")
            }
        }
    }

    private func extractValue<T>(result: Result<T, Error>) throws -> T {
        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
}

extension InvitationHandlePresenter: InvitationHandlePresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

extension InvitationHandlePresenter: InvitationHandleInteractorOutputProtocol {
    func didReceive(userData: UserData) {
        userDataResult = .success(userData)
        process()
    }

    func didReceiveUserDataProvider(error: Error) {
        userDataResult = .failure(error)
        process()
    }

    func didApply(invitationCode: String) {
        wireframe.present(message: R.string.localizable.inviteCodeAppliedMessage(),
                          title: R.string.localizable.congratulationTitle(),
                          closeAction: R.string.localizable.close(),
                          from: view)
    }

    func didReceiveInvitationApplication(error: Error, of code: String) {
        if !wireframe.present(error: error, from: view) {
            logger?.error("Did receive invitation application error \(error)")
        }
    }
}

extension InvitationHandlePresenter {
    func navigate(to invitation: InvitationDeepLink) -> Bool {
        pendingInvitationCode = invitation.code
        interactor.refresh()
        process()

        return true
    }
}
