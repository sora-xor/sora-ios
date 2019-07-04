/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

protocol QRInputPresenterProtocol: InvitationInputPresenterProtocol {
    func activateManualInput()
    func handle(error: Error)
}

protocol QRInputWireframeProtocol: InvitationWireframeProtocol, ApplicationSettingsPresentable {
    func showManualInput(from view: InvitationInputViewProtocol?)
}
