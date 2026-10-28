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
import RobinHood

protocol AssetProviderObserverProtocol: AnyObject {
    func processBalance(data: [BalanceData])
}


protocol AssetProviderProtocol: AnyObject {
    /// Balances that were read. An asset whose balance could not be read
    /// has no entry here (it is never reported as zero); see
    /// `unavailableBalanceAssetIds(among:)`.
    func getBalances(with assetIds: [String]) -> [BalanceData]
    /// The assets among `assetIds` whose balance the last read could not
    /// give. They are shown as "Balance unavailable".
    func unavailableBalanceAssetIds(among assetIds: [String]) -> Set<String>
    func add(observer: AssetProviderObserverProtocol)
    func remove(observer: AssetProviderObserverProtocol)
}

extension AssetProviderProtocol {
    func unavailableBalanceAssetIds(among _: [String]) -> Set<String> { [] }
}

struct AssetProviderObserver {
    weak var observer: AssetProviderObserverProtocol?
}

final class AssetProvider {
    /// How long after a read that left a balance out the next read is
    /// asked for, and how many times. Then the next balance event, start
    /// or screen asks again.
    static let retryDelays: [TimeInterval] = [5, 15, 45, 120, 300]

    private var balanceData: [BalanceData] = []
    private var unavailableAssetIds: Set<String> = []
    private let balanceProvider: SingleValueProvider<[BalanceData]>?
    private var observers: [AssetProviderObserver] = []
    private let syncQueue = DispatchQueue(label: "co.jp.soramitsu.sora.balance.provider")
    /// `balanceData` and `unavailableAssetIds` are written on the main
    /// queue (where the provider delivers) and read from any.
    private let stateLock = NSLock()
    private let refresh: () -> Void
    private let retryDelays: [TimeInterval]
    private let schedule: (TimeInterval, @escaping () -> Void) -> Void
    /// The last read left a balance out, or failed as a whole.
    private var readIsIncomplete = false
    private var retryStep = 0
    /// Each chain of retries has a number; a timer of an earlier chain
    /// does nothing.
    private var retryChain = 0
    private var retryScheduled = false
    
    convenience init(assetInfos: [AssetInfo], providerFactory: BalanceProviderFactory) {
        self.init(assetInfos: assetInfos) { assets in
            try? providerFactory.createBalanceDataProvider(for: assets, onlyVisible: false)
        }
    }

    /// - Parameter makeBalanceProvider: creates the provider that loads and
    ///   caches the balances of `assetInfos`. It is not called for an empty
    ///   list.
    ///
    /// Startup does not wait for the on-chain asset list, so a wallet can be
    /// built before any list exists. Such a wallet has no balance to load. It
    /// used to load "no balances" all the same and save that over the
    /// account's cached balances: every provider of an account shares one
    /// cache entry. The tabs that were built again when the list arrived then
    /// read that empty answer, and the wallet showed no asset until the next
    /// launch. Without a list nothing is loaded and nothing is saved; the
    /// asset rows keep their loading state.
    init(assetInfos: [AssetInfo], makeBalanceProvider: ([AssetInfo]) -> SingleValueProvider<[BalanceData]>?) {
        balanceProvider = assetInfos.isEmpty ? nil : makeBalanceProvider(assetInfos)
        let provider = balanceProvider
        refresh = { provider?.refresh() }
        retryDelays = Self.retryDelays
        schedule = { delay, work in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
        setupBalanceDataProvider()
        EventCenter.shared.add(observer: self)
    }

    /// For tests: what the balance provider delivers is passed to
    /// `receive(_:)` and `receiveReadFailure()` directly.
    init(
        refresh: @escaping () -> Void,
        retryDelays: [TimeInterval] = AssetProvider.retryDelays,
        schedule: @escaping (TimeInterval, @escaping () -> Void) -> Void
    ) {
        balanceProvider = nil
        self.refresh = refresh
        self.retryDelays = retryDelays
        self.schedule = schedule
    }
    
    func setupBalanceDataProvider() {
        let changesBlock = { [weak self] (changes: [DataProviderChange<[BalanceData]>]) -> Void in
            guard let change = changes.first else { return }
            switch change {
            case .insert(let items), .update(let items):
                self?.receive(items)
            default:
                break
            }
        }

        let options = DataProviderObserverOptions()
        balanceProvider?.addObserver(self,
                                    deliverOn: .main,
                                    executing: changesBlock,
                                    failing: { [weak self] (_: Error) in
                                        self?.receiveReadFailure()
                                    },
                                    options: options)
    }

    /// One read of the balances arrived (main queue).
    func receive(_ items: [BalanceData]) {
        stateLock.lock()
        let merged = AssetProvider.merge(previous: balanceData, items: items)
        balanceData = merged.balances
        unavailableAssetIds = merged.unavailable
        stateLock.unlock()
        notify()
        readEnded(incomplete: merged.incomplete)
    }

    /// A read failed as a whole (main queue). The balances shown stay.
    func receiveReadFailure() {
        readEnded(incomplete: true)
    }
}

extension AssetProvider {
    /// Separates the balances that were read from the assets whose balance
    /// could not be read, so no consumer can take the latter for a number.
    static func split(_ items: [BalanceData]) -> (balances: [BalanceData], unavailable: Set<String>) {
        let merged = merge(previous: [], items: items)
        return (merged.balances, merged.unavailable)
    }

