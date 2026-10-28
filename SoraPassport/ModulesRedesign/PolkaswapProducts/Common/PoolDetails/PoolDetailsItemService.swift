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
    /// Empty while the value is loading.
    var tvlTextPublisher: Published<String>.Publisher { get }
    /// The price read has finished without a price for this pool: the
    /// header then shows no value instead of a placeholder that never ends.
    var tvlUnavailablePublisher: Published<Bool>.Publisher { get }
    var detailsPublisher: Published<[DetailViewModel]>.Publisher { get }
    func setup(with poolInfo: PoolInfo)
}

final class PoolDetailsItemService: PoolDetailsItemServiceProtocol {
    @Published var tvlText: String = ""
    var tvlTextPublisher: Published<String>.Publisher { $tvlText }
    @Published var tvlUnavailable = false
    var tvlUnavailablePublisher: Published<Bool>.Publisher { $tvlUnavailable }
    private var pricesObserver: NSObjectProtocol?

    deinit {
        if let pricesObserver {
            NotificationCenter.default.removeObserver(pricesObserver)
        }
    }
    
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
        if pricesObserver == nil {
            // Prices arrived or were refreshed: value the pool again.
            pricesObserver = NotificationCenter.default.addObserver(
                forName: PICatalogs.pricesDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.loadValue(of: poolInfo)
            }
        }
        loadValue(of: poolInfo)
        
        Task { [weak self] in
            guard let self else { return }
            let apy = await self.apyService.getApy(for: poolInfo.baseAssetId, targetAssetId: poolInfo.targetAssetId)
            let details = self.detailsFactory.createPoolDetailViewModels(with: poolInfo, apy: apy, viewModel: self.viewModel)
            self.details = details
        }
    }

    private func loadValue(of poolInfo: PoolInfo) {
        Task { [weak self] in
            guard let self else { return }
            let fiatData = await self.fiatService.getFiat()
            // Without a price the value is unknown: the header shows no
            // value, neither "$0 TVL" nor a placeholder that never ends.
            guard let priceUsd = fiatData.first(where: { $0.id == poolInfo.baseAssetId })?.priceUsd?.decimalValue else {
                self.tvlUnavailable = true
                return
            }
            let reserves = poolInfo.baseAssetReserves ?? .zero
            self.tvlUnavailable = false
            self.tvlText = "$" + (priceUsd * reserves * 2).formatNumber() + " TVL"
        }
    }
}
