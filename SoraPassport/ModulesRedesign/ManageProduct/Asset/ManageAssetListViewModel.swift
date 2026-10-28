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
            filterAssetList(with: normalizedQuery)
        }
    }

    var filteredAssetItems: [AssetListItem] = [] {
        didSet {
            setupTableViewItems(with: isActiveSearch ? filteredAssetItems : assetItems)
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
                // No value is worked out from a balance that was not read.
                guard !item.balanceUnavailable else { return }
                
                let fiatText = FiatTextBuilder().build(fiatData: fiatData, amount: item.balance, assetId: item.assetInfo.assetId)
                
                let priceDelta = marketCapInfo.first(where: { $0.assetId == item.assetInfo.assetId })?.hourDelta
                
                item.assetViewModel.fiatText = fiatText
                item.assetViewModel.deltaPriceText = priceDelta.priceDeltaAttributedText()
            }
            
            DispatchQueue.main.async {
                self.reloadItems?(self.isActiveSearch ? self.filteredAssetItems : self.assetItems)
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

    private var normalizedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var searchText: String = "" {
        didSet { filterAssetList(with: normalizedQuery) }
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
         updateHandler: ((UpdatedSection) -> Void)?,
         priceInfoService: PriceInfoServiceProtocol = PriceInfoService.shared
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
        self.priceInfoService = priceInfoService
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

        Task { @MainActor [weak self] in
            await self?.items(with: balanceData)
        }

        assetsProvider?.add(observer: self)
    }
    
    func viewdismissed() {
        updateHandler?(.assets)
    }
}

extension ManageAssetListViewModel: AssetProviderObserverProtocol {
    func processBalance(data: [BalanceData]) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let ids = (self.assetManager?.getAssetList() ?? []).map { $0.identifier }
            await self.items(with: data.filter { ids.contains($0.identifier) })
        }
    }
}

extension ManageAssetListViewModel {
    /// The list that is saved after editing: the rows as edited, then every
    /// asset of the wallet that had no row (its balance had not arrived
    /// when the list was built). Saving only the rows would take such an
    /// asset out of the wallet until the next start.
    static func listToSave(edited: [AssetInfo], current: [AssetInfo]) -> [AssetInfo] {
        let editedIds = Set(edited.map(\.identifier))
        return edited + current.filter { !editedIds.contains($0.identifier) }
    }
}

private extension ManageAssetListViewModel {
    @MainActor
    func items(with balanceItems: [BalanceData]) async {
        let fiatData = priceInfo?.fiatData ?? []
        let marketCapInfo = priceInfo?.marketCapInfo ?? []
        
        let mode = self.mode
        let factory = assetViewModelFactory
        let ids = (assetManager?.getAssetList() ?? []).map { $0.identifier }
        // An asset whose balance could not be read keeps its row. Leaving
        // it out would also drop it from the list that is saved after
        // editing.
        let items = factory.assetListItems(
            assetIds: ids,
            balances: balanceItems,
            unavailable: assetsProvider?.unavailableBalanceAssetIds(among: ids) ?? [],
            mode: mode
        ) { balance, assetInfo in
            factory.createAssetViewModel(with: balance,
                                         assetInfo: assetInfo,
                                         fiatData: fiatData,
                                         mode: mode,
                                         priceDelta: marketCapInfo.first(where: { $0.assetId == balance.identifier })?.hourDelta)
        }
        items.forEach { item in
            let assetInfo = item.assetInfo
            item.assetHandler = { [weak self] identifier in
                self?.showAssetDetails(with: assetInfo)
            }
            
            item.favoriteHandle = { item in
                item.assetInfo.visible = !item.assetInfo.visible
            }
        }
        assetItems = items.sorted { $0.assetViewModel.isFavorite && !$1.assetViewModel.isFavorite }

        let assetIds = balanceItems.map { $0.identifier }
        priceInfo = await priceInfoService.getPriceInfo(for: assetIds)
    }

    func filterAssetList(with query: String) {
        filteredAssetItems = query.isEmpty ? assetItems : assetItems.filter { item in
            return item.assetInfo.assetId.lowercased().contains(query) ||
            item.assetInfo.symbol.lowercased().contains(query) ||
            item.assetViewModel.title.lowercased().contains(query)
        }
    }

    func saveUpdates() {
        let assetInfos = self.assetItems.map({ $0.assetInfo })
        assetManager?.saveAssetList(
            Self.listToSave(edited: assetInfos, current: assetManager?.getAssetList() ?? [])
        )
    }
    
    func setupTableViewItems(with items: [AssetListItem]) {
        if mode == .edit || isActiveSearch {
            setupItems?(items)
            return
        }

        // An asset whose balance could not be read is not a zero balance:
        // it is never put behind "show zero balances".
        let aboveZero = items.filter { WalletAssetId(rawValue: $0.assetInfo.assetId) != nil || $0.assetInfo.visible || !$0.balance.isZero || $0.balanceUnavailable }
        let underZero = items.filter { WalletAssetId(rawValue: $0.assetInfo.assetId) == nil && !$0.assetInfo.visible && $0.balance.isZero && !$0.balanceUnavailable }
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
