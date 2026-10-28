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

import SoraUIKit
import SoraFoundation

protocol WalletItemFactoryProtocol: AnyObject {

    func createPoolsItem(with walletViewModel: RedesignWalletViewModelProtocol,
                         poolsService: PoolsServiceInputProtocol,
                         networkFacade: WalletNetworkOperationFactoryProtocol,
                         polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
                         assetManager: AssetManagerProtocol,
                         fiatService: FiatServiceProtocol,
                         poolsViewModelService: PoolsItemService,
                         marketCapService: MarketCapServiceProtocol) -> SoramitsuTableViewItemProtocol
    
    func createInviteFriendsItem(with walletViewModel: RedesignWalletViewModelProtocol,
                                 assetManager: AssetManagerProtocol) -> SoramitsuTableViewItemProtocol
    
    func createEditViewItem(with walletViewModel: RedesignWalletViewModel,
                            poolsService: PoolsServiceInputProtocol,
                            editViewService: EditViewServiceProtocol) -> SoramitsuTableViewItemProtocol
    func createBackupItem(with walletViewModel: RedesignWalletViewModelProtocol,
                                 assetManager: AssetManagerProtocol) -> SoramitsuTableViewItemProtocol
}

final class WalletItemFactory: WalletItemFactoryProtocol {

    func createInviteFriendsItem(with walletViewModel: RedesignWalletViewModelProtocol,
                                 assetManager: AssetManagerProtocol) -> SoramitsuTableViewItemProtocol {

        let friendsItem = FriendsItem()
        
        friendsItem.onClose = { [weak walletViewModel] in
            guard let walletViewModel = walletViewModel else { return }
            walletViewModel.closeReferralProgram()
            walletViewModel.updateItems()
        }
        
        friendsItem.onTap = { [weak walletViewModel] in
            guard let walletViewModel = walletViewModel else { return }
            walletViewModel.showReferralProgram(assetManager: assetManager)
        }

        return friendsItem
    }

    func createPoolsItem(with walletViewModel: RedesignWalletViewModelProtocol,
                         poolsService: PoolsServiceInputProtocol,
                         networkFacade: WalletNetworkOperationFactoryProtocol,
                         polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
                         assetManager: AssetManagerProtocol,
                         fiatService: FiatServiceProtocol,
                         poolsViewModelService: PoolsItemService,
                         marketCapService: MarketCapServiceProtocol) -> SoramitsuTableViewItemProtocol {
        let poolsItem = PoolsItem(title: R.string.localizable.pooledAssets(preferredLanguages: .currentLocale), service: poolsViewModelService)
        
        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.pooledAssets(preferredLanguages: locale.rLanguages)
        }
        
        LocalizationManager.shared.addObserver(with: poolsItem) { [weak poolsItem] (_, _) in
            let currentTitle = localizableTitle.value(for: LocalizationManager.shared.selectedLocale)
            poolsItem?.title = currentTitle
        }
        
        let updateHandler = { [weak poolsItem, weak walletViewModel] in
            guard let walletViewModel = walletViewModel, let poolsItem = poolsItem else { return }
            walletViewModel.reloadItem?([poolsItem])
        }
        poolsViewModelService.updateHandler = updateHandler
        
        poolsItem.arrowButtonHandler = { [weak poolsItem] in
            guard let poolsItem = poolsItem else { return }
            poolsItem.isExpand = !poolsItem.isExpand
            walletViewModel.reloadItem?([poolsItem])
        }
        
        poolsItem.expandButtonHandler = { [weak walletViewModel] in
            walletViewModel?.showFullListPools()
        }
        
        poolsItem.poolHandler = { [weak poolsService, weak walletViewModel] identifier in
            guard let poolInfo = poolsService?.getPool(by: identifier) else { return }
            walletViewModel?.showPoolDetails(with: poolInfo)
        }
        
        return poolsItem
    }
    
    func createEditViewItem(with walletViewModel: RedesignWalletViewModel,
                            poolsService: PoolsServiceInputProtocol,
                            editViewService: EditViewServiceProtocol) -> SoramitsuTableViewItemProtocol {
        
        let editViewItem = EditViewItem()
        
        editViewItem.onTap = { [weak walletViewModel] in
            guard let walletViewModel = walletViewModel else { return }
            walletViewModel.showEditView(poolsService: poolsService,
                                         editViewService: editViewService,
                                         completion: walletViewModel.updateItems)
        }
        
        return editViewItem
    }
    
    func createBackupItem(with walletViewModel: RedesignWalletViewModelProtocol,
                          assetManager: AssetManagerProtocol) -> SoramitsuTableViewItemProtocol {
        
        let backupItem = BackupItem()
        
        backupItem.onTap = { [weak walletViewModel] in
            guard let walletViewModel = walletViewModel else { return }
            walletViewModel.showBackupAccount()
        }
        
        return backupItem
    }
}
