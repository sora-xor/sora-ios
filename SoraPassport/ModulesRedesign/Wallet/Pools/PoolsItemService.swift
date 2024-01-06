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
import Combine
import BigInt
import sorawallet

final class PoolsItemService {
    let marketCapService: MarketCapServiceProtocol
    var fiatService: FiatServiceProtocol?
    let poolViewModelsFactory: PoolViewModelFactory
    let priceTrendService: PriceTrendServiceProtocol = PriceTrendService()
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
            self.poolViewModels = pools.filter { $0.isFavorite }.compactMap { item in
                return self.poolViewModelsFactory.createPoolViewModel(with: item, fiatData: [], mode: .view)
            }

            self.updateHandler?()
        }
        
        Task {
            let fiatData = await fiatService?.getFiat() ?? []
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
            
            self.moneyText = "$" + (NumberFormatter.fiat.stringFromDecimal(fiatDecimal) ?? "")
            
            self.poolViewModels = pools.filter { $0.isFavorite }.compactMap { item in
                return self.poolViewModelsFactory.createPoolViewModel(with: item, fiatData: fiatData, mode: .view)
            }
            self.updateHandler?()
        }
    }
}

extension PoolsItemService: PoolsServiceOutput {
    func loaded(pools: [PoolInfo]) {
        setup(with: pools)
    }
}
