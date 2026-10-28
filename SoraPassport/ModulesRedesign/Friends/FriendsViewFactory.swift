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
import SoraFoundation
import SoraKeystore


final class FriendsViewFactory: FriendsViewFactoryProtocol {
    static func createView(walletContext: CommonWalletContextProtocol,
                           assetManager: AssetManagerProtocol) -> FriendsViewProtocol? {
        let settings = SettingsManager.shared
        let keychain = Keychain()

        let chainId = Chain.sora.genesisHash()
        guard let engine = ChainRegistryFacade.sharedRegistry.getConnection(for: chainId),
              let runtimeRegistry = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: chainId),
              let selectedAccount = SelectedWalletSettings.shared.currentAccount,
              let feeAsset = assetManager.getAssetList()?.first(where: { $0.isFeeAsset })  else { return nil }

        let view = FriendsViewController()
        view.localizationManager = LocalizationManager.shared

        let presenter = FriendsPresenter(settings: settings,
                                         keychain: keychain,
                                         selectedAccount: selectedAccount,
                                         feeAsset: feeAsset)
        presenter.localizationManager = LocalizationManager.shared

        let operationFactory = ReferralsOperationFactory(settings: settings,
                                                         keychain: keychain,
                                                         engine: engine, runtimeRegistry: runtimeRegistry,
                                                         selectedAccount: selectedAccount)

        let interactor = FriendsInteractor(engine: engine,
                                           address: selectedAccount.address,
                                           config: ApplicationConfig.shared,
                                           operationManager: OperationManagerFacade.sharedManager,
                                           keychain: keychain,
                                           operationFactory: operationFactory)

        let wireframe = FriendsWireframe(walletContext: walletContext,
                                         assetManager: assetManager)

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
