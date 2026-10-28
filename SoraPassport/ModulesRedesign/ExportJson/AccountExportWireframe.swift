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

final class AccountExportWireframe: AccountExportWireframeProtocol, AuthorizationPresentable {

    private(set) var localizationManager: LocalizationManagerProtocol

    init(localizationManager: LocalizationManagerProtocol) {
        self.localizationManager = localizationManager
    }

    @MainActor
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
