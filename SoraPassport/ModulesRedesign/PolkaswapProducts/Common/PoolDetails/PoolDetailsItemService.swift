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
            notificationCenter.removeObserver(pricesObserver)
        }
    }
    
    @Published var details: [DetailViewModel] = []
    var detailsPublisher: Published<[DetailViewModel]>.Publisher { $details }

    weak var viewModel: PoolDetailsViewModelProtocol?
    private var poolInfo: PoolInfo
    private let notificationCenter: NotificationCenter
    private var valueRequest = UUID()
    private var detailsRequest = UUID()
    private let apyService: APYServiceProtocol
    private let fiatService: FiatServiceProtocol
    private let detailsFactory: DetailViewModelFactoryProtocol
    
    init(
        poolInfo: PoolInfo,
        apyService: APYServiceProtocol,
        fiatService: FiatServiceProtocol,
        detailsFactory: DetailViewModelFactoryProtocol,
        notificationCenter: NotificationCenter = .default
    ) {
        self.poolInfo = poolInfo
        self.apyService = apyService
        self.fiatService = fiatService
        self.detailsFactory = detailsFactory
        self.notificationCenter = notificationCenter
    }
    
    func setup(with poolInfo: PoolInfo) {
        let changedPool = self.poolInfo.baseAssetId != poolInfo.baseAssetId ||
            self.poolInfo.targetAssetId != poolInfo.targetAssetId
        self.poolInfo = poolInfo
        if changedPool {
            tvlText = ""
            tvlUnavailable = false
            details = []
        }
        if pricesObserver == nil {
            // Prices arrived or were refreshed: value the pool again.
            pricesObserver = notificationCenter.addObserver(
                forName: PICatalogs.pricesDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                self.loadValue(of: self.poolInfo)
            }
        }
        loadValue(of: poolInfo)
        
        let request = UUID()
        detailsRequest = request
        Task { @MainActor [weak self, apyService] in
            let apy = await apyService.getApy(for: poolInfo.baseAssetId, targetAssetId: poolInfo.targetAssetId)
            guard let self, self.detailsRequest == request else { return }
            self.details = self.detailsFactory.createPoolDetailViewModels(with: poolInfo, apy: apy, viewModel: self.viewModel)
        }
    }

    private func loadValue(of poolInfo: PoolInfo) {
        let request = UUID()
        valueRequest = request
        Task { @MainActor [weak self, fiatService] in
            let fiatData = await fiatService.getFiat()
            guard let self, self.valueRequest == request else { return }
            // Without a price the value is unknown: the header shows no
            // value, neither "$0 TVL" nor a placeholder that never ends.
            guard let priceUsd = fiatData.first(where: { $0.id == poolInfo.baseAssetId })?.priceUsd?.decimalValue else {
                self.tvlUnavailable = true
                self.tvlText = ""
                return
            }
            let reserves = poolInfo.baseAssetReserves ?? .zero
            self.tvlUnavailable = false
            self.tvlText = "$" + (priceUsd * reserves * 2).formatNumber() + " TVL"
        }
    }
}
