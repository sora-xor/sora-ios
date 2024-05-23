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
import RobinHood

import SoraUIKit
import SoraFoundation
import SCard
import IrohaCrypto

protocol WalletItemFactoryProtocol: AnyObject {
    
    func createAccountItem(with walletViewModel: RedesignWalletViewModel,
                           view: RedesignWalletViewProtocol?,
                           wireframe: RedesignWalletWireframeProtocol?,
                           feeProvider: FeeProviderProtocol,
                           assetManager: AssetManagerProtocol,
                           assetsProvider: AssetProviderProtocol,
                           fiatService: FiatServiceProtocol,
                           networkFacade: WalletNetworkOperationFactoryProtocol,
                           providerFactory: BalanceProviderFactory,
                           qrEncoder: WalletQREncoderProtocol,
                           sharingFactory: AccountShareFactoryProtocol,
                           accountRepository: AnyDataProviderRepository<AccountItem>,
                           marketCapService: MarketCapServiceProtocol,
                           reloadItem: (([SoramitsuTableViewItemProtocol]) -> Void)?) -> SoramitsuTableViewItemProtocol

    func createSoraCardItem(with walletViewModel: RedesignWalletViewModelProtocol,
                            service: SCard) -> SoramitsuTableViewItemProtocol

    func createSoraCardExchangeItem(with walletViewModel: RedesignWalletViewModelProtocol) -> SoramitsuTableViewItemProtocol

    func createAssetsItem(with walletViewModel: RedesignWalletViewModelProtocol,
                          assetManager: AssetManagerProtocol,
                          assetsProvider: AssetProviderProtocol,
                          fiatService: FiatServiceProtocol,
                          itemService: AssetsItemService,
                          marketCapService: MarketCapServiceProtocol) -> SoramitsuTableViewItemProtocol
    
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
    
    func createAccountItem(with walletViewModel: RedesignWalletViewModel,
                           view: RedesignWalletViewProtocol?,
                           wireframe: RedesignWalletWireframeProtocol?,
                           feeProvider: FeeProviderProtocol,
                           assetManager: AssetManagerProtocol,
                           assetsProvider: AssetProviderProtocol,
                           fiatService: FiatServiceProtocol,
                           networkFacade: WalletNetworkOperationFactoryProtocol,
                           providerFactory: BalanceProviderFactory,
                           qrEncoder: WalletQREncoderProtocol,
                           sharingFactory: AccountShareFactoryProtocol,
                           accountRepository: AnyDataProviderRepository<AccountItem>,
                           marketCapService: MarketCapServiceProtocol,
                           reloadItem: (([SoramitsuTableViewItemProtocol]) -> Void)?) -> SoramitsuTableViewItemProtocol {
        let currentAccount = SelectedWalletSettings.shared.currentAccount
        var accountName = currentAccount?.username ?? ""
        if accountName.isEmpty {
            accountName = currentAccount?.address ?? ""
        }
        
        let accountItem: AccountTableViewItem = AccountTableViewItem(accountName: accountName)
        accountItem.scanQRHandler = {
            guard let view = view?.controller else { return }
            
            let accountId = try? SS58AddressFactory().accountId(
                fromAddress: currentAccount?.identifier ?? "",
                type: currentAccount?.addressType ?? 69).toHex(includePrefix: true)
            
            wireframe?.showGenerateQR(on: view,
                                      accountId: accountId ?? "",
                                      address: currentAccount?.address ?? "",
                                      username: accountName,
                                      qrEncoder: qrEncoder,
                                      sharingFactory: sharingFactory,
                                      assetManager: assetManager,
                                      assetsProvider: assetsProvider,
                                      networkFacade: networkFacade,
                                      providerFactory: providerFactory,
                                      isScanQRShown: false,
                                      marketCapService: marketCapService,
                                      closeHandler: nil)
        }
        
        accountItem.updateHandler = { [weak accountItem] in
            guard let accountItem = accountItem else { return }
            reloadItem?([accountItem])
        }

        accountItem.accountHandler = { item in
            guard let view = view?.controller else { return }
            
            wireframe?.showManageAccount(on: view, completion: { [weak item] in
                
                let persistentOperation = accountRepository.fetchAllOperation(with: RepositoryFetchOptions())
                
                persistentOperation.completionBlock = {
                    guard let accounts = try? persistentOperation.extractNoCancellableResultData() else { return }
                    
                    let selectedAccountAddress = SelectedWalletSettings.shared.currentAccount?.address ?? ""
                    let selectedAccount =  accounts.first { $0.address == selectedAccountAddress }
                    var selectedAccountName = selectedAccount?.username ?? ""
                    
                    if selectedAccountName.isEmpty {
                        selectedAccountName = selectedAccount?.address ?? ""
                    }
                    item?.accountName = selectedAccountName
                    
                    if let item = item {
                        reloadItem?([item])
                    }
                }
                
                OperationManagerFacade.runtimeBuildingQueue.addOperation(persistentOperation)
            })
        }
        
        return accountItem
    }
    
