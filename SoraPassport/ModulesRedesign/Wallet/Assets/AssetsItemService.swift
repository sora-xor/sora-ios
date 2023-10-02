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
import CommonWallet

final class AssetsItemService {
    let assetProvider: AssetProviderProtocol
    let assetManager: AssetManagerProtocol
    let marketCapService: MarketCapServiceProtocol
    var fiatService: FiatServiceProtocol?
    let assetViewModelsFactory: AssetViewModelFactory
    let priceTrendService: PriceTrendServiceProtocol = PriceTrendService()
    var poolItemInfo: PriceInfo?
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
        let assetIds = assetManager.getAssetList()?.filter { $0.visible }.map { $0.assetId } ?? []
        if poolItemInfo == nil {
            let items = assetProvider.getBalances(with: assetIds)

            assetViewModels = items.compactMap { item in
                return self.assetViewModelsFactory.createAssetViewModel(with: item, fiatData: [], mode: .view)
            }
            updateHandler?()
        }

        Task {
            let poolItemInfo = await PriceInfoService.shared.getPriceInfo(for: assetIds)
            self.poolItemInfo = poolItemInfo
            
            let assetIds = assetManager.getAssetList()?.filter { $0.visible }.map { $0.assetId } ?? []
            let items = assetProvider.getBalances(with: assetIds)
            
            let fiatDecimal = items.reduce(Decimal(0), { partialResult, balanceData in
                if let priceUsd = poolItemInfo.fiatData.first(where: { $0.id == balanceData.identifier })?.priceUsd?.decimalValue {
                    return partialResult + balanceData.balance.decimalValue * priceUsd
                }
                return partialResult
            })
            
            moneyText = "$" + (NumberFormatter.fiat.stringFromDecimal(fiatDecimal) ?? "")
            
            assetViewModels = items.compactMap { item in
                let deltaPrice = priceTrendService.getPriceTrend(for: item.identifier,
                                                                 fiatData: poolItemInfo.fiatData,
                                                                 marketCapInfo: poolItemInfo.marketCapInfo)
                
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
    func processBalance(data: [CommonWallet.BalanceData]) {
        setup()
    }
}
