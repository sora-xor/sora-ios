/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

class PinSetupWireframe: PinSetupWireframeProtocol, AlertPresentable, ErrorPresentable {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()

    func showMain(from view: PinSetupViewProtocol?) {
        guard let mainViewController = MainTabBarViewFactory.createView()?.controller else {
            return
        }

        self.rootAnimator.animateTransition(to: mainViewController)
    }

    func showAuthVerification(from view: PinSetupViewProtocol?) {
        guard let startupController = StartupViewFactory.createView()?.controller else {
            return
        }

        rootAnimator.animateTransition(to: startupController)
    }

    public func showSignup(from view: PinSetupViewProtocol?) {
        guard let signupViewController = OnboardingMainViewFactory.createView()?.controller else {
            return
        }

        rootAnimator.animateTransition(to: signupViewController)
    }
}
