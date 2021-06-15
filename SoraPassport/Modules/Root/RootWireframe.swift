/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

final class RootWireframe: RootWireframeProtocol {
    func showOnboarding(on view: UIWindow) {
        let onboardingView = OnboardingMainViewFactory.createViewForOnboarding()
        let onboardingController = onboardingView?.controller ?? UIViewController()

        let navigationController = SoraNavigationController()
        navigationController.viewControllers = [onboardingController]

        view.rootViewController = navigationController
    }

    func showLocalAuthentication(on view: UIWindow) {
        let pincodeView = PinViewFactory.createSecuredPinView()
        let pincodeController = pincodeView?.controller ?? UIViewController()

        view.rootViewController = pincodeController
    }

    func showPincodeSetup(on view: UIWindow) {
        guard let controller = PinViewFactory.createPinSetupView()?.controller else {
            return
        }

        view.rootViewController = controller
    }

    func showBroken(on view: UIWindow) {
        // normally user must not see this but on malicious devices it is possible
        view.backgroundColor = .red
    }

    func showSplash(on view: UIWindow, completion: @escaping () -> Void) {
        view.rootViewController = UIViewController()
        SplashPresenter().present(in: view, duration: 2.0, completion: {
            completion()
        })
    }
}
