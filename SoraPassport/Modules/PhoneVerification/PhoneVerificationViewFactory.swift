/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit
import SoraCrypto
import SoraKeystore

final class PhoneVerificationViewFactory: PhoneVerificationViewFactoryProtocol {
	static func createView() -> PhoneVerificationViewProtocol? {
        guard let requestSigner = DARequestSigner.createDefault() else {
            return nil
        }

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        let projectService = ProjectUnitService(unit: projectUnit)
        projectService.requestSigner = requestSigner

        let view = PhoneVerificationViewController(nib: R.nib.phoneVerificationViewController)
        let presenter = PhoneVerificationPresenter()
        let interactor = PhoneVerificationInteractor(projectService: projectService, settings: SettingsManager.shared)
        let wireframe = PhoneVerificationWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        presenter.logger = Logger.shared

        return view
	}
}
