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
    
    private let fiatService: FiatServiceProtocol
    private let pause: (TimeInterval) async -> Void
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
            // Prices arrived or were refreshed: value the pools again.
            pricesObserver = NotificationCenter.default.addObserver(
                forName: PICatalogs.pricesDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.reload()
            }
        }
        reload()
    }

    private func reload() {
        loading?.cancel()
        // The service is held only while one round is running, so the
        // retries end when the screen that owns it is released.
        loading = Task { [weak self, pause] in
            var attempts = 0
            while !Task.isCancelled {
                guard let loaded = await self?.loadOnce() else { return }
                if loaded { return }
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

        viewModels = pools.enumerated().compactMap { (index, pool) in
            return itemFactory.createPoolsItem(with: pool, serialNumber: String(index + 1))
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
