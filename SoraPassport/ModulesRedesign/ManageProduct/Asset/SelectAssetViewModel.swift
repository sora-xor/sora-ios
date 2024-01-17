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
        priceInfo = await priceInfoService.getPriceInfo(for: assetIds)
        let fiatData = priceInfo?.fiatData ?? []
        let marketCapInfo = priceInfo?.marketCapInfo ?? []
        
        assetItems = balanceItems.compactMap { balance in
            let priceDelta = marketCapInfo.first(where: { $0.assetId == balance.identifier })?.hourDelta
            
            guard let assetInfo = self.assetManager?.assetInfo(for: balance.identifier),
                  let viewModel = self.assetViewModelFactory.createAssetViewModel(with: balance,
                                                                                  assetInfo: assetInfo,
                                                                                  fiatData: fiatData,
                                                                                  mode: self.mode,
                                                                                  priceDelta: priceDelta) else {
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
