/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import SoraCrypto

final class InvitationInputViewFactory: InvitationInputViewFactoryProtocol {
    static func createQRInputView() -> InvitationInputViewProtocol? {
        let view = QRInputViewController(nib: R.nib.qrInputViewController)
        view.logger = Logger.shared

        let presenter = QRInputPresenter()
        let wireframe = QRInputWireframe()

        let projectService = ProjectUnitService(unit: ApplicationConfig.shared.defaultProjectUnit)
        let interactor = InvitationInputInteractor(projectService: projectService)

        view.presenter = presenter
        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        return view
    }

    static func createManualInputView() -> InvitationInputViewProtocol? {
        let view = InvitationManualInputViewController(nib: R.nib.invitationManualInputViewController)

        let presenter = InvitationInputPresenter()
        let wireframe = InvitationInputWireframe()

        let projectService = ProjectUnitService(unit: ApplicationConfig.shared.defaultProjectUnit)
        let interactor = InvitationInputInteractor(projectService: projectService)

        view.presenter = presenter
        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        return view
    }
}