    /// What the provider holds after one read.
    ///
    /// - An asset that was read has its balance.
    /// - An asset whose request got no answer this time (a timeout, a
    ///   dropped connection) keeps the balance of the read before, if there
    ///   was one: a missing answer says nothing new about it. Without an
    ///   earlier value it is unavailable.
    /// - An asset whose answer arrived and was not understood is
    ///   unavailable: the value held before is no longer known to be
    ///   right.
    ///
    /// `incomplete` is true when either happened, so the read is asked for
    /// again.
    static func merge(
        previous: [BalanceData],
        items: [BalanceData]
    ) -> (balances: [BalanceData], unavailable: Set<String>, incomplete: Bool) {
        var balances: [BalanceData] = []
        var unavailable = Set<String>()
        var incomplete = false
        for item in items {
            guard item.isUnavailable else {
                balances.append(item)
                continue
            }
            incomplete = true
            if item.balanceWasNotRead,
               let kept = previous.first(where: { $0.identifier == item.identifier }) {
                balances.append(kept)
            } else {
                unavailable.insert(item.identifier)
            }
        }
        return (balances, unavailable, incomplete)
    }

    /// Follows a read that left something out with further reads, a
    /// bounded number of times, so a row does not stay at "Balance
    /// unavailable" (or at an earlier value) until the account's XOR next
    /// changes. A complete read ends the asking.
    private func readEnded(incomplete: Bool) {
        readIsIncomplete = incomplete
        guard incomplete else {
            retryChain += 1
            retryStep = 0
            retryScheduled = false
            return
        }
        scheduleRetryIfNeeded()
    }

    private func scheduleRetryIfNeeded() {
        guard readIsIncomplete, !retryScheduled, retryDelays.indices.contains(retryStep) else {
            return
        }
        let delay = retryDelays[retryStep]
        retryStep += 1
        retryScheduled = true
        let chain = retryChain
        schedule(delay) { [weak self] in
            guard let self, self.retryChain == chain else { return }
            self.retryScheduled = false
            guard self.readIsIncomplete else { return }
            self.refresh()
            // A read that brings the same values again is not delivered,
            // so the next try does not wait for an answer to this one.
            self.scheduleRetryIfNeeded()
        }
    }
}

extension AssetProvider: AssetProviderProtocol {
    func unavailableBalanceAssetIds(among assetIds: [String]) -> Set<String> {
        stateLock.lock()
        defer { stateLock.unlock() }
        return unavailableAssetIds.intersection(assetIds)
    }

    func getBalances(with assetIds: [String]) -> [BalanceData] {
        stateLock.lock()
        let balanceData = self.balanceData
        stateLock.unlock()
        var balances: [BalanceData] = []
        
        for id in assetIds {
            guard let assetBalance = balanceData.first(where: { $0.identifier == id }) else { continue }
            balances.append(assetBalance)
        }

        return balances
    }
    
    func add(observer: AssetProviderObserverProtocol) {
        syncQueue.async {
            self.observers = self.observers.filter { $0.observer != nil }

            if !self.observers.contains(where: { $0.observer === observer }) {
                self.observers.append(AssetProviderObserver(observer: observer))
            }
        }
    }

    func remove(observer: AssetProviderObserverProtocol) {
        let identity = ObjectIdentifier(observer)
        syncQueue.async {
            self.observers.removeAll {
                guard let current = $0.observer else { return true }
                return ObjectIdentifier(current) == identity
            }
        }
    }
    
    func notify() {
        syncQueue.async {
            self.observers = self.observers.filter { $0.observer != nil }

            for wrapper in self.observers {
                guard let observer = wrapper.observer else {
                    continue
                }

                self.stateLock.lock()
                let balanceData = self.balanceData
                self.stateLock.unlock()
                observer.processBalance(data: balanceData)
            }
        }
    }
}

extension AssetProvider: EventVisitorProtocol {
    func processBalanceChanged(event: WalletBalanceChanged) {
        refresh()
        // If the read before left a balance out, this event starts the
        // asking again from its first delay.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.readIsIncomplete else { return }
            self.retryChain += 1
            self.retryStep = 0
            self.retryScheduled = false
            self.scheduleRetryIfNeeded()
        }
    }
}
