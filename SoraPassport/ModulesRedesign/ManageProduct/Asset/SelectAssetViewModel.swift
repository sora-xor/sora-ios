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
import SoraFoundation

protocol SelectAssetViewModelProtocol: Produtable {
    typealias ItemType = AssetListItem
}

final class SelectAssetViewModel {

    var setupNavigationBar: ((WalletViewMode) -> Void)?
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var dismiss: ((Bool) -> Void)?
    var selectionCompletion: ((String) -> Void)?

    var assetItems: [AssetListItem] = [] {
        didSet {
            setupItems?(assetItems)
        }
    }

    var filteredAssetItems: [AssetListItem] = [] {
        didSet {
            setupItems?(filteredAssetItems)
        }
    }

    var mode: WalletViewMode = .selection

    var isActiveSearch: Bool = false {
        didSet {
            setupItems?(isActiveSearch ? filteredAssetItems : assetItems)
        }
    }
    
    var priceInfo: PriceInfo? {
        didSet {
            let fiatData = priceInfo?.fiatData ?? []
            let marketCapInfo = priceInfo?.marketCapInfo ?? []
            
            assetItems.forEach { item in
                
                let fiatText = FiatTextBuilder().build(fiatData: fiatData, amount: item.balance, assetId: item.assetInfo.assetId)
                let deltaPrice = marketCapInfo.first(where: { $0.assetId == item.assetInfo.assetId })?.hourDelta
                
                item.assetViewModel.fiatText = fiatText
                item.assetViewModel.deltaPriceText = deltaPrice.priceDeltaAttributedText()
            }
            
            DispatchQueue.main.async {
                self.reloadItems?(self.assetItems)
            }
        }
    }

    var searchText: String = "" {
        didSet {
            guard !searchText.isEmpty else {
                setupItems?(assetItems)
                return
            }
            filterAssetList(with: searchText.lowercased())
        }
    }

    weak var assetManager: AssetManagerProtocol?
    var assetViewModelFactory: AssetViewModelFactory
    weak var fiatService: FiatServiceProtocol?
    private weak var assetsProvider: AssetProviderProtocol?
    private var marketCapService: MarketCapServiceProtocol
    var assetIds: [String] = []
    private let priceInfoService: PriceInfoServiceProtocol

    init(assetViewModelFactory: AssetViewModelFactory,
         fiatService: FiatServiceProtocol,
         assetManager: AssetManagerProtocol?,
         assetsProvider: AssetProviderProtocol?,
         assetIds: [String],
         marketCapService: MarketCapServiceProtocol) {
        self.assetViewModelFactory = assetViewModelFactory
        self.fiatService = fiatService
        self.assetManager = assetManager
        self.assetsProvider = assetsProvider
        self.assetIds = assetIds
        self.marketCapService = marketCapService
        self.priceInfoService = PriceInfoService.shared
    }
}

extension SelectAssetViewModel: SelectAssetViewModelProtocol {
    var navigationTitle: String {
        R.string.localizable.chooseToken(preferredLanguages: .currentLocale)
    }

    var searchBarPlaceholder: String {
        R.string.localizable.assetListSearchPlaceholder(preferredLanguages: .currentLocale)
    }
    
    func viewDidLoad() {
        setupNavigationBar?(mode)
        if let balanceData = assetsProvider?.getBalances(with: assetIds) {
            Task { [weak self] in
                await self?.items(with: balanceData)
            }
        }
    }
}

private extension SelectAssetViewModel {
    func items(with balanceItems: [BalanceData]) async {
        assetItems = balanceItems.compactMap { balance in
            
            guard let assetInfo = self.assetManager?.assetInfo(for: balance.identifier),
                  let viewModel = self.assetViewModelFactory.createAssetViewModel(with: balance,
                                                                                  assetInfo: assetInfo,
                                                                                  fiatData: [],
                                                                                  mode: self.mode) else {
                return nil
            }
            
            let item = AssetListItem(assetInfo: assetInfo, assetViewModel: viewModel, balance: balance.balance.decimalValue)
            
            item.assetHandler = { [weak self] identifier in
                self?.dismiss?(true)
                self?.selectionCompletion?(identifier)
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
        filteredAssetItems = query == "" ? assetItems : assetItems.filter { item in
            return item.assetInfo.assetId.lowercased().contains(query) ||
            item.assetInfo.symbol.lowercased().contains(query) ||
            item.assetViewModel.title.lowercased().contains(query)
        }
    }

    func saveUpdates() {
        let assetInfos = assetItems.map({ $0.assetInfo })
        assetManager?.saveAssetList(assetInfos)
    }
}
