/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

final class PhoneRegistrationWireframe: PhoneRegistrationWireframeProtocol {
    func showPhoneVerification(from view: PhoneRegistrationViewProtocol?, country: Country) {
        let personalForm = PersonalForm.create(from: country)
        guard let phoneVerificationView = PhoneVerificationViewFactory.createView(with: personalForm) else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(phoneVerificationView.controller,
                                                    animated: true)
        }
    }

    func showRegistration(from view: PhoneRegistrationViewProtocol?, country: Country) {
        let personalForm = PersonalForm.create(from: country)
        guard let registrationView = PersonalInfoViewFactory.createView(with: personalForm) else {
            return
        }

        if let navigationCountroller = view?.controller.navigationController {
            navigationCountroller.pushViewController(registrationView.controller, animated: true)
        }
    }
}
