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
import Combine
import BigInt

final class AssetsItemService {
    let assetProvider: AssetProviderProtocol
    let marketCapService: MarketCapServiceProtocol
    var fiatService: FiatServiceProtocol?
    let assetViewModelsFactory: AssetViewModelFactory
    var priceInfo: PriceInfo?
    var assetManager: AssetManagerProtocol
    var updateHandler: (() -> Void)?
    
    @Published var assetViewModels: [AssetViewModel] = [ AssetViewModel(identifier: "1", title: "", subtitle: "", fiatText: ""),
                                                         AssetViewModel(identifier: "2", title: "", subtitle: "", fiatText: ""),
                                                         AssetViewModel(identifier: "3", title: "", subtitle: "", fiatText: ""),
                                                         AssetViewModel(identifier: "4", title: "", subtitle: "", fiatText: ""),
                                                         AssetViewModel(identifier: "5", title: "", subtitle: "", fiatText: "") ]
    
    @Published var moneyText: String = ""
    
    init(
        marketCapService: MarketCapServiceProtocol,
        fiatService: FiatServiceProtocol?,
        assetViewModelsFactory: AssetViewModelFactory,
        assetManager: AssetManagerProtocol,
        assetProvider: AssetProviderProtocol
    ) {
        self.assetProvider = assetProvider
        self.marketCapService = marketCapService
        self.fiatService = fiatService
        self.assetViewModelsFactory = assetViewModelsFactory
        self.assetManager = assetManager
    }
    
    func setup() {
        let assetIds = (assetManager.getAssetList() ?? []).filter { $0.visible }.map { $0.assetId }
        if priceInfo == nil || assetIds.count != assetViewModels.count {
            let items = assetProvider.getBalances(with: assetIds)

            assetViewModels = items.compactMap { item in
                return self.assetViewModelsFactory.createAssetViewModel(with: item, fiatData: [], mode: .view)
            }
            updateHandler?()
        }

        Task {
            let poolItemInfo = await PriceInfoService.shared.getPriceInfo(for: assetIds)
            self.priceInfo = poolItemInfo
            
            let assetIds = (assetManager.getAssetList() ?? []).filter { $0.visible }.map { $0.assetId } 
            let items = assetProvider.getBalances(with: assetIds)
            
            let fiatDecimal = items.reduce(Decimal(0), { partialResult, balanceData in
                if let priceUsd = poolItemInfo.fiatData.first(where: { $0.id == balanceData.identifier })?.priceUsd?.decimalValue {
                    return partialResult + balanceData.balance.decimalValue * priceUsd
                }
                return partialResult
            })
            
            moneyText = "$" + (NumberFormatter.fiat.stringFromDecimal(fiatDecimal) ?? "")
            
            assetViewModels = items.compactMap { item in
                let deltaPrice = poolItemInfo.marketCapInfo.first(where: { $0.assetId == item.identifier })?.hourDelta
                return self.assetViewModelsFactory.createAssetViewModel(with: item,
                                                                        fiatData: poolItemInfo.fiatData,
                                                                        mode: .view,
                                                                        priceDelta: deltaPrice)
            }
            updateHandler?()
        }
    }
}

extension AssetsItemService: AssetProviderObserverProtocol {
    func processBalance(data: [BalanceData]) {
        setup()
    }
}
