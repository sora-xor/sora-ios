/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraFoundation

final class ParliamentViewFactory: ParliamentViewFactoryProtocol {
    static func createView() -> ParliamentViewProtocol? {
        let view = ParliamentViewController(nib: R.nib.parliamentViewController)
        view.localizationManager = LocalizationManager.shared

        let presenter = ParliamentPresenter()
        let interactor = ParliamentInteractor()
        let wireframe = ParliamentWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
