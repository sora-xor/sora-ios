// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import SoraFoundation

class PinSetupWireframe: PinSetupWireframeProtocol, AlertPresentable, ErrorPresentable {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()

    let localizationManager: LocalizationManagerProtocol

    init(localizationManager: LocalizationManagerProtocol) {
        self.localizationManager = localizationManager
    }

    func dismiss(from view: PinSetupViewProtocol?) {
        if let presentingViewController = view?.controller.presentingViewController {
            presentingViewController.dismiss(animated: true, completion: nil)
        }
        if let navigationController = view?.controller.navigationController {
            navigationController.popViewController(animated: true)
        }
    }

    @MainActor
    func showMain(from view: PinSetupViewProtocol?) {
        guard let mainViewController = MainTabBarViewFactory.createView()?.controller else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.rootAnimator.animateTransition(to: mainViewController)
        }
    }

    public func showSignup(from view: PinSetupViewProtocol?) {
    }

    func showPinUpdatedNotify(from view: PinSetupViewProtocol?, completionBlock: @escaping () -> Void) {

        let languages = localizationManager.preferredLocalizations

        let success = ModalAlertFactory.createSuccessAlert(R.string.localizable.pincodeChangeSuccess(preferredLanguages: languages))

        view?.controller.present(success, animated: true, completion: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                completionBlock()
            }
        })
    }
}
