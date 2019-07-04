/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

final class QRInputPresenter: InvitationInputPresenter, QRInputPresenterProtocol {
    private var alreadyAskedAccess: Bool = false

    func activateManualInput() {
        guard let wireframe = wireframe as? QRInputWireframeProtocol else {
            return
        }

        wireframe.showManualInput(from: view)
    }

    func handle(error: Error) {
        guard let qrServiceError = error as? QRCaptureServiceError else {
            return
        }

        guard !alreadyAskedAccess else {
            return
        }

        alreadyAskedAccess = true

        switch qrServiceError {
        case .deviceAccessRestricted:
            wireframe.present(message: R.string.localizable.qrInputRestrictedErrorMessage(),
                              title: R.string.localizable.errorTitle(),
                              closeAction: R.string.localizable.close(),
                              from: view)
        case .deviceAccessDeniedPreviously:
            guard let qrWireframe = wireframe as? QRInputWireframeProtocol else {
                return
            }

            qrWireframe.askOpenApplicationSettins(with: R.string.localizable.qrInputDeniedErrorMessage(),
                                                  title: R.string.localizable.qrInputDeniedErrorTitle(),
                                                  from: view)
        default:
            break
        }
    }
}
