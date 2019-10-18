/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

final class SelectCountryWireframe: SelectCountryWireframeProtocol {
    func showNext(from view: SelectCountryViewProtocol?, country: Country) {
        guard let phoneRegistrationView = PhoneRegistrationViewFactory.createView(with: country) else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(phoneRegistrationView.controller, animated: true)
        }
    }
}
