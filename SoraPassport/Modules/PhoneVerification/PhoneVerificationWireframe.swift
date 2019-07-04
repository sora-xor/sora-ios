/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

final class PhoneVerificationWireframe: PhoneVerificationWireframeProtocol {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()

    func showAccessBackup(from view: PhoneVerificationViewProtocol?) {
        guard let controller = AccessBackupViewFactory.createView()?.controller else {
            return
        }

        let navigationController = SoraNavigationController()
        navigationController.viewControllers = [controller]

        rootAnimator.animateTransition(to: navigationController)
    }
}
