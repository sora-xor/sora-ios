/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

final class PersonalInfoPresenter {
    enum ViewModelIndex: Int {
        case firstName
        case lastName
        case invitationCode
    }

    weak var view: PersonalInfoViewProtocol?
    var interactor: PersonalInfoInteractorInputProtocol!
    var wireframe: PersonalInfoWireframeProtocol!

    var viewModelFactory: PersonalInfoViewModelFactoryProtocol

    var personalForm: PersonalForm

    private var models: [PersonalInfoViewModel] = []

    init(viewModelFactory: PersonalInfoViewModelFactoryProtocol, personalForm: PersonalForm) {
        self.personalForm = personalForm
        self.viewModelFactory = viewModelFactory
    }

    private func updatePersonalForm() {
        personalForm.firstName = models[ViewModelIndex.firstName.rawValue].value
        personalForm.lastName = models[ViewModelIndex.lastName.rawValue].value
        let invitationCode = models[ViewModelIndex.invitationCode.rawValue].value

        if !invitationCode.isEmpty {
            personalForm.invitationCode = invitationCode
        } else {
            personalForm.invitationCode = nil
        }
    }

    private func handleInvalidInvitationCode() {
        let tryAnotherAction = AlertPresentableAction(title: R.string.localizable.tryAnother()) { [weak self] in
            self?.clearInvitation()
        }

        let skipAction = AlertPresentableAction(title: R.string.localizable.skip()) { [weak self] in
            self?.skipInvitation()
        }

        wireframe.present(message: R.string.localizable.registrationInvitationCodeInvalidMessage(),
                          title: R.string.localizable.errorTitle(),
                          actions: [tryAnotherAction, skipAction],
                          from: view)
    }

    private func clearInvitation() {
        models[ViewModelIndex.invitationCode.rawValue].value = ""
        view?.didReceive(viewModels: models)
        view?.didStartEditing(at: ViewModelIndex.invitationCode.rawValue)
    }

    private func skipInvitation() {
        models[ViewModelIndex.invitationCode.rawValue].value = ""
        register()
    }
}

extension PersonalInfoPresenter: PersonalInfoPresenterProtocol {
    func load() {
        models = viewModelFactory.createRegistrationForm(from: personalForm)
        view?.didReceive(viewModels: models)

        interactor.load()
    }

    func register() {
        updatePersonalForm()
        interactor.register(with: personalForm)
    }
}

extension PersonalInfoPresenter: PersonalInfoInteractorOutputProtocol {
    func didReceive(invitationCode: String?) {
        updatePersonalForm()

        personalForm.invitationCode = invitationCode

        models = viewModelFactory.createRegistrationForm(from: personalForm)
        view?.didReceive(viewModels: models)

        if invitationCode == nil {
            let footerViewModel = PersonalInfoFooterViewModel(text: R.string.localizable
                                                                .personalInfoInvitationMessage())
            view?.didReceive(footerViewModel: footerViewModel)
        }
    }

    func didStartRegistration(with form: PersonalForm) {
        view?.didStartLoading()
    }

    func didCompleteRegistration(with form: PersonalForm) {
        view?.didStopLoading()

        wireframe.showPassphraseBackup(from: view)
    }

    func didReceiveRegistration(error: Error) {
        view?.didStopLoading()

        if wireframe.present(error: error, from: view) {
            return
        }

        if let registrationError = error as? RegistrationDataError {
            switch registrationError {
            case .userNotFound:
                wireframe.present(message: R.string.localizable.registrationUserNotFoundMessage(),
                                  title: R.string.localizable.errorTitle(),
                                  closeAction: R.string.localizable.close(),
                                  from: view)
            case .wrongUserStatus:
                wireframe.present(message: R.string.localizable.registrationWrongStatusMessage(),
                                  title: R.string.localizable.errorTitle(),
                                  closeAction: R.string.localizable.close(),
                                  from: view)
            case .invitationCodeNotFound:
                handleInvalidInvitationCode()
            }
        }
    }
}
