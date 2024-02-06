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

import Foundation
import IrohaCrypto
import SoraKeystore
import SCard
import SoraFoundation
import SoraUIKit
import SSFCloudStorage

final class AccountOptionsWireframe: AccountOptionsWireframeProtocol, AuthorizationPresentable, Loadable {

    private(set) var localizationManager: LocalizationManagerProtocol
    var activityIndicatorWindow: UIWindow?

    init(localizationManager: LocalizationManagerProtocol) {
        self.localizationManager = localizationManager
    }

    @MainActor
    func showPassphrase(from view: AccountOptionsViewProtocol?, account: AccountItem) {
        let warning = AccountWarningViewController(warningType: .passphrase)
        warning.localizationManager = self.localizationManager
        warning.completion = { [weak self] in
            self?.authorize(animated: true, cancellable: true, inView: nil) { isAuthorized in
                guard isAuthorized, let passphraseView = AccountCreateViewFactory.createViewForShowPassthrase(account) else {
                    return
                }
                
                var navigationArray = view?.controller.navigationController?.viewControllers ?? []
                navigationArray.remove(at: navigationArray.count - 1)
                view?.controller.navigationController?.viewControllers = navigationArray
                view?.controller.navigationController?.pushViewController(passphraseView.controller, animated: true)
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
        warning.completion = { [weak self] in
            self?.authorize(animated: true, cancellable: true, inView: nil) { isAuthorized in
                if isAuthorized {
                    guard let jsonExportVC = AccountExportRawSeedViewFactory.createView(account: account) as? UIViewController else {
                        return
                    }

                    var navigationArray = view?.controller.navigationController?.viewControllers ?? []
                    navigationArray.remove(at: navigationArray.count - 1)
                    view?.controller.navigationController?.viewControllers = navigationArray
                    view?.controller.navigationController?.pushViewController(jsonExportVC, animated: true)
                }
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
        warning.completion = { [weak self] in
            self?.authorize(animated: true, cancellable: true, inView: nil) { isAuthorized in
                if isAuthorized {
                    guard let jsonExportVC = AccountExportViewFactory.createView(accounts: [account]) as? UIViewController else {
                        return
                    }

                    var navigationArray = view?.controller.navigationController?.viewControllers ?? []
                    navigationArray.remove(at: navigationArray.count - 1)
                    view?.controller.navigationController?.viewControllers = navigationArray
                    view?.controller.navigationController?.pushViewController(jsonExportVC, animated: true)
                }
            }
        }
        if let navigationController = view?.controller.navigationController {
            warning.controller.hidesBottomBarWhenPushed = true
            navigationController.pushViewController(warning.controller, animated: true)
        }
    }

    func back(from view: AccountOptionsViewProtocol?) {
        DispatchQueue.main.async {
            view?.controller.navigationController?.popViewController(animated: true)
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

        authorize(animated: true, cancellable: true, inView: nil) { (isAuthorized) in
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
