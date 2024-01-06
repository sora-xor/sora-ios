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

import UIKit
import SoraUIKit
import CommonWallet
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
            setupItems?(poolItems)
        }
    }

    var filteredPoolItems: [PoolListItem] = [] {
        didSet {
            setupItems?(filteredPoolItems)
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

    var searchText: String = "" {
        didSet {
            guard !searchText.isEmpty else {
                setupItems?(poolItems)
                return
            }
            filterAssetList(with: searchText.lowercased())
        }
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
    var priceTrendService: PriceTrendServiceProtocol = PriceTrendService()
    let marketCapService: MarketCapServiceProtocol
    let farmingService: DemeterFarmingServiceProtocol
    let feeProvider: FeeProviderProtocol
    let updateHandler: ((UpdatedSection) -> Void)?

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
        filteredPoolItems = self.poolItems.filter { item in
            item.poolViewModel.title.lowercased().contains(query)
        }
    }

    func saveUpdates() {
        let poolInfos = self.poolItems.map({ $0.poolInfo })
        poolsService?.updatePools(poolInfos)
    }
}
