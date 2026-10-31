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

final class MainTabBarPresenter {
	weak var view: MainTabBarViewProtocol?
	var interactor: MainTabBarInteractorInputProtocol!
	var wireframe: MainTabBarWireframeProtocol!

    var logger: LoggerProtocol?
}

extension MainTabBarPresenter: MainTabBarPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

extension MainTabBarPresenter: MainTabBarInteractorOutputProtocol {
    func didUserChange() {
        wireframe.recreateWalletViewController(on: view)
    }
    
    func didLanguageChange() {
        wireframe.recreateWalletViewController(on: view)
    }

    func didReceiveWalletAssetList() {
        wireframe.rebuildWalletForArrivedAssetListIfNeeded(on: view)
    }
    
    func didEndTransaction() {

    }

    func didReloadSelectedAccount() {
        wireframe.showNewWalletView(on: view)
    }

    func didReloadSelectedNetwork() {
        wireframe.showNewWalletView(on: view)
        // The reload above reads the asset list again. If it was the first
        // list, the manager no longer sees the wallet as empty and posts no
        // event for it, while the other tabs are still built without assets.
        wireframe.rebuildWalletForArrivedAssetListIfNeeded(on: view)
    }

    func didUpdateWalletInfo() {
        wireframe.reloadWalletContent()
        wireframe.rebuildWalletForArrivedAssetListIfNeeded(on: view)
    }

    func didRequestImportAccount() {
        wireframe.presentAccountImport(on: view)
    }
    func didRequestMigration(with service: MigrationServiceProtocol) {
        wireframe.presentClaim(on: view, with: service)
    }

    func didEndMigration() {
        wireframe.removeClaim(on: view)
    }

    func didFindUnwarnedShortPhraseWallets(_ wallets: [AccountItem]) {
        wireframe.presentShortPhraseWarnings(for: wallets, on: view)
    }

    func didReceive(deepLink: DeepLinkProtocol) {}
}
