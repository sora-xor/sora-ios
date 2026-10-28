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

final class ExplorePoolsViewModelService {
    var apyService: APYServiceProtocol
    let itemFactory: ExploreItemFactory
    var poolsService: ExplorePoolsServiceInputProtocol
    
    @Published var viewModels: [ExplorePoolViewModel] = {
        let serialNumbers = Array(1...20)
        let shimmersAssetItems = serialNumbers.map {
            ExplorePoolViewModel(serialNumber: String($0))
        }
        return shimmersAssetItems
    }()
    
    init(
        itemFactory: ExploreItemFactory,
        poolsService: ExplorePoolsServiceInputProtocol,
        apyService: APYServiceProtocol
    ) {
        self.poolsService = poolsService
        self.itemFactory = itemFactory
        self.apyService = apyService
    }
    
    func setup() {
        Task {
            let fiatData = await FiatService.shared.getFiat()
            let pools = (try? await poolsService.getPools(with: fiatData)) ?? []
            
            viewModels = pools.enumerated().compactMap { (index, pool) in
                return itemFactory.createPoolsItem(with: pool, serialNumber: String(index + 1))
            }
            
            async let viewModels = (pools.enumerated().concurrentMap { (index, pool) in
                let apy = await self.apyService.getApy(for: pool.baseAssetId, targetAssetId: pool.targetAssetId)
                return self.itemFactory.createPoolsItem(with: pool, serialNumber: String(index + 1), apy: apy)
            })

            let result = (try? await viewModels) ?? []
            
            if result.isEmpty {
                setup()
            } else {
                self.viewModels = result
            }
        }
    }
}
