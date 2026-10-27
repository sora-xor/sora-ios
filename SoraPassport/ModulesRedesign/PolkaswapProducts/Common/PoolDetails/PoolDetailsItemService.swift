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
