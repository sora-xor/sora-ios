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
import SoraUIKit

import sorawallet
import SSFUtils
import SoraFoundation

final class PoolDetailsItemFactory {
    func createPoolDetailsItem(
        with assetManager: AssetManagerProtocol,
        poolInfo: PoolInfo,
        detailsFactory: DetailViewModelFactoryProtocol,
        viewModel: PoolDetailsViewModelProtocol?,
        farms: [UserFarm],
        service: PoolDetailsItemServiceProtocol
    ) -> PoolDetailsItem {

        let baseAsset = assetManager.assetInfo(for: poolInfo.baseAssetId)
        let targetAsset = assetManager.assetInfo(for: poolInfo.targetAssetId)
        let rewardAsset = assetManager.assetInfo(for: WalletAssetId.pswap.rawValue)
        
        let baseAssetSymbol = baseAsset?.symbol.uppercased() ?? ""
        let targetAssetSymbol = targetAsset?.symbol.uppercased() ?? ""
        
        let poolText = R.string.localizable.polkaswapPoolTitle(preferredLanguages: .currentLocale)
        
        let title = "\(baseAssetSymbol)-\(targetAssetSymbol) \(poolText)"
        
        let accountPoolBalance = poolInfo.accountPoolBalance
        let isRemoveLiquidityEnabled = accountPoolBalance.map { balance in
            !balance.isNaN && balance > 0 && farms.allSatisfy { farm in
                guard let tokens = farm.pooledTokens, !tokens.isNaN, tokens >= 0 else { return false }
                return tokens < balance
            }
        } ?? false
        let isThereLiquidity = [poolInfo.baseAssetPooledByAccount, poolInfo.targetAssetPooledByAccount]
            .allSatisfy { amount in amount.map { !$0.isNaN && $0 > 0 } ?? false }

        let detailsViewModels = detailsFactory.createPoolDetailViewModels(with: poolInfo, apy: nil, viewModel: viewModel)
        
        let detailsItem = PoolDetailsItem(title: title,
                                          firstAssetImage: baseAsset?.icon,
                                          secondAssetImage: targetAsset?.icon,
                                          rewardAssetImage: rewardAsset?.icon,
                                          isRemoveLiquidityEnabled: isRemoveLiquidityEnabled, 
                                          typeImage: isThereLiquidity ? .activePoolWithFarming : .inactivePoolWithFarming,
                                          isThereLiquidity: isThereLiquidity,
                                          detailsViewModels: detailsViewModels,
                                          poolInfo: poolInfo,
                                          service: service)
        detailsItem.handler = { [weak viewModel] type in
            viewModel?.infoButtonTapped(with: type)
        }

        return detailsItem
    }
    
    func farmsItem(with assetManager: AssetManagerProtocol, poolInfo: PoolInfo, farms: [Farm] = []) -> [FarmViewModel] {
        return poolInfo.farms.compactMap { userFarm in

            let baseAsset = assetManager.assetInfo(for: userFarm.baseAssetId)
            let poolAsset = assetManager.assetInfo(for: userFarm.poolAssetId)
            let rewardAsset = assetManager.assetInfo(for: userFarm.rewardAssetId)
            
            let baseAssetSymbol = baseAsset?.symbol ?? ""
            let poolAssetSymbol = poolAsset?.symbol ?? ""
            let rewardAssetSymbol = rewardAsset?.symbol ?? ""
            
            let baseAssetId = baseAsset?.assetId ?? ""
            let poolAssetId = poolAsset?.assetId ?? ""
            let rewardAssetId = rewardAsset?.assetId ?? ""

            let title = "\(baseAssetSymbol)-\(poolAssetSymbol)"
            let id = "\(baseAssetId)-\(poolAssetId)-\(rewardAssetId)"
            
            let rewards = NumberFormatter.cryptoAmounts.stringFromDecimal(userFarm.rewards ?? .zero) ?? ""
            let subtitle = R.string.localizable.poolDetailsReward(preferredLanguages: .currentLocale) + ": \(rewards) \(rewardAssetSymbol)"
            
            let accountPoolBalance = poolInfo.accountPoolBalance ?? .zero
            let pooledTokens = userFarm.pooledTokens ?? .zero
            let percentage = accountPoolBalance > 0 ? (pooledTokens / accountPoolBalance) * 100 : 0

            let percentageText = "\(NumberFormatter.percent.stringFromDecimal(percentage) ?? "")%"
            
            let aprText = farms.first(where: { $0.baseAsset?.assetId == userFarm.baseAssetId &&
                $0.poolAsset?.assetId == userFarm.poolAssetId &&
                $0.rewardAsset?.assetId == userFarm.rewardAssetId })?.aprText(suffix: "% APR") ?? ""
            
            return FarmViewModel(identifier: id,
                                 title: title,
                                 subtitle: subtitle,
                                 baseAssetImage: RemoteSerializer.shared.image(with: baseAsset?.icon ?? ""),
                                 targetAssetImage: RemoteSerializer.shared.image(with: poolAsset?.icon ?? ""),
                                 rewardAssetImage: RemoteSerializer.shared.image(with: rewardAsset?.icon ?? ""),
                                 aprText: aprText,
                                 percentageText: percentageText,
                                 isFarmed: true)
        }
    }
    
