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
