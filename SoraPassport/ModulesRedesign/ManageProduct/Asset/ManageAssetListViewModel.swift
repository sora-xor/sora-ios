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
import SoraUIKit

import RobinHood

protocol ManageAssetListViewModelProtocol: Produtable {
    typealias ItemType = AssetListItem
}

final class ManageAssetListViewModel {

    var setupNavigationBar: ((WalletViewMode) -> Void)?
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var dismiss: ((Bool) -> Void)?
    var updateHandler: ((UpdatedSection) -> Void)?

    var assetItems: [AssetListItem] = [] {
        didSet {
            setupTableViewItems(with: assetItems)
        }
    }

    var filteredAssetItems: [AssetListItem] = [] {
        didSet {
            setupTableViewItems(with: filteredAssetItems)
        }
    }

    var isNeedZeroBalance: Bool = false {
        didSet {
            setupTableViewItems(with: isActiveSearch ? filteredAssetItems : assetItems)
        }
    }

    var priceInfo: PriceInfo? {
        didSet {
            let fiatData = priceInfo?.fiatData ?? []
            let marketCapInfo = priceInfo?.marketCapInfo ?? []
            
            assetItems.forEach { item in
                
                let fiatText = FiatTextBuilder().build(fiatData: fiatData, amount: item.balance, assetId: item.assetInfo.assetId)
                
                let priceDelta = marketCapInfo.first(where: { $0.assetId == item.assetInfo.assetId })?.hourDelta
                
                item.assetViewModel.fiatText = fiatText
                item.assetViewModel.deltaPriceText = priceDelta.priceDeltaAttributedText()
            }
            
            DispatchQueue.main.async {
                self.reloadItems?(self.assetItems)
            }
        }
    }

    var mode: WalletViewMode = .view {
        didSet {
            if mode == .view {
                saveUpdates()
            }

            setupNavigationBar?(mode)

            assetItems.forEach { item in
                item.assetViewModel.mode = mode
            }

            setupTableViewItems(with: isActiveSearch ? filteredAssetItems : assetItems)
        }
    }

    var isActiveSearch: Bool = false {
        didSet {
            setupTableViewItems(with: isActiveSearch ? filteredAssetItems : assetItems)
        }
    }

    var searchText: String = "" {
        didSet {
            guard !searchText.isEmpty else {
                setupTableViewItems(with: assetItems)
                return
            }
            filterAssetList(with: searchText.lowercased())
        }
    }

    weak var assetManager: AssetManagerProtocol?
    var assetViewModelFactory: AssetViewModelFactory
    weak var fiatService: FiatServiceProtocol?
    var providerFactory: BalanceProviderFactory
    var poolsService: PoolsServiceInputProtocol
    var networkFacade: WalletNetworkOperationFactoryProtocol?
    var accountId: String
    var address: String
    var polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol
    var qrEncoder: WalletQREncoderProtocol
    var sharingFactory: AccountShareFactoryProtocol
    var wireframe: AssetListWireframeProtocol
    weak var view: UIViewController?
    let referralFactory: ReferralsOperationFactoryProtocol
    private weak var assetsProvider: AssetProviderProtocol?
    private let farmingService: DemeterFarmingServiceProtocol
    private var marketCapService: MarketCapServiceProtocol
    private let priceInfoService: PriceInfoServiceProtocol

    init(assetViewModelFactory: AssetViewModelFactory,
         fiatService: FiatServiceProtocol,
         assetManager: AssetManagerProtocol?,
         providerFactory: BalanceProviderFactory,
         poolsService: PoolsServiceInputProtocol,
         networkFacade: WalletNetworkOperationFactoryProtocol?,
         accountId: String,
         address: String,
         polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
         qrEncoder: WalletQREncoderProtocol,
         sharingFactory: AccountShareFactoryProtocol,
         referralFactory: ReferralsOperationFactoryProtocol,
         assetsProvider: AssetProviderProtocol?,
         marketCapService: MarketCapServiceProtocol,
         farmingService: DemeterFarmingServiceProtocol,
         wireframe: AssetListWireframeProtocol,
         updateHandler: ((UpdatedSection) -> Void)?
    ) {
        self.assetViewModelFactory = assetViewModelFactory
        self.fiatService = fiatService
        self.assetManager = assetManager
        self.providerFactory = providerFactory
        self.poolsService = poolsService
        self.networkFacade = networkFacade
        self.accountId = accountId
        self.address = address
        self.polkaswapNetworkFacade = polkaswapNetworkFacade
        self.qrEncoder = qrEncoder
        self.sharingFactory = sharingFactory
        self.referralFactory = referralFactory
        self.updateHandler = updateHandler
        self.assetsProvider = assetsProvider
        self.marketCapService = marketCapService
        self.farmingService = farmingService
        self.wireframe = wireframe
        self.priceInfoService = PriceInfoService.shared
    }
}

extension ManageAssetListViewModel: ManageAssetListViewModelProtocol {
    var searchBarPlaceholder: String {
        R.string.localizable.assetListSearchPlaceholder(preferredLanguages: .currentLocale)
    }

