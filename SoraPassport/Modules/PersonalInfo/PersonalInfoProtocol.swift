/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

protocol PersonalInfoViewProtocol: LoadableViewProtocol, ControllerBackedProtocol {
    func didReceive(viewModels: [PersonalInfoViewModelProtocol])
}

protocol PersonalInfoPresenterProtocol: class {
    func load()
    func register()
}

protocol PersonalInfoInteractorInputProtocol: class {
    var isBusy: Bool { get }
    func register(with applicationForm: ApplicationFormInfo, invitationCode: String)
}

protocol PersonalInfoInteractorOutputProtocol: class {
    func didStartRegistration(with info: RegistrationInfo)
    func didCompleteRegistration(with info: RegistrationInfo)
    func didReceiveRegistration(error: Error)
}

protocol PersonalInfoWireframeProtocol: AlertPresentable, ErrorPresentable {
    func showPhoneVerification(from view: PersonalInfoViewProtocol?)
}

protocol PersonalInfoViewFactoryProtocol {
    static func createView(with applicationForm: ApplicationFormData?,
                           invitationCode: String) -> PersonalInfoViewProtocol?
}
