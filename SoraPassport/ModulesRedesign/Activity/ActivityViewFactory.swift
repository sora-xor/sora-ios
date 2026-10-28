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

protocol ActivityViewFactoryProtocol: AnyObject {
    static func createView(assetManager: AssetManagerProtocol, aseetList: [AssetInfo]) -> ActivityViewController?
}

final class ActivityViewFactory: ActivityViewFactoryProtocol {
    static func createView(assetManager: AssetManagerProtocol, aseetList: [AssetInfo]) -> ActivityViewController? {
        createView(assetManager: assetManager, aseetList: aseetList,
                   selectedAccount: SelectedWalletSettings.shared.currentAccount)
    }

    static func createView(assetManager: AssetManagerProtocol, aseetList: [AssetInfo],
                           selectedAccount: AccountItem?) -> ActivityViewController? {
        guard let selectedAccount else { return nil }

        let localizationManager = LocalizationManager.shared
        let historyService = HistoryService(operationManager: OperationManagerFacade.sharedManager,
                                            address: selectedAccount.address,
                                            assets: aseetList)

        let viewModelFactory = ActivityViewModelFactory(walletAssets: aseetList, assetManager: assetManager)
        let viewModel = ActivityViewModel(historyService: historyService,
                                          viewModelFactory: viewModelFactory,
                                          wireframe: ActivityWireframe(),
                                          assetManager: assetManager,
                                          eventCenter: EventCenter.shared)
        viewModel.localizationManager = localizationManager
        viewModel.title = R.string.localizable.activity(preferredLanguages: .currentLocale)

        localizationManager.addObserver(with: viewModel) { [weak viewModel] (_, _) in
            viewModel?.title = R.string.localizable.activity(preferredLanguages: .currentLocale)
        }

        let view = ActivityViewController(viewModel: viewModel)
        view.localizationManager = localizationManager
        // Clear: the tab bar controller draws the aurora behind every tab.
        view.backgroundColor = .custom(uiColor: .clear)
        viewModel.view = view
        
        return view
    }
}



