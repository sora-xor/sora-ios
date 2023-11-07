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

import SoraUIKit
import sorawallet
import SoraFoundation
import CommonWallet
import SCard

final class AssetDetailsItemFactory {
    
    private weak var assetsProvider: AssetProviderProtocol?
    private let priceTrendService: PriceTrendServiceProtocol
    private let poolViewModelsFactory: PoolViewModelFactory
    private let historyService: HistoryServiceProtocol
    private var recentActivityService: RecentActivityItemService
    private let wireframe: AssetDetailsWireframeProtocol
    private let poolsService: PoolsServiceInputProtocol?
    private let transferableItemService: TransferableItemService
    
    init(assetsProvider: AssetProviderProtocol? = nil,
         priceTrendService: PriceTrendServiceProtocol = PriceTrendService(),
         poolViewModelsFactory: PoolViewModelFactory,
         historyService: HistoryServiceProtocol,
         recentActivityService: RecentActivityItemService,
         wireframe: AssetDetailsWireframeProtocol,
         poolsService: PoolsServiceInputProtocol?,
         transferableItemService: TransferableItemService) {
        self.assetsProvider = assetsProvider
        self.priceTrendService = priceTrendService
        self.poolViewModelsFactory = poolViewModelsFactory
        self.historyService = historyService
        self.recentActivityService = recentActivityService
        self.wireframe = wireframe
        self.poolsService = poolsService
        self.transferableItemService = transferableItemService
    }
    
    func createPriceItem(with asset: AssetInfo, 
                         usdPrice: Decimal,
                         priceInfo: PriceInfo) -> SoramitsuTableViewItemProtocol {
        let priceDelta: Decimal? = priceTrendService.getPriceTrend(for: asset.identifier,
                                                                     fiatData: priceInfo.fiatData,
                                                                     marketCapInfo: priceInfo.marketCapInfo)
        let priceDeltaText = priceDelta.priceDeltaAttributedText()
        
        return PriceItem(icon: asset.icon,
                         tokenName: asset.name,
                         tokenSymbol: asset.symbol,
                         priceText: usdPrice.assetDetailPriceText(),
                         deltaPriceText: priceDeltaText)
    }
    
    func createTranferableItem(with assetInfo: AssetInfo,
                               usdPrice: Decimal,
                               referralBalance: Decimal?,
                               wireframe: AssetDetailsWireframeProtocol,
                               frozenDetailsHandler: ((BalanceContext) -> Void)?
    ) -> TransferableItem {
        let balance = assetsProvider?.getBalances(with: [assetInfo.identifier]).first ?? BalanceData(identifier: "",
                                                                                                     balance: AmountDecimal(value: 0))

        let fiatDecimal = balance.balance.decimalValue * usdPrice
        let fiatBalanceText = fiatDecimal.priceText()

        let balanceContext = BalanceContext(context: balance.context ?? [:])
        let frozen = balanceContext.frozen
        let referral = referralBalance ?? Decimal(0)
        let frozenAmount = Amount(value: frozen + referral)

        let frozenFiat = (frozenAmount.decimalValue * usdPrice).priceText()
        
        transferableItemService.usdPrice = usdPrice
        transferableItemService.balanceContext = balanceContext
        
        let transferableItem = TransferableItem(assetInfo: assetInfo,
                                                fiat: fiatBalanceText,
                                                balance: Amount(value: balance.balance.decimalValue),
                                                frozenAmount: frozenAmount,
                                                frozenFiatAmount: frozenFiat,
                                                service: transferableItemService,
                                                balanceData: balance)

        transferableItem.actionHandler = { [weak self] type in
            switch type {
            case .frozenDetails:
                frozenDetailsHandler?(balanceContext)
            case .send:
                self?.wireframe.showSend()
            case .receive:
                self?.wireframe.showReceive()
            case .swap:
                self?.wireframe.showSwap()
            case .buy:
                guard let scard = SCard.shared else { return }
                self?.wireframe.showXOne(service: scard)
            }
        }
    
        return transferableItem
    }
    
    func createPooledItem(with assetInfo: AssetInfo, fiatData: [FiatData]) -> PooledItem? {
        guard let pools = poolsService?.loadPools(currentAsset: assetInfo), !pools.isEmpty else {
            return nil
        }

        let viewModels = pools.compactMap { pool in
            poolViewModelsFactory.createPoolViewModel(with: pool, fiatData: fiatData, mode: .view)
        }
        
        let poolsItem = PooledItem(assetSymbol: assetInfo.symbol, poolViewModels: viewModels)

        poolsItem.openPoolDetailsHandler = { [weak self] id in
            guard let self = self, let poolsService = self.poolsService, let poolInfo = pools.first(where: { $0.poolId == id }) else { return }
            self.wireframe.showPoolDetails(poolInfo: poolInfo, poolsService: poolsService)
        }

        return poolsItem
    }
    
    func createRecentActivity(with assetId: String, updateHandler: @escaping (SoramitsuTableViewItemProtocol) -> Void) -> RecentActivityItem {
        let activityItem = RecentActivityItem(service: recentActivityService)
        
        activityItem.openActivityDetailsHandler = { [weak self] blockHash in
            guard let self = self, let transaction = self.historyService.getTransaction(by: blockHash) else { return }
            self.wireframe.showActivityDetails(model: transaction)
        }
        
        activityItem.openFullActivityHandler = { [weak self] in
            guard let self = self else { return }
            self.wireframe.showActivity(assetId: assetId)
        }
        
        recentActivityService.updateHandler = {
            updateHandler(activityItem)
        }

        return activityItem
    }
}
