// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import Foundation
import RobinHood
import SoraKeystore

enum PortfolioFeature {
    /// Debug inputs (the sample portfolio, an injected tilt) exist only outside Release builds.
    static var allowsDebugInjection: Bool {
        #if F_RELEASE
        return false
        #else
        return true
        #endif
    }
}

// MARK: - Snapshot builder

/// What the portfolio knows about a wallet from account storage (read-only).
struct PortfolioWalletSource: Equatable {
    let id: String
    let name: String
    let order: Int
    let isSelected: Bool
    let visibleAssetIds: [String]?
    let orderedAssetIds: [String]?
    /// Network accounts the build shows, by network (SORA2 is `id`).
    let addresses: [PortfolioNetwork: String]
}

struct PortfolioAssetSource: Equatable {
    let id: String
    let symbol: String
    let name: String
    let icon: String?
    let precision: Int16
}

/// The latest reads of one wallet.
struct PortfolioWalletReadState: Equatable {
    var sora2: [String: PortfolioRawBalance]?
    var nexus: [PortfolioNetwork: Decimal] = [:]
    var lastRead: Date?
    var lastAttempt: Date?
    var failed: [PortfolioNetwork] = []
}

struct PortfolioPriceSource: Equatable {
    var usd: [String: Decimal] = [:]
    var change: [String: Decimal] = [:]
}

enum PortfolioSnapshotBuilder {
    static let xorId = "0x0200000000000000000000000000000000000000000000000000000000000000"

    /// Mirrors the asset list's visibility (`AssetManager`): XOR always shows; with a saved order the
    /// wallet's visible list decides; otherwise the app's default assets show.
    static func isVisible(assetId: String, wallet: PortfolioWalletSource) -> Bool {
        if assetId == xorId { return true }
        if let ordered = wallet.orderedAssetIds, !ordered.isEmpty, let visible = wallet.visibleAssetIds {
            return visible.contains(assetId)
        }
        return WalletAssetId(rawValue: assetId) != nil
    }

    static func build(wallets: [PortfolioWalletSource], assets: [PortfolioAssetSource],
                      reads: [String: PortfolioWalletReadState], prices: PortfolioPriceSource,
                      networks: [PortfolioNetwork], liveNetworks: Set<PortfolioNetwork>,
                      swapsAvailable: Bool, disclaimerAccepted: Bool, now: Date) -> PortfolioSnapshot {
        let byId = Dictionary(assets.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        func token(_ asset: PortfolioAssetSource) -> PortfolioToken {
            PortfolioToken(id: asset.id, symbol: asset.symbol, name: asset.name, icon: asset.icon,
                           priceUSD: prices.usd[asset.id], change24h: prices.change[asset.id], isSwappable: true)
        }
        var holdings: [PortfolioHolding] = []
        var portfolioWallets: [PortfolioWallet] = []
        for wallet in wallets.sorted(by: { $0.order < $1.order }) {
            let read = reads[wallet.id] ?? PortfolioWalletReadState()
            for (assetId, balance) in (read.sora2 ?? [:]).sorted(by: { $0.key < $1.key }) where balance.total > 0 {
                guard let asset = byId[assetId] else { continue }
                holdings.append(PortfolioHolding(walletId: wallet.id, network: .sora2, token: token(asset),
                                                 amount: balance.total, transferable: balance.transferable,
                                                 isHidden: !isVisible(assetId: assetId, wallet: wallet)))
            }
            if let xor = byId[xorId] {
                for network in networks where network != .sora2 {
                    guard wallet.addresses[network] != nil, let amount = read.nexus[network], amount > 0 else { continue }
                    holdings.append(PortfolioHolding(walletId: wallet.id, network: network, token: token(xor),
                                                     amount: amount, transferable: amount, isHidden: false))
                }
            }
            let walletNetworks = networks.filter { $0 == .sora2 || wallet.addresses[$0] != nil }
            var addresses = wallet.addresses.filter { walletNetworks.contains($0.key) }
            addresses[.sora2] = wallet.id
            portfolioWallets.append(PortfolioWallet(
                id: wallet.id, name: wallet.name.isEmpty ? PortfolioFormat.shortAddress(wallet.id) : wallet.name,
                isSelected: wallet.isSelected, order: wallet.order, networks: walletNetworks, addresses: addresses,
                freshness: PortfolioFreshnessPolicy.freshness(lastRead: read.lastRead, failedNetworks: read.failed, now: now)
            ))
        }
        return PortfolioSnapshot(wallets: portfolioWallets, holdings: holdings, networks: networks,
                                 swapsAvailable: swapsAvailable, swapDisclaimerAccepted: disclaimerAccepted,
                                 liveNetworks: liveNetworks)
    }
}

// MARK: - Live wallets

/// Reads that outlive one Wallet tab: an account switch rebuilds the tab, and the other wallets'
/// numbers should not blink back to OFFLINE. Process memory only; nothing is written to disk.
final class PortfolioReadCache {
    static let shared = PortfolioReadCache()
    var wallets: [PortfolioWalletSource] = []
    var reads: [String: PortfolioWalletReadState] = [:]
    var prices = PortfolioPriceSource()
}

/// Every wallet the user has, read by address and read-only. Non-selected wallets refresh at most
/// once a minute while the dashboard is visible; the selected one also on the app's balance events.
@MainActor
final class LivePortfolioDataSource: PortfolioDataSource {
    var onChange: ((PortfolioSnapshot) -> Void)?
    private(set) var snapshot: PortfolioSnapshot = .empty
    let isSample = false

