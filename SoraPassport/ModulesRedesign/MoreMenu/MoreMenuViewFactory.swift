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
import RobinHood
import SoraKeystore
import SoraFoundation


final class MoreMenuViewFactory {
    static func createView(
        walletContext: CommonWalletContextProtocol,
        fiatService: FiatServiceProtocol,
        balanceFactory: BalanceProviderFactory,
        address: AccountAddress,
        assetsProvider: AssetProviderProtocol,
        assetManager: AssetManagerProtocol
    ) -> MoreMenuViewProtocol? {

        let view = MoreMenuViewController()
        let presenter = MoreMenuPresenter()
        let wireframe = MoreMenuWireframe(
            settingsManager: SettingsManager.shared,
            localizationManager: LocalizationManager.shared,
            walletContext: walletContext,
            fiatService: fiatService,
            balanceFactory: balanceFactory,
            address: address,
            assetsProvider: assetsProvider,
            assetManager: assetManager
        )
        presenter.localizationManager = LocalizationManager.shared
        view.presenter = presenter
        presenter.view = view
        presenter.wireframe = wireframe

        return view
    }
}
