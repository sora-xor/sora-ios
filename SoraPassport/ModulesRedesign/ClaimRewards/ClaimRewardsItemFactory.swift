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

final class ClaimRewardsItemFactory {
    func createClaimRewardsItem(farm: Farm,
                                userFarmInfo: UserFarm?,
                                poolInfo: PoolInfo,
                                userBalance: Decimal,
                                fee: Decimal,
                                fiatData: [PIExactFiatData]?,
                                detailsFactory: DetailViewModelFactoryProtocol,
                                viewModel: ClaimRewardsViewModelProtocol) -> ClaimRewardsItem {
        let detailsViewModel = detailsFactory.createClaimViewModels(with: farm,
                                                                    poolInfo: poolInfo,
                                                                    fee: fee,
                                                                    viewModel: viewModel)
        
        
        let tokenReward = userFarmInfo?.rewards ?? .zero
        let reward = NumberFormatter.cryptoAssets.stringFromDecimal(tokenReward) ?? ""
        let rewardText = "\(reward) \(farm.rewardAsset?.symbol ?? "")"
        
        var fiatRewardText = ""
        if let usdPrice = fiatData?.first(where: { $0.id == farm.rewardAsset?.assetId })?.priceUsd?.decimalValue {
            let tokenUSD = tokenReward * usdPrice
            fiatRewardText = "$" + (NumberFormatter.fiat.stringFromDecimal(tokenUSD) ?? "")
        }
        
        
        let rewardAssetIcon = farm.rewardAsset?.icon ?? ""
        let rewardAssetImage = RemoteSerializer.shared.image(with: rewardAssetIcon)
        
        let claimPossible = fee < userBalance && !fee.isZero
        let claimRewardsItem = ClaimRewardsItem(rewardText: rewardText,
                                                amountText: fiatRewardText,
                                                image: rewardAssetImage,
                                                claimPossible: claimPossible,
                                                detailsViewModel: detailsViewModel)
        
        claimRewardsItem.onClaim = { [weak viewModel] in
            viewModel?.claimButtonTapped()
        }
        
        return claimRewardsItem
    }
}
