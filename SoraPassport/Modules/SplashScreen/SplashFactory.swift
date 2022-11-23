/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraKeystore

protocol SplashPresenterProtocol: AnyObject {
    func setupComplete()
}

protocol SplashInteractorProtocol: AnyObject {
    func setup()
}

protocol SplashViewProtocol: AnyObject {
    func animate(duration animationDurationBase: Double, completion: @escaping () -> Void)
}

final class SplashPresenterFactory {
    static func createSplashPresenter(with window: SoraWindow) {
        let presenter = SplashPresenter(window: window)
        let interactor = SplashInteractor(settings: SettingsManager.shared,
                                          socketService: WebSocketService.shared)
        let wireframe = SplashWireframe()
        let view = SplashViewController()
        view.presenter = presenter
        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        interactor.presenter = presenter

        interactor.setup()
        window.rootViewController = view
    }
}