    func createSoraCardItem(with walletViewModel: RedesignWalletViewModelProtocol,
                            service: SCard) -> SoramitsuTableViewItemProtocol {
        let soraCardItem = SCCardItem(
            service: service
        ) { [weak walletViewModel] in
                guard let walletViewModel = walletViewModel else { return }
                walletViewModel.closeSC()
                walletViewModel.updateItems()
        } onCard: { [weak walletViewModel] in
            guard let walletViewModel = walletViewModel else { return }
            if let isReachable = ReachabilityManager.shared?.isReachable, isReachable {
                walletViewModel.showSoraCardDetails()
            } else {
                walletViewModel.showInternerConnectionAlert()
            }
        }

        return soraCardItem
    }

    func createSoraCardExchangeItem(with walletViewModel: RedesignWalletViewModelProtocol) -> SoramitsuTableViewItemProtocol {
        let soraCardItem = SCBuyXorItem() { [weak walletViewModel] in
                guard let walletViewModel = walletViewModel else { return }
                walletViewModel.closeSCExchange()
                walletViewModel.updateItems()
        } onTap: { [weak walletViewModel] in
            guard let walletViewModel = walletViewModel else { return }
            if let isReachable = ReachabilityManager.shared?.isReachable, isReachable {
                walletViewModel.showSoraCardExchange()
            } else {
                walletViewModel.showInternerConnectionAlert()
            }
        }

        return soraCardItem
    }

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

    func createAssetsItem(with walletViewModel: RedesignWalletViewModelProtocol,
                          assetManager: AssetManagerProtocol,
                          assetsProvider: AssetProviderProtocol,
                          fiatService: FiatServiceProtocol,
                          itemService: AssetsItemService,
                          marketCapService: MarketCapServiceProtocol) -> SoramitsuTableViewItemProtocol {
        
        let assetsItem = AssetsItem(title: R.string.localizable.commonAssets(preferredLanguages: .currentLocale),
                                    assetProvider: assetsProvider,
                                    service: itemService)
        
        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.commonAssets(preferredLanguages: locale.rLanguages)
        }
        
        LocalizationManager.shared.addObserver(with: assetsItem) { [weak assetsItem] (_, _) in
            let currentTitle = localizableTitle.value(for: LocalizationManager.shared.selectedLocale)
            assetsItem?.title = currentTitle
        }
        
        let updateHandler = { [weak walletViewModel, weak assetsItem] in
            guard let walletViewModel = walletViewModel, let assetsItem = assetsItem else { return }
            walletViewModel.reloadItem?([assetsItem])
        }
        assetsItem.updateHandler = updateHandler
        itemService.updateHandler = updateHandler
        
        assetsItem.arrowButtonHandler = { [weak assetsItem] in
            guard let assetsItem = assetsItem else { return }
            assetsItem.isExpand = !assetsItem.isExpand
            walletViewModel.reloadItem?([assetsItem])
        }
        
        assetsItem.expandButtonHandler = { [weak walletViewModel] in
            walletViewModel?.showFullListAssets()
        }
        
        assetsItem.assetHandler = { [weak assetManager, weak walletViewModel] identifier in
            guard let assetInfo = assetManager?.getAssetList()?.first(where: { $0.identifier == identifier }) else { return }
            walletViewModel?.showAssetDetails(with: assetInfo)
        }
        
        return assetsItem
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
