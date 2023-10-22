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

    func showStart(from view: UIViewController, completion: @escaping () -> Void) {
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        
        let onboardingView = OnboardingMainViewFactory.createWelcomeView(endAddingBlock: completion)
        
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