    private let assetManager: AssetManagerProtocol
    private let sora2Reader: PortfolioSora2BalanceReading
    private let nexusReader: PortfolioNexusBalanceReading
    private let accountRepository: AnyDataProviderRepository<AccountItem>
    private let cache: PortfolioReadCache
    private var wallets: [PortfolioWalletSource] = []
    /// Each wallet's accounts on networks other than SORA2 (public addresses only), for the reads.
    private var networkAccounts: [String: [PortfolioNetwork: NetworkAccount]] = [:]
    private var refreshTask: Task<Void, Never>?
    private var pendingForce = false
    private var timer: Timer?
    private var started = false
    private var selectedDirty = false
    /// Until every wallet has been tried once (or earlier reads are cached), the snapshot says it is
    /// loading, so the hero shows neither the empty state nor OFFLINE for a wallet not read yet.
    private var firstPassDone: Bool

    init(assetManager: AssetManagerProtocol,
         sora2Reader: PortfolioSora2BalanceReading = PortfolioSora2BalanceReader(),
         nexusReader: PortfolioNexusBalanceReading = PortfolioNexusBalanceReader(),
         accountRepository: AnyDataProviderRepository<AccountItem> = AnyDataProviderRepository(
             UserDataStorageFacade.shared.createRepository(filter: nil, sortDescriptors: [],
                                                           mapper: AnyCoreDataMapper(AccountItemMapper()))),
         cache: PortfolioReadCache = .shared) {
        self.assetManager = assetManager
        self.sora2Reader = sora2Reader
        self.nexusReader = nexusReader
        self.accountRepository = accountRepository
        self.cache = cache
        wallets = cache.wallets
        firstPassDone = !cache.reads.isEmpty
        EventCenter.shared.add(observer: self, dispatchIn: .main)
        publish()
    }

    deinit {
        timer?.invalidate()
        refreshTask?.cancel()
    }

