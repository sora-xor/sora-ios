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
import sorawallet

final class PoolsItemService {
    let marketCapService: MarketCapServiceProtocol
    var fiatService: FiatServiceProtocol?
    let poolViewModelsFactory: PoolViewModelFactory
    var fiatData: [FiatData] = []
    var updateHandler: (() -> Void)?
    
    @Published var poolViewModels: [PoolViewModel] = [
        PoolViewModel(identifier: "1", title: "", subtitle: "", fiatText: ""),
        PoolViewModel(identifier: "2", title: "", subtitle: "", fiatText: ""),
        PoolViewModel(identifier: "3", title: "", subtitle: "", fiatText: ""),
        PoolViewModel(identifier: "4", title: "", subtitle: "", fiatText: ""),
        PoolViewModel(identifier: "5", title: "", subtitle: "", fiatText: "")
    ]
    
    @Published var moneyText: String = ""
    
    init(
        marketCapService: MarketCapServiceProtocol,
        fiatService: FiatServiceProtocol?,
        poolViewModelsFactory: PoolViewModelFactory
    ) {
        self.marketCapService = marketCapService
        self.fiatService = fiatService
        self.poolViewModelsFactory = poolViewModelsFactory
    }
    
    func setup(with pools: [PoolInfo]) {
        if fiatData.isEmpty {
            poolViewModels = pools.filter { $0.isFavorite }.compactMap { item in
                return poolViewModelsFactory.createPoolViewModel(with: item, fiatData: [], mode: .view)
            }

            updateHandler?()
        }
        
        Task { [weak self] in
            guard let self else { return }

            let fiatData = await self.fiatService?.getFiat() ?? []
            self.fiatData = fiatData
            
            let fiatDecimal = pools.filter { $0.isFavorite }.reduce(Decimal(0), { partialResult, pool in
                if let baseAssetPriceUsd = fiatData.first(where: { $0.id == pool.baseAssetId })?.priceUsd?.decimalValue,
                   let targetAssetPriceUsd = fiatData.first(where: { $0.id == pool.targetAssetId })?.priceUsd?.decimalValue,
                   let baseAssetPooledByAccount = pool.baseAssetPooledByAccount,
                   let targetAssetPooledByAccount = pool.targetAssetPooledByAccount {

                    let baseAssetFiatAmount = baseAssetPooledByAccount * baseAssetPriceUsd
                    let targetAssetFiatAmount = targetAssetPooledByAccount * targetAssetPriceUsd
                    return partialResult + baseAssetFiatAmount + targetAssetFiatAmount
                }
                return partialResult
            })
            
            moneyText = "$" + (NumberFormatter.fiat.stringFromDecimal(fiatDecimal) ?? "")
            
            poolViewModels = pools.filter { $0.isFavorite }.compactMap { item in
                return self.poolViewModelsFactory.createPoolViewModel(with: item, fiatData: fiatData, mode: .view)
            }
            updateHandler?()
        }
    }
}

extension PoolsItemService: PoolsServiceOutput {
    func loaded(pools: [PoolInfo]) {
        setup(with: pools)
    }
}
