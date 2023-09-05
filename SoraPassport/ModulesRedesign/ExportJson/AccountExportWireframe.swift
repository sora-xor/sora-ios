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

final class AccountExportWireframe: AccountExportWireframeProtocol, AuthorizationPresentable {

    private(set) var localizationManager: LocalizationManagerProtocol

    init(localizationManager: LocalizationManagerProtocol) {
        self.localizationManager = localizationManager
    }

    func showJson(from view: AccountExportViewProtocol?, accounts: [AccountItem]) {
        let warning = AccountWarningViewController(warningType: .json)
        warning.localizationManager = self.localizationManager
        warning.completion = { [weak self] in
            self?.authorize(animated: true, cancellable: true, inView: nil) { [weak self] (isAuthorized) in
                if isAuthorized {
                    guard let accountExportView = self?.createAccountExportView(accounts) else {
                        return
                    }

                    var navigationArray = view?.controller.navigationController?.viewControllers ?? []
                    navigationArray.remove(at: navigationArray.count - 1)
                    view?.controller.navigationController?.viewControllers = navigationArray
                    view?.controller.navigationController?.pushViewController(accountExportView.controller, animated: true)
                }
            }
        }
        if let navigationController = view?.controller.navigationController {
            warning.controller.hidesBottomBarWhenPushed = true
            navigationController.pushViewController(warning.controller, animated: true)
        }
    }

    private func createAccountExportView(_ accounts: [AccountItem]) -> AccountExportViewProtocol? {
        let view = AccountExportViewController()

        let presenter = AccountExportPresenter()

        let interactor = AccountExportInteractor(
            keystore: Keychain(),
            settings: SettingsManager.shared,
            accounts: accounts
        )
        let wireframe = AccountExportWireframe(localizationManager: self.localizationManager)

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        let localizationManager = LocalizationManager.shared
        view.localizationManager = localizationManager

        return view
    }

    func showShareFile(url: NSURL, in viewController: AccountExportViewProtocol?) {
        let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)

        activityViewController.completionWithItemsHandler = { (_, completed: Bool, _, _) in
            if completed {
                viewController?.controller.navigationController?.popViewController(animated: true)
            }
        }

        viewController?.controller.present(activityViewController, animated: true)
    }
}
