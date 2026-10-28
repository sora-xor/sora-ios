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
    
    /// What the price notifications and the loading rounds tell each other.
    private final class Progress {
        private let lock = NSLock()
        private var changes = 0
        private var shown = false

        /// How many times prices have changed so far.
        var priceChanges: Int {
            lock.lock()
            defer { lock.unlock() }
            return changes
        }

        /// The list with its rates has been put on screen.
        var listIsShown: Bool {
            lock.lock()
            defer { lock.unlock() }
            return shown
        }

        func markShown() {
            lock.lock()
            shown = true
            lock.unlock()
        }

        /// Records a price change. `true` when the list is on screen and a
        /// new round has to value it; while the list is still loading, the
        /// round that is running notices the change itself.
        func priceChanged() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            changes += 1
            return shown
        }
    }

    private let fiatService: FiatServiceProtocol
    private let pause: (TimeInterval) async -> Void
    private let progress = Progress()
    private var loading: Task<Void, Never>?
    private var pricesObserver: NSObjectProtocol?

    deinit {
        loading?.cancel()
        if let pricesObserver {
            NotificationCenter.default.removeObserver(pricesObserver)
        }
    }

    init(
        itemFactory: ExploreItemFactory,
        poolsService: ExplorePoolsServiceInputProtocol,
        apyService: APYServiceProtocol,
        fiatService: FiatServiceProtocol = FiatService.shared,
        pause: @escaping (TimeInterval) async -> Void = { seconds in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }
    ) {
        self.poolsService = poolsService
        self.itemFactory = itemFactory
        self.apyService = apyService
        self.fiatService = fiatService
        self.pause = pause
    }

    /// How long to wait before asking for the pool list again after it
    /// came back empty: 2 s, 4 s, 8 s and so on, one minute at most.
    static func retryDelay(afterAttempts attempts: Int) -> TimeInterval {
        min(60, 2 * pow(2, Double(max(0, min(attempts, 8)))))
    }

    func setup() {
        if pricesObserver == nil {
            // Prices arrived or were refreshed: value the pools again. Only
            // the values are worked out again; the pool list itself is kept
            // by the pools service and is not read from the node again.
            pricesObserver = NotificationCenter.default.addObserver(
                forName: PICatalogs.pricesDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.pricesChanged()
            }
        }
        reload()
    }

    private func pricesChanged() {
        if progress.priceChanged() {
            reload()
        }
    }

    private func reload() {
        loading?.cancel()
        // The service is held only while one round is running, so the
        // retries end when the screen that owns it is released.
        loading = Task { [weak self, pause, progress] in
            var attempts = 0
            while !Task.isCancelled {
                let changesBefore = progress.priceChanges
                guard let loaded = await self?.loadOnce(), !Task.isCancelled else { return }
                if loaded {
                    progress.markShown()
                    // Prices changed while this round was on its way: value
                    // the list once more with the prices of now.
                    if progress.priceChanges == changesBefore { return }
                    continue
                }
                // The node or the pool list was not ready. Ask again, each
                // time after a longer pause.
                await pause(Self.retryDelay(afterAttempts: attempts))
                attempts += 1
            }
        }
    }

    /// One round. `false` when there was nothing to show.
    private func loadOnce() async -> Bool {
        let fiatData = await fiatService.getFiat()
        let pools = (try? await poolsService.getPools(with: fiatData)) ?? []
        guard !Task.isCancelled else { return true }

        // The first time, the list appears with its values while the rates
        // are still loading. A list that is already on screen is replaced in
        // one step, so its rates do not go back to placeholders each time
        // prices change.
        if !progress.listIsShown {
            viewModels = pools.enumerated().compactMap { (index, pool) in
                return itemFactory.createPoolsItem(with: pool, serialNumber: String(index + 1))
            }
        }

        let result: [ExplorePoolViewModel] = (try? await pools.enumerated().concurrentMap { (index, pool) -> ExplorePoolViewModel in
            let apy = await self.apyService.getApy(for: pool.baseAssetId, targetAssetId: pool.targetAssetId)
            return self.itemFactory.createPoolsItem(with: pool, serialNumber: String(index + 1), apy: apy, apyLoaded: true)
        }) ?? []
        guard !Task.isCancelled else { return true }

        guard !result.isEmpty else { return false }
        viewModels = result
        return true
    }
}
