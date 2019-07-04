/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

class InvitationInputPresenter {
    weak var view: InvitationInputViewProtocol?
    var wireframe: InvitationInputWireframeProtocol!
    var interactor: InvitationInputInteractorProtocol!
}

extension InvitationInputPresenter: InvitationInputPresenterProtocol {
    func process(viewModel: CodeInputViewModelProtocol) {
        guard !interactor.isProcessing &&  viewModel.isComplete else {
            return
        }

        interactor.process(code: viewModel.code)
    }
}

extension InvitationInputPresenter: InvitationInputInteractorOutputProtocol {
    func didStartProcessing(code: String) {
        view?.didStartLoading()
    }

    func didSuccessfullProcess(code: String, received applicationForm: ApplicationFormData?) {
        view?.didStopLoading()

        wireframe.continueOnboarding(from: view, with: applicationForm, invitationCode: code)
    }

    func didReceiveProcessing(error: Error, for code: String) {
        guard let view = view else {
            return
        }

        view.didStopLoading()

        if view.present(error: error, from: nil) {
            return
        }

        if wireframe.present(error: error, from: view) {
            return
        }

        if let resultError = error as? InvitationCheckDataError {
            switch resultError {
            case .codeNotFound:
                wireframe.present(message: R.string.localizable.invitationCodeNotFoundErrorMessage(),
                                  title: R.string.localizable.errorTitle(),
                                  closeAction: R.string.localizable.close(),
                                  from: view)
            }
        }
    }
}
