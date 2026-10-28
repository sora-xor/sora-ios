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
import SoraUIKit

final class ChangeAccountWireframe: ChangeAccountWireframeProtocol, AuthorizationPresentable {
    
    func showSignUp(from view: UIViewController, completion: @escaping () -> Void) {
        let navigationController = SoraNavigationController()
        let endAddingBlock = { navigationController.dismiss(animated: true, completion: completion) }
        
        guard let usernameSetup = SetupAccountNameViewFactory.createViewForAdding(endEditingBlock: endAddingBlock) else {
            return
        }

        navigationController.viewControllers = [usernameSetup.controller]
        view.present(navigationController, animated: true)
    }
    
    func showAccountRestore(from view: UIViewController, completion: @escaping () -> Void) {
        let navigationController = SoraNavigationController()
        let endAddingBlock = { navigationController.dismiss(animated: true, completion: completion) }
        
        guard let usernameSetup = AccountImportViewFactory.createViewForAdding(endAddingBlock: endAddingBlock) else {
            return
        }

        navigationController.viewControllers = [usernameSetup.controller]
        view.present(navigationController, animated: true)
    }

    @MainActor
    func showStart(from view: UIViewController, completion: @escaping () -> Void) {
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        
        let onboardingView = OnboardingMainViewFactory.createWelcomeViewForChanging(endAddingBlock: completion)
        
        let nc = UINavigationController(rootViewController: onboardingView?.controller ?? UIViewController())
        nc.navigationBar.backgroundColor = .clear
        nc.navigationBar.setBackgroundImage(UIImage(), for: .default)
        nc.addCustomTransitioning()
        
        containerView.add(nc)
        view.present(containerView, animated: true)
    }

    func showEdit(account: AccountItem, from controller: UIViewController) {
        if let editor = AccountOptionsViewFactory.createView(account: account) as? UIViewController {
            controller.navigationController?.pushViewController(editor, animated: true)
        }
    }

    @MainActor
    func showExportAccounts(accounts: [AccountItem], from controller: UIViewController) {

        let warning = AccountWarningViewController(warningType: .json)
        warning.localizationManager = LocalizationManager.shared
        warning.completion = { [weak self] in
            self?.authorize(animated: true, cancellable: true, inView: nil) { isAuthorized in
                if isAuthorized {
                    guard let jsonExportVC = AccountExportViewFactory.createView(accounts: accounts) as? UIViewController else {
                        return
                    }

                    var navigationArray = controller.navigationController?.viewControllers ?? []
                    navigationArray.remove(at: navigationArray.count - 1)
                    controller.navigationController?.viewControllers = navigationArray
                    controller.navigationController?.pushViewController(jsonExportVC, animated: true)
                }
            }
        }
        if let navigationController = controller.navigationController {
            warning.controller.hidesBottomBarWhenPushed = true
            navigationController.pushViewController(warning.controller, animated: true)
        }
    }
}
