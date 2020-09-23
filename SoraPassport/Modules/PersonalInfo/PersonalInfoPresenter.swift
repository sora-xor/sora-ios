/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood
import SoraFoundation

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

    private var models: [InputViewModel] = []

    let locale: Locale

    init(viewModelFactory: PersonalInfoViewModelFactoryProtocol,
         personalForm: PersonalForm,
         locale: Locale) {
        self.personalForm = personalForm
        self.viewModelFactory = viewModelFactory
        self.locale = locale
    }

    private func updatePersonalForm() {
        personalForm.firstName = models[ViewModelIndex.firstName.rawValue].inputHandler.normalizedValue
        personalForm.lastName = models[ViewModelIndex.lastName.rawValue].inputHandler.normalizedValue
        let invitationCode = models[ViewModelIndex.invitationCode.rawValue].inputHandler.normalizedValue

        if !invitationCode.isEmpty {
            personalForm.invitationCode = invitationCode
        } else {
            personalForm.invitationCode = nil
        }
    }

    private func handleInvalidInvitationCode() {
        let tryAnotherAction = AlertPresentableAction(title: R.string.localizable
            .tryAnother(preferredLanguages: locale.rLanguages)) { [weak self] in
            self?.clearInvitation()
        }

        let skipAction = AlertPresentableAction(title: R.string.localizable
            .commonSkip(preferredLanguages: locale.rLanguages)) { [weak self] in
            self?.skipInvitation()
        }

        wireframe.present(message: R.string.localizable
            .personalInfoInvitationIsInvalid(preferredLanguages: locale.rLanguages),
                          title: R.string.localizable
                            .commonErrorGeneralTitle(preferredLanguages: locale.rLanguages),
                          actions: [tryAnotherAction, skipAction],
                          from: view)
    }

    private func clearInvitation() {
        models[ViewModelIndex.invitationCode.rawValue].inputHandler.clearValue()
        view?.didReceive(viewModels: models)
        view?.didStartEditing(at: ViewModelIndex.invitationCode.rawValue)
    }

    private func skipInvitation() {
        models[ViewModelIndex.invitationCode.rawValue].inputHandler.clearValue()
        register()
    }
}

extension PersonalInfoPresenter: PersonalInfoPresenterProtocol {
    func load() {
        models = viewModelFactory.createRegistrationForm(from: personalForm,
                                                         locale: locale)
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

        models = viewModelFactory.createRegistrationForm(from: personalForm,
                                                         locale: locale)
        view?.didReceive(viewModels: models)

        if invitationCode == nil {
            let footerViewModel = PersonalInfoFooterViewModel(text: R.string.localizable
                .personalInfoInvitationDescription(preferredLanguages: locale.rLanguages))
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

        if wireframe.present(error: error, from: view, locale: locale) {
            return
        }

        if let registrationError = error as? RegistrationDataError {
            switch registrationError {
            case .userNotFound:
                wireframe.present(message: R.string.localizable
                    .registrationUserNotFoundMessage(preferredLanguages: locale.rLanguages),
                                  title: R.string.localizable
                                    .commonErrorGeneralTitle(preferredLanguages: locale.rLanguages),
                                  closeAction: R.string.localizable
                                    .commonClose(preferredLanguages: locale.rLanguages),
                                  from: view)
            case .wrongUserStatus:
                wireframe.present(message: R.string.localizable
                    .registrationWrongStatusMessage(preferredLanguages: locale.rLanguages),
                                  title: R.string.localizable
                                    .commonErrorGeneralTitle(preferredLanguages: locale.rLanguages),
                                  closeAction: R.string.localizable
                                    .commonClose(preferredLanguages: locale.rLanguages),
                                  from: view)
            case .invitationCodeNotFound:
                handleInvalidInvitationCode()
            }
        }
    }
}