    func farmsItem(with farms: [Farm] = []) -> [FarmViewModel] {
        return farms.compactMap { farm in

            let baseAsset = farm.baseAsset
            let poolAsset = farm.poolAsset
            let rewardAsset = farm.rewardAsset
            
            let baseAssetSymbol = baseAsset?.symbol ?? ""
            let poolAssetSymbol = poolAsset?.symbol ?? ""
            
            let baseAssetId = baseAsset?.assetId ?? ""
            let poolAssetId = poolAsset?.assetId ?? ""
            let rewardAssetId = rewardAsset?.assetId ?? ""
            
            let id = "\(baseAssetId)-\(poolAssetId)-\(rewardAssetId)"
            let title = "\(baseAssetSymbol)-\(poolAssetSymbol)"
            
            let subtitle = farm.tvlText()
            
            let aprText = farm.aprText(suffix: "% APR")

            return FarmViewModel(identifier: id,
                                 title: title,
                                 subtitle: subtitle,
                                 baseAssetImage: RemoteSerializer.shared.image(with: baseAsset?.icon ?? ""),
                                 targetAssetImage: RemoteSerializer.shared.image(with: poolAsset?.icon ?? ""),
                                 rewardAssetImage: RemoteSerializer.shared.image(with: rewardAsset?.icon ?? ""),
                                 aprText: aprText,
                                 isFarmed: false)
        }
    }
    
    func farmDetail(with farm: Farm, 
                    poolInfo: PoolInfo?,
                    userFarmInfo: UserFarm?,
                    detailsFactory: DetailViewModelFactoryProtocol,
                    viewModel: FarmDetailsViewModelProtocol,
                    supplyItem: SupplyPoolItem?,
                    fiatData: [PIExactFiatData] = []
    ) -> FarmDetailsItem {
        let baseAssetSymbol = farm.baseAsset?.symbol ?? ""
        let poolAssetSymbol = farm.poolAsset?.symbol ?? ""
        let title = R.string.localizable.polkaswapFarmTitleTemplate("\(baseAssetSymbol)-\(poolAssetSymbol)", preferredLanguages: .currentLocale)
        
        
        let detailsViewModels = detailsFactory.createFarmDetailViewModels(with: farm, 
                                                                          userFarmInfo: userFarmInfo,
                                                                          poolInfo: poolInfo,
                                                                          fiatData: fiatData,
                                                                          viewModel: viewModel)
        
        let rewardsAmount = userFarmInfo?.rewards ?? .zero
        let pooledTokens = userFarmInfo?.pooledTokens ?? .zero
        
        var stackingState: FarmDetailsBottomButtonState = .stackingUnavailable

        if let pooledByAccount = poolInfo?.baseAssetPooledByAccount, !pooledByAccount.isNaN, pooledByAccount > 0 {
            if pooledTokens.isZero {
                stackingState = rewardsAmount.isZero ? .startStacking : .startStackingWithRewards
            } else {
                stackingState = .editFarm
            }
        }
        
        let farmDetailsItem = FarmDetailsItem(title: title,
                                              subtitle: farm.tvlText(suffix: " TVL"),
                                              firstAssetImage: RemoteSerializer.shared.image(with: farm.baseAsset?.icon ?? ""),
                                              secondAssetImage: RemoteSerializer.shared.image(with: farm.poolAsset?.icon ?? ""),
                                              rewardAssetImage: RemoteSerializer.shared.image(with: farm.rewardAsset?.icon ?? ""),
                                              detailsViewModel: detailsViewModels,
                                              typeImage: (userFarmInfo?.pooledTokens ?? 0) > 0 ? .activeFarming : .incativeFarming,
                                              stackingState: stackingState,
                                              areThereRewards: !rewardsAmount.isNaN && rewardsAmount > 0,
                                              supplyItem: supplyItem)
        
        farmDetailsItem.onTapTopButton = { [weak viewModel] in
            viewModel?.claimRewardButtonTapped()
        }
        
        farmDetailsItem.onTapBottomButton = { [weak viewModel] in
            viewModel?.editFarmButtonTapped()
        }
        
        return farmDetailsItem
    }
    
    func createSupplyLiquidityItem(poolViewModel: ExplorePoolViewModel,
                                   viewModel: FarmDetailsViewModelProtocol) -> SupplyPoolItem {
        let supplyItem = SupplyPoolItem(poolViewModel: poolViewModel)
        
        supplyItem.onTap = { [weak viewModel] in
            viewModel?.supplyLiquidityTapped()
        }
        
        return supplyItem
    }
}

extension Decimal {
    var floatValue: Float {
        return NSDecimalNumber(decimal:self).floatValue
    }
}
