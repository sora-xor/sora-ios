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

final class ExploreFarmsViewModelService {
    let demeterFarmingService: DemeterFarmingServiceProtocol
    
    @Published var viewModels: [ExploreFarmViewModel] = {
        let serialNumbers = Array(1...20)
        let shimmersAssetItems = serialNumbers.map {
            ExploreFarmViewModel(serialNumber: String($0))
        }
        return shimmersAssetItems
    }()
    
    init(demeterFarmingService: DemeterFarmingServiceProtocol) {
        self.demeterFarmingService = demeterFarmingService
    }
    
    func setup() {
        Task {
            let farms = try? await self.demeterFarmingService.getAllFarms()
            
            viewModels = farms?.sorted { $0.tvl > $1.tvl }.enumerated().compactMap { (index, farm) in
                return ExploreFarmViewModel(farmId: farm.id,
                                            title: farm.name,
                                            tvl: "$" + (farm.tvl).formatNumber() + " TVL",
                                            serialNumber: String(index + 1),
                                            apr: "\(NumberFormatter.percent.stringFromDecimal(farm.apr * 100) ?? "")% APR",
                                            baseAssetId: farm.baseAsset?.assetId,
                                            poolAssetId: farm.poolAsset?.assetId,
                                            rewardAssetId: farm.rewardAsset?.assetId,
                                            baseAssetIcon: RemoteSerializer.shared.image(with: farm.baseAsset?.icon ?? ""),
                                            targetAssetIcon: RemoteSerializer.shared.image(with: farm.poolAsset?.icon ?? ""),
                                            rewardAssetIcon: RemoteSerializer.shared.image(with: farm.rewardAsset?.icon ?? ""))
            } ?? []
        }
    }
    
    func getFarm(with id: String) -> Farm? {
        return demeterFarmingService.getFarm(with: id)
    }
}
