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

import Foundation
import IrohaCrypto
import SoraKeystore
import SoraFoundation
import SoraUIKit
import SSFCloudStorage

enum AccountOptionsDeletionPresentationPolicy {
    static func dismissalContainer(
        for controller: UIViewController
    ) -> UIViewController {
        let navigationController = controller.navigationController
        return navigationController?.parent ??
            navigationController ?? controller
    }
}

struct AccountOptionsRouteEnvironment {
    var authorize: @MainActor (AuthorizationPresentable, @escaping AuthorizationCompletionBlock) -> Void
    var passphrase: @MainActor (AccountItem) -> UIViewController?
    var rawSeed: @MainActor (AccountItem) -> UIViewController?
    var json: @MainActor (AccountItem) -> UIViewController?

    static var app: AccountOptionsRouteEnvironment {
        AccountOptionsRouteEnvironment(
            authorize: { route, completion in
                route.authorize(animated: true, cancellable: true, inView: nil, with: completion)
            },
            passphrase: { AccountCreateViewFactory.createViewForShowPassthrase($0)?.controller },
            rawSeed: { AccountExportRawSeedViewFactory.createView(account: $0) as? UIViewController },
            json: { AccountExportViewFactory.createView(accounts: [$0]) as? UIViewController }
        )
    }
}

final class AccountOptionsWireframe: AccountOptionsWireframeProtocol, AuthorizationPresentable, Loadable {

    private(set) var localizationManager: LocalizationManagerProtocol
    var activityIndicatorWindow: UIWindow?
    private let environment: AccountOptionsRouteEnvironment

    init(localizationManager: LocalizationManagerProtocol,
         environment: AccountOptionsRouteEnvironment = .app) {
        self.localizationManager = localizationManager
        self.environment = environment
    }

    @MainActor
    func showPassphrase(from view: AccountOptionsViewProtocol?, account: AccountItem) {
        let warning = AccountWarningViewController(warningType: .passphrase)
        warning.localizationManager = self.localizationManager
        warning.completion = { [weak self, weak warning] in
            guard let self, let warning else { return }
            self.environment.authorize(self) { [weak self, weak warning] isAuthorized in
                guard let self, let warning, isAuthorized,
                      self.canReplaceWarning(warning, from: view),
                      let destination = self.environment.passphrase(account) else { return }
                self.replaceWarning(warning, with: destination, from: view)
            }
        }
        if let navigationController = view?.controller.navigationController {
            warning.controller.hidesBottomBarWhenPushed = true
            navigationController.pushViewController(warning.controller, animated: true)
        }
    }
    
    @MainActor func setupBackupAccountPassword(on controller: AccountOptionsViewProtocol?,
                                    account: OpenBackupAccount,
                                    completion: @escaping () -> Void) {
        guard let setupPasswordView = SetupPasswordViewFactory.createView(
            with: account,
            entryPoint: .profile,
            completion: completion)?.controller else { return }
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        
        let nc = UINavigationController(rootViewController: setupPasswordView)
        nc.navigationBar.backgroundColor = .clear
        nc.navigationBar.setBackgroundImage(UIImage(), for: .default)
        nc.addCustomTransitioning()
        
        containerView.add(nc)
        controller?.controller.present(containerView, animated: true)
    }

    @MainActor
    func showRawSeed(from view: AccountOptionsViewProtocol?, account: AccountItem) {
        let warning = AccountWarningViewController(warningType: .rawSeed)
        warning.localizationManager = self.localizationManager
        warning.completion = { [weak self, weak warning] in
            guard let self, let warning else { return }
            self.environment.authorize(self) { [weak self, weak warning] isAuthorized in
                guard let self, let warning, isAuthorized,
                      self.canReplaceWarning(warning, from: view),
                      let destination = self.environment.rawSeed(account) else { return }
                self.replaceWarning(warning, with: destination, from: view)
            }
        }
        if let navigationController = view?.controller.navigationController {
            warning.controller.hidesBottomBarWhenPushed = true
            navigationController.pushViewController(warning.controller, animated: true)
        }
    }

