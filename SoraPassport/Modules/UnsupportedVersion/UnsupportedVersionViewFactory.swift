/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

final class UnsupportedVersionViewFactory: UnsupportedVersionViewFactoryProtocol {
    static func createView(supportedVersionData: SupportedVersionData) -> UnsupportedVersionViewProtocol? {
        let view = UnsupportedVersionViewController(nib: R.nib.unsupportedVersionViewController)
        let presenter = UnsupportedVersionPresenter(supportedVersionData: supportedVersionData)
        let interactor = UnsupportedVersionInteractor()
        let wireframe = UnsupportedVersionWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
