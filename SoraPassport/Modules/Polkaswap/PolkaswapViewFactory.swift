/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraFoundation

final class PolkaswapViewFactory: PolkaswapViewFactoryProtocol {
    static func createView() -> PolkaswapViewProtocol? {
        let view = PolkaswapViewController(nib: R.nib.polkaswapViewController)
        view.localizationManager = LocalizationManager.shared

        let presenter = PolkaswapPresenter()
        let interactor = PolkaswapInteractor()
        let wireframe = PolkaswapWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
