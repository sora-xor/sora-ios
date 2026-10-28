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
    private var valuationID = UUID()
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
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.setup(with: pools) }
            return
        }
        let id = UUID()
        valuationID = id
        priceRetryLock.lock()
        priceRetry?.cancel()
        priceRetry = nil
        priceRetryLock.unlock()
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
            poolViewModels = pools.filter { $0.isFavorite }.compactMap {
                poolViewModelsFactory.createPoolViewModel(with: $0, fiatData: [], mode: .view)
            }
            updateHandler?()
        } else {
            publish(pools: pools, prices: fiatData)
        }

        guard valuationID == id else { return }
        let fiatService = self.fiatService
        Task { @MainActor [weak self] in
            let prices = await fiatService?.getFiat() ?? []
            guard let self, self.valuationID == id else { return }
            self.fiatData = prices
            self.publish(pools: pools, prices: prices)
            guard self.valuationID == id else { return }
            self.schedulePriceRetry(needed: prices.isEmpty, pools: pools)
        }
    }

    private func publish(pools: [PoolInfo], prices: [PIExactFiatData]) {
        let favorites = pools.filter { $0.isFavorite }
        let total = favorites.reduce(Decimal(0)) { result, pool in
            guard let basePrice = prices.first(where: { $0.id == pool.baseAssetId })?.priceUsd?.decimalValue,
                  let targetPrice = prices.first(where: { $0.id == pool.targetAssetId })?.priceUsd?.decimalValue,
                  let baseAmount = pool.baseAssetPooledByAccount,
                  let targetAmount = pool.targetAssetPooledByAccount else { return result }
            return result + baseAmount * basePrice + targetAmount * targetPrice
        }
        let pricesAvailable = Self.pricesKnown(for: favorites, fiatData: prices)
        priceIsUnavailable = !pricesAvailable
        moneyText = WalletUX.fiatTotalText(total, pricesAvailable: pricesAvailable)
        poolViewModels = favorites.compactMap {
            var model = poolViewModelsFactory.createPoolViewModel(with: $0, fiatData: prices, mode: .view)
            model?.priceLoadFinished = true
            return model
        }
        updateHandler?()
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
