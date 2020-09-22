/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

final class StartupWireframe: StartupWireframeProtocol {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()

    func showOnboarding(from view: StartupViewProtocol?) {
        guard let onboardingController = OnboardingMainViewFactory.createView()?.controller else {
            return
        }

        let navigationController = SoraNavigationController()
        navigationController.viewControllers = [onboardingController]

        rootAnimator.animateTransition(to: navigationController)
    }

    func showMain(from view: StartupViewProtocol?) {
        guard let controller = MainTabBarViewFactory.createView()?.controller else {
            return
        }

        rootAnimator.animateTransition(to: controller)
    }

    func showPincodeSetup(from view: StartupViewProtocol?) {
        guard let controller = PinViewFactory.createPinSetupView()?.controller else {
            return
        }

        rootAnimator.animateTransition(to: controller)
    }
}