    @MainActor
    func showJson(account: AccountItem, from view: AccountOptionsViewProtocol?) {
        let warning = AccountWarningViewController(warningType: .json)
        warning.localizationManager = self.localizationManager
        warning.completion = { [weak self, weak warning] in
            guard let self, let warning else { return }
            self.environment.authorize(self) { [weak self, weak warning] isAuthorized in
                guard let self, let warning, isAuthorized,
                      self.canReplaceWarning(warning, from: view),
                      let destination = self.environment.json(account) else { return }
                self.replaceWarning(warning, with: destination, from: view)
            }
        }
        if let navigationController = view?.controller.navigationController {
            warning.controller.hidesBottomBarWhenPushed = true
            navigationController.pushViewController(warning.controller, animated: true)
        }
    }

    /// Creating or deleting a Google Drive backup asks for the same fresh
    /// wallet authorization (PIN or biometrics) as the local exports above.
    /// Google sign-in and the backup password never stand in for it.
    @MainActor
    func authorizeCloudBackup(from view: AccountOptionsViewProtocol?,
                              completion: @escaping AuthorizationCompletionBlock) {
        guard view != nil else {
            completion(false)
            return
        }
        environment.authorize(self, completion)
    }

    @MainActor
    private func canReplaceWarning(_ warning: UIViewController, from view: AccountOptionsViewProtocol?) -> Bool {
        guard let navigation = view?.controller.navigationController else { return false }
        return navigation.topViewController === warning
    }

    @MainActor
    private func replaceWarning(_ warning: UIViewController, with destination: UIViewController,
                                from view: AccountOptionsViewProtocol?) {
        guard let navigation = view?.controller.navigationController,
              navigation.topViewController === warning else { return }
        // Authorization can outlive the disclosure screen. Never remove an
        // unrelated destination or pop an empty stack when its result arrives.
        navigation.setViewControllers(Array(navigation.viewControllers.dropLast()) + [destination], animated: true)
    }

    func back(from view: AccountOptionsViewProtocol?) {
        DispatchQueue.main.async {
            guard let controller = view?.controller else {
                return
            }
            guard let navigationController = controller.navigationController
            else {
                controller.dismiss(animated: true)
                return
            }
            if navigationController.viewControllers.first === controller {
                // Wallet presents Account Options as the navigation root
                // inside BlurViewController. Popping that root is a no-op and
                // would leave a deleted wallet actionable on screen.
                (navigationController.parent ?? navigationController)
                    .dismiss(animated: true)
            } else {
                navigationController.popViewController(animated: true)
            }
        }
    }

    func dismissAfterDeletion(from view: AccountOptionsViewProtocol?) {
        DispatchQueue.main.async {
            guard let controller = view?.controller else {
                return
            }
            // Account deletion invalidates both the options controller and a
            // Change Account parent that may still list the removed wallet.
            AccountOptionsDeletionPresentationPolicy
                .dismissalContainer(for: controller)
                .dismiss(animated: true)
        }
    }

    func showRoot() {
        guard let rootWindow = UIApplication.shared.delegate?.window as? SoraWindow else {
            fatalError()
        }

        _ = SplashPresenterFactory.createSplashPresenter(with: rootWindow)
    }

    @MainActor
    func showLogout(from view: AccountOptionsViewProtocol?, isNeedCustomNodeText: Bool, completionBlock: (() -> Void)?) {
        let languages = localizationManager.preferredLocalizations

        let alertTitle = R.string.localizable.profileLogoutTitle(preferredLanguages: languages)
        var alertMessage = R.string.localizable.logoutDialogBody(preferredLanguages: languages)

        if isNeedCustomNodeText {
            let customNodeMessage = R.string.localizable.logoutRemoveCustomNodes(preferredLanguages: languages)
            alertMessage.append(contentsOf: "\n\n" + customNodeMessage)
        }

        let cancelActionTitle = R.string.localizable.commonCancel(preferredLanguages: languages)
        let logoutActionTitle = R.string.localizable.profileLogoutTitle(preferredLanguages: languages)

        environment.authorize(self) { (isAuthorized) in
            if isAuthorized {
                let alertView = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)

                let cancelAction = UIAlertAction(title: cancelActionTitle, style: .cancel, handler: nil)
                let logoutAction = UIAlertAction(title: logoutActionTitle, style: .destructive) { (_) in
                    completionBlock?()
                }

                alertView.addAction(cancelAction)
                alertView.addAction(logoutAction)

                view?.controller.present(alertView, animated: true, completion: nil)
            }
        }
    }
}
