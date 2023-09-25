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
import SoraUIKit
import CommonWallet
import RobinHood
import XNetworking

enum PoolItemState {
    case loading
    case empty
    case viewModel
}

struct PoolItemInfo {
    let fiatData: [FiatData]
    let marketCapInfo: [AssetsInfo]
}

final class PoolsItem: NSObject {

    var title: String
    var moneyText: String = ""
    
    var poolViewModels: [PoolViewModel] = []
    var isExpand: Bool
    let poolsService: PoolsServiceInputProtocol?
    let poolViewModelsFactory: PoolViewModelFactory
    weak var fiatService: FiatServiceProtocol?
    var updateHandler: (() -> Void)?
    var expandButtonHandler: (() -> Void)?
    var arrowButtonHandler: (() -> Void)?
    var poolHandler: ((String) -> Void)?
    var state: PoolItemState = .loading
    var priceTrendService: PriceTrendServiceProtocol = PriceTrendService()
    let marketCapService: MarketCapServiceProtocol
    
    init(title: String,
         isExpand: Bool = true,
         poolsService: PoolsServiceInputProtocol?,
         fiatService: FiatServiceProtocol?,
         poolViewModelsFactory: PoolViewModelFactory,
         marketCapService: MarketCapServiceProtocol) {
        self.title = title
        self.isExpand = isExpand
        self.fiatService = fiatService
        self.poolsService = poolsService
        self.poolViewModelsFactory = poolViewModelsFactory
        self.marketCapService = marketCapService
    }
}

extension PoolsItem: PoolsServiceOutput {
    func loaded(pools: [PoolInfo]) {
        Task {
            async let fiatData = fiatService?.getFiat() ?? []
            
            async let marketCapInfo = marketCapService.getMarketCap()
            
            let poolInfo = await PoolItemInfo(fiatData: fiatData, marketCapInfo: marketCapInfo)
            
            let fiatDecimal = pools.filter { $0.isFavorite }.reduce(Decimal(0), { partialResult, pool in
                if let baseAssetPriceUsd = poolInfo.fiatData.first(where: { $0.id == pool.baseAssetId })?.priceUsd?.decimalValue,
                   let targetAssetPriceUsd = poolInfo.fiatData.first(where: { $0.id == pool.targetAssetId })?.priceUsd?.decimalValue,
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
                let poolChangePrice = self.priceTrendService.getPriceTrend(for: item, fiatData: poolInfo.fiatData, marketCapInfo: poolInfo.marketCapInfo)
                return self.poolViewModelsFactory.createPoolViewModel(with: item, fiatData: poolInfo.fiatData, mode: .view, priceTrend: poolChangePrice)
            }

            if self.poolViewModels.isEmpty {
                self.state = .empty
            } else {
                self.state = .viewModel
            }
            
            self.updateHandler?()
        }
    }
}

extension PoolsItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { PoolsCell.self }

    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }

    var clipsToBounds: Bool { false }
}
