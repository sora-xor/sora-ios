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


protocol PoolDetailsItemServiceProtocol: AnyObject {
    var tvlTextPublisher: Published<String>.Publisher { get }
    var detailsPublisher: Published<[DetailViewModel]>.Publisher { get }
    func setup(with poolInfo: PoolInfo)
}

final class PoolDetailsItemService: PoolDetailsItemServiceProtocol {
    @Published var tvlText: String = ""
    var tvlTextPublisher: Published<String>.Publisher { $tvlText }
    
    @Published var details: [DetailViewModel] = []
    var detailsPublisher: Published<[DetailViewModel]>.Publisher { $details }

    weak var viewModel: PoolDetailsViewModelProtocol?
    private let poolInfo: PoolInfo
    private let apyService: APYServiceProtocol
    private let fiatService: FiatServiceProtocol
    private let detailsFactory: DetailViewModelFactoryProtocol
    
    init(
        poolInfo: PoolInfo,
        apyService: APYServiceProtocol,
        fiatService: FiatServiceProtocol,
        detailsFactory: DetailViewModelFactoryProtocol
    ) {
        self.poolInfo = poolInfo
        self.apyService = apyService
        self.fiatService = fiatService
        self.detailsFactory = detailsFactory
    }
    
    func setup(with poolInfo: PoolInfo) {
        Task { [weak self] in
            guard let self else { return }
            let fiatData = await self.fiatService.getFiat()
            let priceUsd = fiatData.first(where: { $0.id == poolInfo.baseAssetId })?.priceUsd?.decimalValue ?? .zero
            let reserves = poolInfo.baseAssetReserves ?? .zero
            self.tvlText = "$" + (priceUsd * reserves * 2).formatNumber() + " TVL"
        }
        
        Task { [weak self] in
            guard let self else { return }
            let apy = await self.apyService.getApy(for: poolInfo.baseAssetId, targetAssetId: poolInfo.targetAssetId)
            let details = self.detailsFactory.createPoolDetailViewModels(with: poolInfo, apy: apy, viewModel: self.viewModel)
            self.details = details
        }
    }
}
