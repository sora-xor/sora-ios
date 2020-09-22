/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraFoundation

protocol PhoneRegistrationViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(viewModel: InputViewModelProtocol)
}

protocol PhoneRegistrationPresenterProtocol: class {
    func setup()
    func processPhoneInput()
}

protocol PhoneRegistrationInteractorInputProtocol: class {
    func createCustomer(with info: UserCreationInfo)
}

protocol PhoneRegistrationInteractorOutputProtocol: class {
    func didCreateCustomer()
    func didReceiveCustomerCreation(error: Error)
}

protocol PhoneRegistrationWireframeProtocol: AlertPresentable, ErrorPresentable {
    func showPhoneVerification(from view: PhoneRegistrationViewProtocol?, country: Country)
    func showRegistration(from view: PhoneRegistrationViewProtocol?, country: Country)
}

protocol PhoneRegistrationViewFactoryProtocol: class {
    static func createView(with country: Country) -> PhoneRegistrationViewProtocol?
}