    func start() {
        guard !started else { return }
        started = true
        refresh(force: false)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh(force: false) }
        }
    }

    func stop() {
        started = false
        timer?.invalidate()
        timer = nil
    }

    func refreshAll() {
        refresh(force: true)
    }

    // MARK: Reading

    /// The networks the Wallet tab shows (the gates of `WalletNetworkAccounts`), in the app's order.
    private var shownNetworks: [PortfolioNetwork] {
        let settings = SettingsManager.shared
        var networks: [PortfolioNetwork] = [.sora2]
        if settings.nexusEnabled { networks.append(.minamoto) }
        if settings.nexusEnabled && settings.isTairaEnabled && NexusNetworkAdmissionPolicy.current.isTairaAdmitted {
            networks.append(.taira)
        }
        return PortfolioNetwork.ordered(networks)
    }

    /// Networks with live balances in this build; the others only have an address to copy.
    private var liveNetworks: Set<PortfolioNetwork> {
        Set(shownNetworks.filter { WalletNetworkDirectory.current.info($0.networkId).isLive })
    }

    private var assets: [PortfolioAssetSource] {
        (assetManager.getAssetList() ?? []).map {
            PortfolioAssetSource(id: $0.assetId, symbol: $0.symbol, name: $0.name, icon: $0.icon,
                                 precision: Int16(clamping: $0.precision))
        }
    }

    private func refresh(force: Bool) {
        guard refreshTask == nil else {
            pendingForce = pendingForce || force
            return
        }
        refreshTask = Task { [weak self] in
            await self?.performRefresh(force: force)
            guard let self else { return }
            self.refreshTask = nil
            if self.pendingForce {
                self.pendingForce = false
                self.refresh(force: true)
            }
        }
    }

    private func performRefresh(force: Bool) async {
        await loadWallets()
        let assets = self.assets
        guard !assets.isEmpty else {
            publish()
            return
        }
        let readable = assets.map { (id: $0.id, precision: $0.precision) }
        for wallet in wallets {
            var state = cache.reads[wallet.id] ?? PortfolioWalletReadState()
            let due = force || (wallet.isSelected && selectedDirty) ||
                PortfolioFreshnessPolicy.isDue(lastAttempt: state.lastAttempt, now: Date())
            guard due, !Task.isCancelled else { continue }
            state.lastAttempt = Date()
            var failed: [PortfolioNetwork] = []
            do {
                state.sora2 = try await sora2Reader.balances(address: wallet.id, assets: readable)
            } catch {
                failed.append(.sora2)
            }
            for network in liveNetworks.subtracting([.sora2]).sorted(by: { $0.rank() < $1.rank() }) {
                guard let account = networkAccounts[wallet.id]?[network], !Task.isCancelled else { continue }
                do {
                    state.nexus[network] = try await nexusReader.xorBalance(account: account)
                } catch {
                    failed.append(network)
                }
            }
            if !failed.contains(.sora2) { state.lastRead = Date() }
            state.failed = failed
            cache.reads[wallet.id] = state
            if wallet.isSelected { selectedDirty = false }
            if firstPassDone { publish() }
        }
        await loadPrices(assets: assets)
        firstPassDone = true
        publish()
    }

    private func loadWallets() async {
        let accounts: [AccountItem] = await withCheckedContinuation { continuation in
            let operation = accountRepository.fetchAllOperation(with: RepositoryFetchOptions())
            operation.completionBlock = {
                continuation.resume(returning: (try? operation.extractNoCancellableResultData()) ?? [])
            }
            OperationManagerFacade.sharedDefaultQueue.addOperation(operation)
        }
        let selected = SelectedWalletSettings.shared.currentAccount?.address
        let stored = (try? WalletNetworkStore().load())?.accounts ?? []
        let shown = shownNetworks
        var byWallet: [String: [PortfolioNetwork: NetworkAccount]] = [:]
        wallets = accounts.sorted { $0.order < $1.order }.enumerated().map { index, account in
            var addresses: [PortfolioNetwork: String] = [:]
            for networkAccount in stored where networkAccount.walletId == account.address {
                let network = PortfolioNetwork(networkAccount.networkId)
                guard network != .sora2, shown.contains(network) else { continue }
                addresses[network] = networkAccount.address
                byWallet[account.address, default: [:]][network] = networkAccount
            }
            return PortfolioWalletSource(id: account.address, name: account.username, order: index,
                                         isSelected: account.address == selected,
                                         visibleAssetIds: account.settings.visibleAssetIds,
                                         orderedAssetIds: account.settings.orderedAssetIds,
                                         addresses: addresses)
        }
        networkAccounts = byWallet
        cache.wallets = wallets
    }

    private func loadPrices(assets: [PortfolioAssetSource]) async {
        let held = Set(cache.reads.values.flatMap { read in
            (read.sora2 ?? [:]).filter { $0.value.total > 0 }.map(\.key)
        } + [PortfolioSnapshotBuilder.xorId])
        let ids = assets.map(\.id).filter { held.contains($0) }
        guard !ids.isEmpty else { return }
        let info = await PriceInfoService.shared.getPriceInfo(for: ids)
        var prices = cache.prices
        for fiat in info.fiatData {
            if let price = fiat.priceUsd?.decimalValue { prices.usd[fiat.id] = price }
        }
        for market in info.marketCapInfo {
            prices.change[market.assetId] = market.hourDelta
        }
        cache.prices = prices
    }

    private func publish() {
        var next = PortfolioSnapshotBuilder.build(wallets: wallets, assets: assets, reads: cache.reads,
                                                  prices: cache.prices, networks: shownNetworks,
                                                  liveNetworks: liveNetworks, swapsAvailable: true,
                                                  disclaimerAccepted: ApplicationConfig.shared.isDisclamerShown,
                                                  now: Date())
        next.isLoading = !firstPassDone
        guard next != snapshot else { return }
        snapshot = next
        onChange?(next)
    }

    /// Symbol and icon of an asset in the app's asset list.
    func asset(_ id: String) -> (symbol: String, icon: String?)? {
        assetManager.assetInfo(for: id).map { ($0.symbol, $0.icon) }
    }
}

