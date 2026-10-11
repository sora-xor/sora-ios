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

final class AssetsItemService {
    let assetProvider: AssetProviderProtocol
    let marketCapService: MarketCapServiceProtocol
    var fiatService: FiatServiceProtocol?
    let assetViewModelsFactory: AssetViewModelFactory
    private let priceInfoService: PriceInfoServiceProtocol
    var priceInfo: PriceInfo?
    var assetManager: AssetManagerProtocol
    var updateHandler: (() -> Void)?
    
    @Published var assetViewModels: [AssetViewModel] = [ AssetViewModel(identifier: "1", title: "", subtitle: "", fiatText: ""),
                                                         AssetViewModel(identifier: "2", title: "", subtitle: "", fiatText: ""),
                                                         AssetViewModel(identifier: "3", title: "", subtitle: "", fiatText: ""),
                                                         AssetViewModel(identifier: "4", title: "", subtitle: "", fiatText: ""),
                                                         AssetViewModel(identifier: "5", title: "", subtitle: "", fiatText: "") ]
    
    /// Empty while loading, the total once prices are known, or the "price
    /// unavailable" notice. Never "$0" for want of prices.
    @Published var moneyText: String = ""
    /// Set before `moneyText`, so the cell can style the notice.
    private(set) var priceIsUnavailable = false
    /// "Prices as of 09:02" while the total is valued with the last prices
    /// PI could give; empty when the prices are current or unknown.
    @Published var priceNoteText: String = ""

    private let priceRetryLock = NSLock()
    private var priceRetry: Task<Void, Never>?
    private var priceFailures = 0
    private var pricesObserver: NSObjectProtocol?

    /// A retry is waiting to run. For tests.
    var hasScheduledPriceRetry: Bool {
        priceRetryLock.lock()
        defer { priceRetryLock.unlock() }
        return priceRetry != nil
    }

    deinit {
        priceRetry?.cancel()
        if let pricesObserver {
            NotificationCenter.default.removeObserver(pricesObserver)
        }
    }

    init(
        marketCapService: MarketCapServiceProtocol,
        fiatService: FiatServiceProtocol?,
        assetViewModelsFactory: AssetViewModelFactory,
        assetManager: AssetManagerProtocol,
        assetProvider: AssetProviderProtocol,
        priceInfoService: PriceInfoServiceProtocol = PriceInfoService.shared
    ) {
        self.assetProvider = assetProvider
        self.marketCapService = marketCapService
        self.fiatService = fiatService
        self.assetViewModelsFactory = assetViewModelsFactory
        self.assetManager = assetManager
        self.priceInfoService = priceInfoService
        // Prices were refreshed in the background, or the app came back to
        // the foreground: value the wallet again.
        pricesObserver = NotificationCenter.default.addObserver(
            forName: PICatalogs.pricesDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.setup()
        }
    }
    
    func setup() {
        let assetIds = (assetManager.getAssetList() ?? []).filter { $0.visible }.map { $0.assetId }
        if priceInfo == nil || assetIds.count != assetViewModels.count {
            let items = assetProvider.getBalances(with: assetIds)

            assetViewModels = items.compactMap { item in
                return self.assetViewModelsFactory.createAssetViewModel(with: item, fiatData: [], mode: .view)
            }
            updateHandler?()
        }

        Task {
            let poolItemInfo = await priceInfoService.getPriceInfo(for: assetIds)
            self.priceInfo = poolItemInfo
            
            let assetIds = (assetManager.getAssetList() ?? []).filter { $0.visible }.map { $0.assetId } 
            let items = assetProvider.getBalances(with: assetIds)
            
            let pricesAvailable = Self.pricesKnown(for: items, fiatData: poolItemInfo.fiatData)
            priceIsUnavailable = !pricesAvailable
            let pricesAsOf = pricesAvailable ? poolItemInfo.pricesAsOf : nil
            priceNoteText = pricesAsOf.map { WalletUX.pricesAsOfText($0) } ?? ""
            moneyText = Self.fiatTotalText(balances: items, fiatData: poolItemInfo.fiatData)
            // Keep asking while the prices could not be read, and while
            // the ones read are old. A wallet whose tokens PI has no price
            // for gains nothing from asking again.
            schedulePriceRetry(needed: poolItemInfo.fiatData.isEmpty || poolItemInfo.pricesAsOf != nil)
            
            assetViewModels = items.compactMap { item in
                let deltaPrice = poolItemInfo.marketCapInfo.first(where: { $0.assetId == item.identifier })?.hourDelta
                var viewModel = self.assetViewModelsFactory.createAssetViewModel(with: item,
                                                                                 fiatData: poolItemInfo.fiatData,
                                                                                 mode: .view,
                                                                                 priceDelta: deltaPrice)
                // The price read is over: a row without a price shows no
                // value instead of a placeholder that never ends.
                viewModel?.priceLoadFinished = true
                return viewModel
            }
            updateHandler?()
        }
    }
}

extension AssetsItemService {
    /// The wallet total for these balances at these prices. When no price
    /// is known for anything the wallet holds, the total is the "price
    /// unavailable" notice: a wallet that holds tokens must not read "$0".
    static func fiatTotalText(balances: [BalanceData], fiatData: [PIExactFiatData]) -> String {
        let total = balances.reduce(Decimal(0)) { partialResult, balanceData in
            if let priceUsd = fiatData.first(where: { $0.id == balanceData.identifier })?.priceUsd?.decimalValue {
                return partialResult + balanceData.balance.decimalValue * priceUsd
            }
            return partialResult
        }
        return WalletUX.fiatTotalText(total, pricesAvailable: pricesKnown(for: balances, fiatData: fiatData))
    }

    /// Whether a total can be given for these balances. Not when the prices
    /// could not be read at all, and not when the wallet holds tokens and
    /// none of them has a price (PI could not price them): its value is
    /// then unknown, not zero. A wallet that holds nothing is worth "$0",
    /// and a wallet with some priced tokens shows the sum of those.
    static func pricesKnown(for balances: [BalanceData], fiatData: [PIExactFiatData]) -> Bool {
        guard !fiatData.isEmpty else { return false }
        let held = balances.filter { $0.balance.decimalValue > 0 }
        guard !held.isEmpty else { return true }
        return held.contains { balanceData in
            fiatData.first(where: { $0.id == balanceData.identifier })?.priceUsd?.decimalValue != nil
        }
    }
}

private extension AssetsItemService {
    /// While prices are unavailable, asks again by itself so the notice is
    /// replaced as soon as PI answers; nothing is asked of the user.
    func schedulePriceRetry(needed: Bool) {
        priceRetryLock.lock()
        defer { priceRetryLock.unlock() }
        guard needed else {
            priceFailures = 0
            priceRetry?.cancel()
            priceRetry = nil
            return
        }
        guard priceRetry == nil else { return }
        let delay = WalletUX.priceRetryDelay(afterFailures: priceFailures)
        priceFailures += 1
        priceRetry = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            self.priceRetryLock.lock()
            self.priceRetry = nil
            self.priceRetryLock.unlock()
            self.setup()
        }
    }
}

extension AssetsItemService: AssetProviderObserverProtocol {
    func processBalance(data: [BalanceData]) {
        setup()
    }
}
