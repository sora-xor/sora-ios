/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

final class PersonalInfoWireframe: PersonalInfoWireframeProtocol {
    func showPhoneVerification(from view: PersonalInfoViewProtocol?) {
        guard let phoneVerificationView = PhoneVerificationViewFactory.createView() else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(phoneVerificationView.controller,
                                                    animated: true)
        }
    }
}
