/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import RobinHood

final class PersonalInfoPresenter {
    weak var view: PersonalInfoViewProtocol?
    var interactor: PersonalInfoInteractorInputProtocol!
    var wireframe: PersonalInfoWireframeProtocol!

    private var models: [PersonalInfoViewModel] = []
    private var applicationForm: ApplicationFormData?
    private var invitationCode: String

    init(applicationForm: ApplicationFormData?,
         invitationCode: String,
         viewModelFactory: PersonalInfoViewModelFactoryProtocol) {
        self.applicationForm = applicationForm
        self.invitationCode = invitationCode

        if let applicationForm = applicationForm {
            models = viewModelFactory.createViewModels(from: applicationForm)
        } else {
            models = viewModelFactory.createEmpty()
        }
    }
}

extension PersonalInfoPresenter: PersonalInfoPresenterProtocol {
    func load() {
        view?.didReceive(viewModels: models)
    }

    func register() {
        let firstName = models[PersonalInfoViewModelIndex.firstName.rawValue].value
        let lastName = models[PersonalInfoViewModelIndex.lastName.rawValue].value
        let phone = models[PersonalInfoViewModelIndex.phone.rawValue].value
        let email = models[PersonalInfoViewModelIndex.email.rawValue].value

        let applicationFormInfo = ApplicationFormInfo(applicationId: applicationForm?.identifier,
                                                  firstName: firstName,
                                                  lastName: lastName,
                                                  phone: phone,
                                                  email: email)

        interactor.register(with: applicationFormInfo, invitationCode: invitationCode)
    }
}

extension PersonalInfoPresenter: PersonalInfoInteractorOutputProtocol {
    func didStartRegistration(with info: RegistrationInfo) {
        view?.didStartLoading()
    }

    func didCompleteRegistration(with info: RegistrationInfo) {
        view?.didStopLoading()

        wireframe.showPhoneVerification(from: view)
    }

    func didReceiveRegistration(error: Error) {
        view?.didStopLoading()

        if let networkError = error as? NetworkResponseError, networkError == .authorizationError {
            wireframe.present(message: R.string.localizable.registrationUnauthorizedMessage(),
                              title: R.string.localizable.registrationUnauthorizedTitle(),
                              closeAction: R.string.localizable.close(),
                              from: view)
            return
        }

        if wireframe.present(error: error, from: view) {
            return
        }
    }
}
