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
import RobinHood
import SoraFoundation

final class AccountExportRawSeedViewFactory: AccountExportRawSeedViewFactoryProtocol {
    static func createView(account: AccountItem) -> AccountExportRawSeedViewProtocol? {
        let view = AccountExportRawSeedViewController()
        let presenter = AccountExportRawSeedPresenter()
        let interactor = AccountExportRawSeedInteractor(
            keystore: Keychain(),
            settings: SettingsManager.shared,
            account: account
        )

        view.localizationManager = LocalizationManager.shared
        view.presenter = presenter
        presenter.view = view
        presenter.exportJSONAction = { [weak view] in
            guard let jsonView = AccountExportViewFactory.createView(accounts: [account]) else { return }
            view?.navigationController?.pushViewController(jsonView.controller, animated: true)
        }
        presenter.interactor = interactor
        interactor.presenter = presenter

        return view
    }
}
