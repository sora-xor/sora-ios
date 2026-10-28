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
import sorawallet

final class PoolsItemService {
    let marketCapService: MarketCapServiceProtocol
    var fiatService: FiatServiceProtocol?
    let poolViewModelsFactory: PoolViewModelFactory
    var fiatData: [PIExactFiatData] = []
    var updateHandler: (() -> Void)?
    
    @Published var poolViewModels: [PoolViewModel] = [
        PoolViewModel(identifier: "1", title: "", subtitle: "", fiatText: ""),
        PoolViewModel(identifier: "2", title: "", subtitle: "", fiatText: ""),
        PoolViewModel(identifier: "3", title: "", subtitle: "", fiatText: ""),
        PoolViewModel(identifier: "4", title: "", subtitle: "", fiatText: ""),
        PoolViewModel(identifier: "5", title: "", subtitle: "", fiatText: "")
    ]
    
    /// Empty while loading, the total once prices are known, or the "price
    /// unavailable" notice. Never "$0" for want of prices.
    @Published var moneyText: String = ""
    /// Set before `moneyText`, so the cell can style the notice.
    private(set) var priceIsUnavailable = false

    private let priceRetryLock = NSLock()
    private var priceRetry: Task<Void, Never>?
    private var priceFailures = 0
    private var lastPools: [PoolInfo]?
    private var pricesObserver: NSObjectProtocol?

    deinit {
        priceRetry?.cancel()
        if let pricesObserver {
            NotificationCenter.default.removeObserver(pricesObserver)
        }
    }

    init(
        marketCapService: MarketCapServiceProtocol,
        fiatService: FiatServiceProtocol?,
        poolViewModelsFactory: PoolViewModelFactory
    ) {
        self.marketCapService = marketCapService
        self.fiatService = fiatService
        self.poolViewModelsFactory = poolViewModelsFactory
    }
    
    func setup(with pools: [PoolInfo]) {
        lastPools = pools
        if pricesObserver == nil {
            // Prices were refreshed in the background, or the app came back
            // to the foreground: value the pools again.
            pricesObserver = NotificationCenter.default.addObserver(
                forName: PICatalogs.pricesDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self, let pools = self.lastPools else { return }
                self.setup(with: pools)
            }
        }
        if fiatData.isEmpty {
            poolViewModels = pools.filter { $0.isFavorite }.compactMap { item in
                return poolViewModelsFactory.createPoolViewModel(with: item, fiatData: [], mode: .view)
            }

            updateHandler?()
        }
        
        Task { [weak self] in
            guard let self else { return }

            let fiatData = await self.fiatService?.getFiat() ?? []
            self.fiatData = fiatData
            
            let fiatDecimal = pools.filter { $0.isFavorite }.reduce(Decimal(0), { partialResult, pool in
                if let baseAssetPriceUsd = fiatData.first(where: { $0.id == pool.baseAssetId })?.priceUsd?.decimalValue,
                   let targetAssetPriceUsd = fiatData.first(where: { $0.id == pool.targetAssetId })?.priceUsd?.decimalValue,
                   let baseAssetPooledByAccount = pool.baseAssetPooledByAccount,
                   let targetAssetPooledByAccount = pool.targetAssetPooledByAccount {

                    let baseAssetFiatAmount = baseAssetPooledByAccount * baseAssetPriceUsd
                    let targetAssetFiatAmount = targetAssetPooledByAccount * targetAssetPriceUsd
                    return partialResult + baseAssetFiatAmount + targetAssetFiatAmount
                }
                return partialResult
            })
            
            // As for the liquid assets: with pooled tokens and no price for
            // any of the pools, the value is unknown, not "$0". Asking
            // again only helps when the prices could not be read.
            let pricesAvailable = Self.pricesKnown(for: pools.filter { $0.isFavorite }, fiatData: fiatData)
            priceIsUnavailable = !pricesAvailable
            moneyText = WalletUX.fiatTotalText(fiatDecimal, pricesAvailable: pricesAvailable)
            schedulePriceRetry(needed: fiatData.isEmpty, pools: pools)
            
            poolViewModels = pools.filter { $0.isFavorite }.compactMap { item in
                var viewModel = self.poolViewModelsFactory.createPoolViewModel(with: item, fiatData: fiatData, mode: .view)
                // The price read is over: a pool without a price shows no
                // value instead of a placeholder that never ends.
                viewModel?.priceLoadFinished = true
                return viewModel
            }
            updateHandler?()
        }
    }
}

extension PoolsItemService {
    /// Whether a total can be given for these pool positions: the prices
    /// were read, and at least one position has a price for both of its
    /// assets (or there is no position at all).
    static func pricesKnown(for pools: [PoolInfo], fiatData: [PIExactFiatData]) -> Bool {
        guard !fiatData.isEmpty else { return false }
        let held = pools.filter {
            ($0.baseAssetPooledByAccount ?? 0) > 0 || ($0.targetAssetPooledByAccount ?? 0) > 0
        }
        guard !held.isEmpty else { return true }
        return held.contains { pool in
            fiatData.first(where: { $0.id == pool.baseAssetId })?.priceUsd?.decimalValue != nil &&
                fiatData.first(where: { $0.id == pool.targetAssetId })?.priceUsd?.decimalValue != nil
        }
    }
}

private extension PoolsItemService {
    /// While prices are unavailable, asks again by itself so the notice is
    /// replaced as soon as PI answers; nothing is asked of the user.
    func schedulePriceRetry(needed: Bool, pools: [PoolInfo]) {
        priceRetryLock.lock()
        defer { priceRetryLock.unlock() }
        // A newer pool list replaces a retry planned for an older one.
        priceRetry?.cancel()
        priceRetry = nil
        guard needed else {
            priceFailures = 0
            return
        }
        let delay = WalletUX.priceRetryDelay(afterFailures: priceFailures)
        priceFailures += 1
        priceRetry = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            self.setup(with: pools)
        }
    }
}

extension PoolsItemService: PoolsServiceOutput {
    func loaded(pools: [PoolInfo]) {
        setup(with: pools)
    }
}
