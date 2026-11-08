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
    
    /// From the start, one row for each visible asset of the local asset
    /// list: its name and icon need no read. Balances fill in as they
    /// arrive (the saved ones first), never placeholder rows.
    @Published var assetViewModels: [AssetViewModel] = []

    /// Empty while loading, the total once prices are known, or the "price
    /// unavailable" notice. Never "$0" for want of prices or of balances.
    @Published var moneyText: String = ""
    /// Set before `moneyText`, so the cell styles unavailable-price or
    /// unavailable-balance notices quietly instead of as numeric totals.
    private(set) var priceIsUnavailable = false
    /// "Prices as of 09:02" while the total is valued with the last prices
    /// PI could give; empty when the prices are current or unknown.
    @Published var priceNoteText: String = ""

    private let priceRetryLock = NSLock()
    private var priceRetry: Task<Void, Never>?
    private var priceFailures = 0
    private var pricesObserver: NSObjectProtocol?
    private var valuationID = UUID()

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
        // No read and no price is waited for here.
        let assetIds = visibleAssetIds()
        assetViewModels = rows(for: assetIds, balances: assetProvider.getBalances(with: assetIds)) { item in
            row(for: item, priceInfo: nil)
        }
    }

    private func visibleAssetIds() -> [String] {
        (assetManager.getAssetList() ?? []).filter { $0.visible }.map { $0.assetId }
    }

    /// One balance's row, valued with `priceInfo` once a price read has
    /// finished: a row without a price then shows no value instead of a
    /// placeholder that never ends.
    private func row(for item: BalanceData, priceInfo: PriceInfo?) -> AssetViewModel? {
        let deltaPrice = priceInfo?.marketCapInfo.first(where: { $0.assetId == item.identifier })?.hourDelta
        var viewModel = assetViewModelsFactory.createAssetViewModel(with: item,
                                                                    fiatData: priceInfo?.fiatData ?? [],
                                                                    mode: .view,
                                                                    priceDelta: deltaPrice)
        viewModel?.priceLoadFinished = priceInfo != nil
        return viewModel
    }

    /// A visible asset still waits for its first balance: the total is not
    /// known yet, so it is neither shown without that asset nor as "$0".
    private func balancesStillLoading(among assetIds: [String], balances: [BalanceData]) -> Bool {
        guard assetProvider.isAwaitingFirstRead else { return false }
        let unavailable = assetProvider.unavailableBalanceAssetIds(among: assetIds)
        return assetIds.contains { assetId in
            !unavailable.contains(assetId) && !balances.contains { $0.identifier == assetId }
        }
    }

    func setup() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.setup() }
            return
        }
        let id = UUID()
        valuationID = id
        let assetIds = visibleAssetIds()
        // A balance refresh never waits for a price refresh. Value it with
        // the prices already held, then update those independently.
        publish(assetIds: assetIds, prices: priceInfo)
        guard valuationID == id else { return }
        let priceInfoService = self.priceInfoService
        Task { @MainActor [weak self] in
            let prices = await priceInfoService.getPriceInfo(for: assetIds)
            guard let self, self.valuationID == id else { return }
            self.priceInfo = prices
            self.publish(assetIds: self.visibleAssetIds(), prices: prices)
            guard self.valuationID == id else { return }
            self.schedulePriceRetry(needed: prices.fiatData.isEmpty || prices.pricesAsOf != nil)
        }
    }

    private func publish(assetIds: [String], prices: PriceInfo?) {
        let items = assetProvider.getBalances(with: assetIds)
        let loading = balancesStillLoading(among: assetIds, balances: items)
        let balancesMissing = !assetProvider.unavailableBalanceAssetIds(among: assetIds).isEmpty
        let allBalancesUnavailable = !loading && items.isEmpty && balancesMissing
        let pricesAvailable = prices.map { Self.pricesKnown(for: items, fiatData: $0.fiatData) } ?? false
        priceIsUnavailable = allBalancesUnavailable || (prices != nil && !pricesAvailable && !loading)
        let pricesAsOf = pricesAvailable ? prices?.pricesAsOf : nil
        priceNoteText = allBalancesUnavailable || loading || prices == nil ? "" : balancesMissing
            ? WalletUX.text("This total does not include balances that could not be read")
            : (pricesAsOf.map { WalletUX.pricesAsOfText($0) } ?? "")
        if allBalancesUnavailable {
            moneyText = WalletUX.balanceUnavailableText
        } else {
            moneyText = loading ? "" : prices.map { Self.fiatTotalText(balances: items, fiatData: $0.fiatData) } ?? ""
        }
        assetViewModels = rows(for: assetIds, balances: items) { item in
            self.row(for: item, priceInfo: prices)
        }
        updateHandler?()
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
    /// The rows in list order. An asset whose balance could not be read
    /// keeps its row, which says "Balance unavailable"; it is neither left
    /// out nor shown as zero. Until the first read has ended, an asset
    /// without a balance yet keeps its row too, without an amount.
    func rows(
        for assetIds: [String],
        balances: [BalanceData],
        build: (BalanceData) -> AssetViewModel?
    ) -> [AssetViewModel] {
        let unavailable = assetProvider.unavailableBalanceAssetIds(among: assetIds)
        let loading = assetProvider.isAwaitingFirstRead
        guard !unavailable.isEmpty || loading else {
            return balances.compactMap(build)
        }
        return assetIds.compactMap { assetId in
            if unavailable.contains(assetId) {
                return assetViewModelsFactory.createBalanceUnavailableViewModel(assetId: assetId, mode: .view)
            }
            if let balance = balances.first(where: { $0.identifier == assetId }) {
                return build(balance)
            }
            return loading ? assetViewModelsFactory.createBalanceLoadingViewModel(assetId: assetId, mode: .view) : nil
        }
    }

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
