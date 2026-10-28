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

import SoraUIKit
import sorawallet
import SoraFoundation

final class AssetDetailsItemFactory {
    
    private weak var assetsProvider: AssetProviderProtocol?
    private let poolViewModelsFactory: PoolViewModelFactory
    private let historyService: HistoryServiceProtocol
    private var recentActivityService: RecentActivityItemService
    private let wireframe: AssetDetailsWireframeProtocol
    private let poolsService: PoolsServiceInputProtocol?
    private let transferableItemService: TransferableItemService
    
    init(assetsProvider: AssetProviderProtocol? = nil,
         poolViewModelsFactory: PoolViewModelFactory,
         historyService: HistoryServiceProtocol,
         recentActivityService: RecentActivityItemService,
         wireframe: AssetDetailsWireframeProtocol,
         poolsService: PoolsServiceInputProtocol?,
         transferableItemService: TransferableItemService) {
        self.assetsProvider = assetsProvider
        self.poolViewModelsFactory = poolViewModelsFactory
        self.historyService = historyService
        self.recentActivityService = recentActivityService
        self.wireframe = wireframe
        self.poolsService = poolsService
        self.transferableItemService = transferableItemService
    }
    
    /// - Parameters:
    ///   - usdPrice: `nil` when the price is not known.
    ///   - pricesLoaded: The price read has finished. An unknown price then
    ///     reads "Price unavailable"; before, it is left blank.
    func createPriceItem(with asset: AssetInfo, 
                         usdPrice: Decimal?,
                         priceInfo: PriceInfo,
                         pricesLoaded: Bool = true) -> SoramitsuTableViewItemProtocol {
        let priceDelta = priceInfo.marketCapInfo.first(where: { $0.assetId == asset.identifier })?.hourDelta
        let priceDeltaText = priceDelta.priceDeltaAttributedText()
        
        return PriceItem(icon: asset.icon,
                         tokenName: asset.name,
                         tokenSymbol: asset.symbol,
                         priceText: Self.priceText(usdPrice: usdPrice, pricesLoaded: pricesLoaded),
                         deltaPriceText: priceDeltaText)
    }
    
    /// The headline price: the price, nothing while it is loading, or the
    /// "Price unavailable" notice. Never "$0" for want of a price.
    static func priceText(usdPrice: Decimal?, pricesLoaded: Bool) -> String {
        if let usdPrice {
            return usdPrice.assetDetailPriceText()
        }
        return pricesLoaded ? WalletUX.priceUnavailableText : ""
    }

    func createTranferableItem(with assetInfo: AssetInfo,
                               usdPrice: Decimal?,
                               referralBalance: Decimal?,
                               wireframe: AssetDetailsWireframeProtocol,
                               frozenDetailsHandler: ((BalanceContext) -> Void)?
    ) -> TransferableItem {
        let readBalance = assetsProvider?.getBalances(with: [assetInfo.identifier]).first
        // A balance that could not be read is shown as unavailable, not as
        // the zero the placeholder below carries, and no value or frozen
        // part is worked out from that zero.
        let balanceUnavailable = readBalance == nil && (assetsProvider?
            .unavailableBalanceAssetIds(among: [assetInfo.identifier])
            .contains(assetInfo.identifier) ?? false)
        let balance = readBalance ?? BalanceData(identifier: "",
                                                 balance: AmountDecimal(value: 0))

        // Without a price the value is unknown: no fiat text, not "$0".
        let fiatBalanceText = balanceUnavailable
            ? ""
            : WalletUX.balanceFiatText(amount: balance.balance.decimalValue, price: usdPrice)

        let balanceContext = BalanceContext(context: balance.context ?? [:])
        let frozen = balanceContext.frozen
        let referral = referralBalance ?? Decimal(0)
        let frozenAmount = Amount(value: balanceUnavailable ? 0 : frozen + referral)

        let frozenFiat = balanceUnavailable
            ? ""
            : WalletUX.balanceFiatText(amount: frozenAmount.decimalValue, price: usdPrice)
        
        transferableItemService.usdPrice = usdPrice
        transferableItemService.balanceContext = balanceContext
        
        let transferableItem = TransferableItem(assetInfo: assetInfo,
                                                fiat: fiatBalanceText,
                                                balance: Amount(value: balance.balance.decimalValue),
                                                frozenAmount: frozenAmount,
                                                frozenFiatAmount: frozenFiat,
                                                service: transferableItemService,
                                                balanceData: balance,
                                                balanceUnavailable: balanceUnavailable)

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
            }
        }
    
        return transferableItem
    }
    
    func createPooledItem(with assetInfo: AssetInfo, fiatData: [PIExactFiatData]) -> PooledItem? {
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
