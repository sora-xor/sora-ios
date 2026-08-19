// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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
        showMain(from: view, attemptsRemaining: 60)
    }

    @MainActor
    private func showMain(from view: PinSetupViewProtocol?, attemptsRemaining: Int) {
        guard MainTabBarViewFactory.isReadyForCreation() else {
            if attemptsRemaining == 60 {
                Logger.shared.warning(
                    "SORA wallet local dependencies are still initializing after unlock"
                )
            }
            guard attemptsRemaining > 0 else {
                presentWalletStartupRetry(from: view)
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self, weak view] in
                guard view?.controller.viewIfLoaded?.window != nil else {
                    return
                }
                self?.showMain(from: view, attemptsRemaining: attemptsRemaining - 1)
            }
            return
        }

        guard let mainViewController = MainTabBarViewFactory.createView()?.controller else {
            presentWalletStartupRetry(from: view)
            return
        }

        Logger.shared.info("SORA wallet screen created from local wallet state")
        rootAnimator.animateTransition(to: mainViewController)
    }

    @MainActor
    private func presentWalletStartupRetry(from view: PinSetupViewProtocol?) {
        Logger.shared.error("Wallet screen was not ready after waiting for chain startup")

        let retry = AlertPresentableAction(
            title: R.string.localizable.commonRetry(preferredLanguages: .currentLocale)
        ) { [weak self, weak view] in
            self?.showMain(from: view, attemptsRemaining: 60)
        }
        let viewModel = AlertPresentableViewModel(
            title: "Wallet is still starting",
            message: R.string.localizable.commonErrorRetry(preferredLanguages: .currentLocale),
            actions: [retry],
            closeAction: nil
        )
        present(viewModel: viewModel, style: .alert, from: view)
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