    func viewDidLoad() {
        setupNavigationBar?(mode)
        
        let ids = (assetManager?.getAssetList() ?? []).map { $0.identifier }
        let balanceData = assetsProvider?.getBalances(with: ids) ?? []

        Task { [weak self] in
            await self?.items(with: balanceData)
            self?.priceInfo = await self?.priceInfoService.getPriceInfo(for: ids)
        }

        assetsProvider?.add(observer: self)
    }
    
    func viewdismissed() {
        updateHandler?(.assets)
    }
}

extension ManageAssetListViewModel: AssetProviderObserverProtocol {
    func processBalance(data: [BalanceData]) {
        let ids = (assetManager?.getAssetList() ?? []).map { $0.identifier }
        let balanceData = data.filter { ids.contains($0.identifier) }
        
        Task { [weak self] in
            await self?.items(with: balanceData)
        }
    }
}

private extension ManageAssetListViewModel {
    func items(with balanceItems: [BalanceData]) async {
        let fiatData = priceInfo?.fiatData ?? []
        let marketCapInfo = priceInfo?.marketCapInfo ?? []
        
        assetItems = balanceItems.compactMap { balance in
            let priceDelta = marketCapInfo.first(where: { $0.assetId == balance.identifier })?.hourDelta
            guard let assetInfo = assetManager?.assetInfo(for: balance.identifier),
                  let viewModel = assetViewModelFactory.createAssetViewModel(with: balance,
                                                                             assetInfo: assetInfo,
                                                                             fiatData: fiatData,
                                                                             mode: mode,
                                                                             priceDelta: priceDelta) else {
                return nil
            }
            
            let item = AssetListItem(assetInfo: assetInfo,
                                     assetViewModel: viewModel,
                                     balance: balance.balance.decimalValue)
            
            item.assetHandler = { [weak self] identifier in
                self?.showAssetDetails(with: assetInfo)
            }
            
            item.favoriteHandle = { item in
                item.assetInfo.visible = !item.assetInfo.visible
            }
            
            return item
        }.sorted { $0.assetViewModel.isFavorite && !$1.assetViewModel.isFavorite }

        let assetIds = balanceItems.map { $0.identifier }
        priceInfo = await PriceInfoService.shared.getPriceInfo(for: assetIds)
    }

    func filterAssetList(with query: String) {
        filteredAssetItems = self.assetItems.filter { item in
            return item.assetInfo.assetId.lowercased().contains(query) ||
            item.assetInfo.symbol.lowercased().contains(query) ||
            item.assetViewModel.title.lowercased().contains(query)
        }
    }

    func saveUpdates() {
        let assetInfos = self.assetItems.map({ $0.assetInfo })
        assetManager?.saveAssetList(assetInfos)
    }    
    
    func setupTableViewItems(with items: [AssetListItem]) {
        if mode == .edit || isActiveSearch {
            setupItems?(items)
            return
        }

        let aboveZero = items.filter { WalletAssetId(rawValue: $0.assetInfo.assetId) != nil || $0.assetInfo.visible || !$0.balance.isZero }
        let underZero = items.filter { WalletAssetId(rawValue: $0.assetInfo.assetId) == nil && !$0.assetInfo.visible && $0.balance.isZero }
        var resultItems: [SoramitsuTableViewItemProtocol] = aboveZero
        
        if aboveZero.count < items.count, underZero.count > 0 {
            let zeroItem = ZeroBalanceItem(isShown: isNeedZeroBalance)

            zeroItem.buttonHandler = { [weak self] in
                guard let self = self else { return }
                self.isNeedZeroBalance = !self.isNeedZeroBalance
                self.reloadItems?([zeroItem])
            }

            resultItems.append(zeroItem)
        }
        
        if isNeedZeroBalance {
            resultItems.append(contentsOf: underZero)
        }

        setupItems?(resultItems)
    }
    
    func showAssetDetails(with assetInfo: AssetInfo) {
        guard let assetManager = assetManager, let fiatService = fiatService else { return }

        let factory = AssetViewModelFactory(walletAssets: [assetInfo],
                                            assetManager: assetManager,
                                            fiatService: fiatService)

        let poolFactory = PoolViewModelFactory(walletAssets: assetManager.getAssetList() ?? [],
                                            assetManager: assetManager,
                                               fiatService: fiatService)

        wireframe.showAssetDetails(on: view,
                                   assetInfo: assetInfo,
                                   assetManager: assetManager,
                                   fiatService: fiatService,
                                   assetViewModelFactory: factory,
                                   poolsService: poolsService,
                                   poolViewModelsFactory: poolFactory,
                                   providerFactory: providerFactory,
                                   networkFacade: networkFacade,
                                   accountId: accountId,
                                   address: address,
                                   polkaswapNetworkFacade: polkaswapNetworkFacade,
                                   qrEncoder: qrEncoder,
                                   sharingFactory: sharingFactory,
                                   referralFactory: referralFactory,
                                   assetsProvider: assetsProvider,
                                   marketCapService: marketCapService,
                                   farmingService: farmingService)
    }
}
