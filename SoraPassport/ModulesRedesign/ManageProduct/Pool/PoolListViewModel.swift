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


protocol PoolListViewModelProtocol: Produtable {
    typealias ItemType = PoolListItem
}

final class PoolListViewModel {

    var setupNavigationBar: ((WalletViewMode) -> Void)?
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var dismiss: ((Bool) -> Void)?
    
    var poolItems: [PoolListItem] = [] {
        didSet {
            filterAssetList(with: normalizedQuery)
        }
    }

    var filteredPoolItems: [PoolListItem] = [] {
        didSet {
            setupItems?(isActiveSearch ? filteredPoolItems : poolItems)
        }
    }

    var mode: WalletViewMode = .view {
        didSet {
            if mode == .view {
                saveUpdates()
            }

            setupNavigationBar?(mode)

            poolItems.forEach { item in
                item.poolViewModel.mode = mode
            }

            setupItems?(isActiveSearch ? filteredPoolItems : poolItems)
        }
    }

    var isActiveSearch: Bool = false {
        didSet {
            setupItems?(isActiveSearch ? filteredPoolItems : poolItems)
        }
    }

    private var normalizedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var searchText: String = "" {
        didSet { filterAssetList(with: normalizedQuery) }
    }

    weak var assetManager: AssetManagerProtocol?
    var poolViewModelFactory: PoolViewModelFactory
    var fiatService: FiatServiceProtocol
    var poolsService: PoolsServiceInputProtocol?
    var wireframe: PoolListWireframeProtocol = PoolListWireframe()
    var providerFactory: BalanceProviderFactory
    weak var view: UIViewController?
    var operationFactory: WalletNetworkOperationFactoryProtocol
    var assetsProvider: AssetProviderProtocol
    let marketCapService: MarketCapServiceProtocol
    let farmingService: DemeterFarmingServiceProtocol
    let feeProvider: FeeProviderProtocol
    let updateHandler: ((UpdatedSection) -> Void)?
    private var pricesObservation: PIPricesObservation?

    init(poolsService: PoolsServiceInputProtocol,
         assetManager: AssetManagerProtocol,
         fiatService: FiatServiceProtocol,
         poolViewModelFactory: PoolViewModelFactory,
         providerFactory: BalanceProviderFactory,
         operationFactory: WalletNetworkOperationFactoryProtocol,
         assetsProvider: AssetProviderProtocol,
         marketCapService: MarketCapServiceProtocol,
         farmingService: DemeterFarmingServiceProtocol,
         feeProvider: FeeProviderProtocol,
         updateHandler: ((UpdatedSection) -> Void)?
    ) {
        self.poolViewModelFactory = poolViewModelFactory
        self.fiatService = fiatService
        self.assetManager = assetManager
        self.poolsService = poolsService
        self.providerFactory = providerFactory
        self.operationFactory = operationFactory
        self.assetsProvider = assetsProvider
        self.marketCapService = marketCapService
        self.farmingService = farmingService
        self.feeProvider = feeProvider
        self.updateHandler = updateHandler
    }
    func dismissIfNeeded() {
        if poolItems.isEmpty {
            dismiss?(false)
        }
    }
}

extension PoolListViewModel: PoolListViewModelProtocol {
    
    var searchBarPlaceholder: String {
        R.string.localizable.commonSearchPools(preferredLanguages: .currentLocale)
    }
    
    func viewDidLoad() {
        setupNavigationBar?(mode)

        let pools = poolsService?.getAccountPools() ?? []
        loaded(pools: pools)
        // The first answer can be the catalog of an earlier day, served at
        // once while PI is read. Value the pools again when that read
        // ends. Not while the list is being edited or searched: building
        // it again would undo what the user is doing.
        pricesObservation = PIPricesObservation { [weak self] in
            guard let self, self.mode == .view, !self.isActiveSearch else { return }
            let pools = self.poolItems.map(\.poolInfo)
            guard !pools.isEmpty else { return }
            self.loaded(pools: pools)
        }
    }
    
    func viewdismissed() {
        updateHandler?(.pools)
    }
}

extension PoolListViewModel: PoolsServiceOutput {
    func loaded(pools: [PoolInfo]) {
        Task {
            if pools.isEmpty {
                dismiss?(false)
            }
            
            self.poolItems = try await pools.concurrentMap { pool in
                let fiatData = await self.fiatService.getFiat()
                
                guard let viewModel = self.poolViewModelFactory.createPoolViewModel(with: pool, fiatData: fiatData, mode: .view) else {
                    return nil
                }
                
                let item = PoolListItem(poolInfo: pool, poolViewModel: viewModel)
                item.tapHandler = { [weak self] in
                    self?.showPoolDetails(poolInfo: pool)
                }
                item.favoriteHandle = { item in
                    item.poolInfo.isFavorite = !item.poolInfo.isFavorite
                }
                return item
            }.sorted { $0.poolViewModel.isFavorite && !$1.poolViewModel.isFavorite }
        }
    }
    
    func showPoolDetails(poolInfo: PoolInfo) {
        guard let assetManager = assetManager, let poolsService = poolsService else { return }

        wireframe.showPoolDetails(on: view,
                                  poolInfo: poolInfo,
                                  assetManager: assetManager,
                                  fiatService: fiatService,
                                  poolsService: poolsService,
                                  providerFactory: providerFactory,
                                  operationFactory: operationFactory,
                                  assetsProvider: assetsProvider,
                                  marketCapService: marketCapService, 
                                  farmingService: farmingService,
                                  feeProvider: feeProvider,
                                  dismissHandler: dismissIfNeeded)
    }
}

private extension PoolListViewModel {
    func filterAssetList(with query: String) {
        filteredPoolItems = query.isEmpty ? poolItems : poolItems.filter { item in
            item.poolViewModel.title.lowercased().contains(query)
        }
    }

    func saveUpdates() {
        let poolInfos = self.poolItems.map({ $0.poolInfo })
        poolsService?.updatePools(poolInfos)
    }
}
