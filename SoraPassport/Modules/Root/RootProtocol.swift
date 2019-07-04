/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit

protocol RootPresenterProtocol: class {
    func loadOnLaunch()
}

protocol RootWireframeProtocol: class {
    func showLocalAuthentication(on view: UIWindow)
    func showOnboarding(on view: UIWindow)
    func showAuthVerification(on view: UIWindow)
    func showBroken(on view: UIWindow)
}

protocol RootInteractorInputProtocol: class {
    func setup()
    func decideModuleSynchroniously()
}

protocol RootInteractorOutputProtocol: class {
    func didDecideOnboarding()
    func didDecideLocalAuthentication()
    func didDecideAuthVerification()
    func didDecideBroken()
}

protocol RootPresenterFactoryProtocol: class {
    static func createPresenter(with view: UIWindow) -> RootPresenterProtocol
}