extension LivePortfolioDataSource: EventVisitorProtocol {
    nonisolated func processBalanceChanged(event: WalletBalanceChanged) {
        Task { @MainActor in self.selectedBalanceChanged() }
    }

    nonisolated func processNewTransaction(event: WalletNewTransactionInserted) {
        Task { @MainActor in self.selectedBalanceChanged() }
    }

    private func selectedBalanceChanged() {
        selectedDirty = true
        if started { refresh(force: false) }
    }
}

// MARK: - Debug sample

#if !F_RELEASE
/// Debug-only inputs: `-PortfolioSample full|empty|partial|offline` and `-PortfolioTilt 0.8,-0.4`
/// as launch arguments (or `SORA_PORTFOLIO_SAMPLE` / `SORA_PORTFOLIO_TILT` in the environment).
enum PortfolioDebugOptions {
    static var sampleOverride: PortfolioSampleData.Variant?
    static var tiltOverride: (x: Double, y: Double)?

    static var sampleVariant: PortfolioSampleData.Variant? {
        if let sampleOverride { return sampleOverride }
        let value = UserDefaults.standard.string(forKey: "PortfolioSample") ??
            ProcessInfo.processInfo.environment["SORA_PORTFOLIO_SAMPLE"]
        return value.flatMap(PortfolioSampleData.Variant.init(rawValue:))
    }

    static var injectedTilt: (x: Double, y: Double)? {
        if let tiltOverride { return tiltOverride }
        guard let value = UserDefaults.standard.string(forKey: "PortfolioTilt") ??
            ProcessInfo.processInfo.environment["SORA_PORTFOLIO_TILT"] else { return nil }
        let parts = value.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 2 else { return nil }
        return (parts[0], parts[1])
    }
}

/// The debug sample as a data source. Not compiled into App Store builds.
@MainActor
final class PortfolioSampleDataSource: PortfolioDataSource {
    var onChange: ((PortfolioSnapshot) -> Void)?
    private(set) var snapshot: PortfolioSnapshot
    let isSample = true
    private let variant: PortfolioSampleData.Variant

    init(variant: PortfolioSampleData.Variant) {
        self.variant = variant
        snapshot = PortfolioSampleData.snapshot(variant, now: Date(), icon: Self.icon)
    }

    func start() {
        snapshot = PortfolioSampleData.snapshot(variant, now: Date(), icon: Self.icon)
        onChange?(snapshot)
    }

    func stop() {}

    func refreshAll() {
        start()
    }

    func asset(_ id: String) -> (symbol: String, icon: String?)? {
        snapshot.holdings.first { $0.token.id == id }.map { ($0.token.symbol, $0.token.icon) } ??
            Self.whitelist[id].map { ($0.symbol, $0.icon) }
    }

    /// Icons of the bundled asset whitelist (the same data URLs the asset list shows).
    nonisolated private static let whitelist: [String: (symbol: String, icon: String?)] = {
        guard let url = Bundle.main.url(forResource: "whitelist", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [:] }
        var result: [String: (symbol: String, icon: String?)] = [:]
        for entry in list {
            guard let id = entry["address"] as? String, let symbol = entry["symbol"] as? String else { continue }
            result[id] = (symbol, entry["icon"] as? String)
        }
        return result
    }()

    nonisolated static func icon(_ id: String) -> String? {
        whitelist[id]?.icon
    }
}
#endif
