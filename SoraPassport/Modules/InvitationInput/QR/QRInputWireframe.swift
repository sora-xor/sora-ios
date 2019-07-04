/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

final class QRInputWireframe: InvitationInputWireframe, QRInputWireframeProtocol {
    func showManualInput(from view: InvitationInputViewProtocol?) {
        guard let manualInputView = InvitationInputViewFactory.createManualInputView() else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(manualInputView.controller, animated: true)
        }
    }
}
