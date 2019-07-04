/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

class InvitationInputWireframe: InvitationInputWireframeProtocol {
    func continueOnboarding(from view: InvitationInputViewProtocol?,
                            with applicationForm: ApplicationFormData?,
                            invitationCode: String) {
        let personalInfoView = PersonalInfoViewFactory.createView(with: applicationForm, invitationCode: invitationCode)
        guard let controller = personalInfoView?.controller else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(controller,
                                                    animated: true)
        }
    }
}
