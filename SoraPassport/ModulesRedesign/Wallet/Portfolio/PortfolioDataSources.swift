// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

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
    /// Set while these are not fresh prices: the time of the app's "Prices as of" note.
    var asOf: Date?
    /// When prices were last read.
    var readAt: Date?
}

enum PortfolioSnapshotBuilder {
    static let xorId = "0x0200000000000000000000000000000000000000000000000000000000000000"

    /// Prices are read about once a minute while the wallet is open. This long without an answer they
    /// are old, whatever the last answer said: the age the price catalog itself calls stale.
    static let pricesOldAfter: TimeInterval = 600

    /// The time of the "Prices as of" note, while the prices are old.
    static func pricesAsOf(_ prices: PortfolioPriceSource, now: Date) -> Date? {
        if let asOf = prices.asOf { return asOf }
        guard let readAt = prices.readAt, now.timeIntervalSince(readAt) > pricesOldAfter else { return nil }
        return readAt
    }

    /// Everything a wallet holds is listed. Only a token the app shows by default can be hidden, when
    /// the user turned it off in the asset list: `AssetManager` saves every other token as not visible
    /// until it is turned on, so for those "not visible" says nothing about the user's choice.
    static func isVisible(assetId: String, wallet: PortfolioWalletSource) -> Bool {
        guard assetId != xorId, WalletAssetId(rawValue: assetId) != nil else { return true }
        if let ordered = wallet.orderedAssetIds, !ordered.isEmpty, let visible = wallet.visibleAssetIds {
            return visible.contains(assetId)
        }
        return true
    }

    static func build(wallets: [PortfolioWalletSource], assets: [PortfolioAssetSource],
                      reads: [String: PortfolioWalletReadState], prices: PortfolioPriceSource,
                      networks: [PortfolioNetwork], liveNetworks: Set<PortfolioNetwork>,
                      swapsAvailable: Bool, disclaimerAccepted: Bool, now: Date) -> PortfolioSnapshot {
        let byId = Dictionary(assets.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let oldPricesDate = pricesAsOf(prices, now: now)
        func token(_ asset: PortfolioAssetSource) -> PortfolioToken {
            // An old price says nothing about the last 24 hours.
            PortfolioToken(id: asset.id, symbol: asset.symbol, name: asset.name, icon: asset.icon,
                           priceUSD: prices.usd[asset.id],
                           change24h: oldPricesDate == nil ? prices.change[asset.id] : nil, isSwappable: true)
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
                                 liveNetworks: liveNetworks, pricesAsOf: oldPricesDate)
    }
}

// MARK: - Live wallets

/// The last reads on this device, so a launch shows every wallet's balances at once and refreshes
/// them after. Public chain data only (addresses, balances, prices), never anything from the keys.
final class PortfolioReadStore {
    static let key = "portfolio.reads.v1"

    private struct Saved: Codable, Equatable {
        struct Wallet: Codable, Equatable {
            /// Non-zero balances by asset id: free, reserved, frozen.
            var sora2: [String: [String]]?
            var nexus: [String: String]
            var lastRead: Date?
        }

        var wallets: [String: Wallet]
        var usd: [String: String]
        var change: [String: String]
        var asOf: Date?
        var readAt: Date?
    }

    private let defaults: UserDefaults
    private var lastSaved: Saved?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> (reads: [String: PortfolioWalletReadState], prices: PortfolioPriceSource)? {
        guard let data = defaults.data(forKey: Self.key),
              let saved = try? JSONDecoder().decode(Saved.self, from: data) else { return nil }
        lastSaved = saved
        var reads: [String: PortfolioWalletReadState] = [:]
        for (id, wallet) in saved.wallets {
            var state = PortfolioWalletReadState()
            state.sora2 = wallet.sora2?.compactMapValues { values in
                let parts = values.compactMap { Decimal(string: $0) }
                guard parts.count == 3 else { return nil }
                return PortfolioRawBalance(free: parts[0], reserved: parts[1], frozen: parts[2])
            }
            for (network, amount) in wallet.nexus {
                guard let network = PortfolioNetwork(rawValue: network),
                      let value = Decimal(string: amount) else { continue }
                state.nexus[network] = value
            }
            state.lastRead = wallet.lastRead
            reads[id] = state
        }
        var prices = PortfolioPriceSource()
        prices.usd = saved.usd.compactMapValues { Decimal(string: $0) }
        prices.change = saved.change.compactMapValues { Decimal(string: $0) }
        prices.asOf = saved.asOf
        prices.readAt = saved.readAt
        return (reads, prices)
    }

    func save(reads: [String: PortfolioWalletReadState], prices: PortfolioPriceSource) {
        let wallets = reads.mapValues { state in
            Saved.Wallet(
                sora2: state.sora2?.filter { $0.value.total > 0 }.mapValues { balance in
                    ["\(balance.free)", "\(balance.reserved)", "\(balance.frozen)"]
                },
                nexus: Dictionary(uniqueKeysWithValues: state.nexus.map { ($0.key.rawValue, "\($0.value)") }),
                lastRead: state.lastRead
            )
        }
        let saved = Saved(wallets: wallets, usd: prices.usd.mapValues { "\($0)" },
                          change: prices.change.mapValues { "\($0)" }, asOf: prices.asOf, readAt: prices.readAt)
        guard saved != lastSaved, let data = try? JSONEncoder().encode(saved) else { return }
        defaults.set(data, forKey: Self.key)
        lastSaved = saved
    }
}

/// Reads that outlive one Wallet tab: an account switch rebuilds the tab, and the other wallets'
/// numbers should not blink back to OFFLINE. The shared cache also keeps them across launches.
final class PortfolioReadCache {
    static let shared = PortfolioReadCache(store: PortfolioReadStore())
    var wallets: [PortfolioWalletSource] = []
    var reads: [String: PortfolioWalletReadState] = [:]
    var prices = PortfolioPriceSource()
    private let store: PortfolioReadStore?

    init(store: PortfolioReadStore? = nil) {
        self.store = store
        if let saved = store?.load() {
            reads = saved.reads
            prices = saved.prices
        }
    }

    func save() {
        store?.save(reads: reads, prices: prices)
    }
}

/// Every wallet the user has, read by address and read-only. Saved balances show at once. Wallets
/// are read side by side, each under a deadline, so a slow one never holds back the others.
/// Non-selected wallets refresh at most once a minute while the dashboard is visible; the selected
/// one also on the app's balance events.
@MainActor
final class LivePortfolioDataSource: PortfolioDataSource {
    /// Wallets read at the same time.
    private static let parallelReads = 4

    var onChange: ((PortfolioSnapshot) -> Void)?
    private(set) var snapshot: PortfolioSnapshot = .empty
    let isSample = false

    private let assetManager: AssetManagerProtocol
    private let sora2Reader: PortfolioSora2BalanceReading
    private let nexusReader: PortfolioNexusBalanceReading
    private let accountRepository: AnyDataProviderRepository<AccountItem>
    private let cache: PortfolioReadCache
    private let priceService: PriceInfoServiceProtocol
    private let readDeadline: TimeInterval
    private var wallets: [PortfolioWalletSource] = []
    /// Each wallet's accounts on networks other than SORA2 (public addresses only), for the reads.
    private var networkAccounts: [String: [PortfolioNetwork: NetworkAccount]] = [:]
    private var refreshTask: Task<Void, Never>?
    private var pendingForce = false
    private var pendingRefresh = false
    private var selectedBalanceRevision: UInt64 = 0
    private var timer: Timer?
    private var started = false
    private var selectedDirty = false
    /// Until every wallet has been tried once, the snapshot says it is loading, so the hero shows
    /// neither the empty state nor OFFLINE for a wallet not read yet. Saved balances show meanwhile.
    private var firstPassDone: Bool

    init(assetManager: AssetManagerProtocol,
         sora2Reader: PortfolioSora2BalanceReading = PortfolioSora2BalanceReader(),
         nexusReader: PortfolioNexusBalanceReading = PortfolioNexusBalanceReader(),
         accountRepository: AnyDataProviderRepository<AccountItem> = AnyDataProviderRepository(
             UserDataStorageFacade.shared.createRepository(filter: nil, sortDescriptors: [],
                                                           mapper: AnyCoreDataMapper(AccountItemMapper()))),
         cache: PortfolioReadCache = .shared,
         priceService: PriceInfoServiceProtocol = PriceInfoService.shared,
         readDeadline: TimeInterval = 15) {
        self.assetManager = assetManager
        self.sora2Reader = sora2Reader
        self.nexusReader = nexusReader
        self.accountRepository = accountRepository
        self.cache = cache
        self.priceService = priceService
        self.readDeadline = readDeadline
        wallets = cache.wallets
        firstPassDone = !cache.wallets.isEmpty && !cache.reads.isEmpty
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
            pendingRefresh = true
            return
        }
        refreshTask = Task { [weak self] in
            await self?.performRefresh(force: force)
            guard let self else { return }
            self.refreshTask = nil
            if self.pendingRefresh {
                let force = self.pendingForce
                self.pendingForce = false
                self.pendingRefresh = false
                self.refresh(force: force)
            }
        }
    }

    private func performRefresh(force: Bool) async {
        do {
            try await loadWallets()
        } catch {
            // A failed repository read says nothing about whether stored wallets were deleted.
            // Keep the last snapshot until an authoritative account list is available.
            firstPassDone = true
            publish()
            return
        }
        // Every wallet's saved balances, before anything is read.
        publish()
        let assets = self.assets
        guard !assets.isEmpty else {
            cache.save()
            publish()
            return
        }
        let readable = assets.map { (id: $0.id, precision: $0.precision) }
        let now = Date()
        let due = wallets.filter { wallet in
            force || (wallet.isSelected && selectedDirty) ||
                PortfolioFreshnessPolicy.isDue(lastAttempt: cache.reads[wallet.id]?.lastAttempt, now: now)
        }
        // The selected wallet first, then the others, a few at a time.
        var waiting = (due.filter(\.isSelected) + due.filter { !$0.isSelected }).makeIterator()
        await withTaskGroup(of: Void.self) { group in
            func addNext() {
                guard !Task.isCancelled, let wallet = waiting.next() else { return }
                group.addTask { @MainActor [weak self] in
                    await self?.read(wallet, assets: readable)
                }
            }
            (0..<Self.parallelReads).forEach { _ in addNext() }
            while await group.next() != nil { addNext() }
        }
        await loadPrices(assets: assets)
        firstPassDone = true
        cache.save()
        publish()
    }

    private func read(_ wallet: PortfolioWalletSource, assets: [(id: String, precision: Int16)]) async {
        var state = cache.reads[wallet.id] ?? PortfolioWalletReadState()
        state.lastAttempt = Date()
        let readRevision = selectedBalanceRevision
        var failed: [PortfolioNetwork] = []
        let sora2Reader = self.sora2Reader, nexusReader = self.nexusReader
        do {
            state.sora2 = try await PortfolioReadDeadline.run(seconds: readDeadline) {
                try await sora2Reader.balances(address: wallet.id, assets: assets)
            }
        } catch {
            failed.append(.sora2)
        }
        for network in liveNetworks.subtracting([.sora2]).sorted(by: { $0.rank() < $1.rank() }) {
            guard let account = networkAccounts[wallet.id]?[network], !Task.isCancelled else { continue }
            do {
                state.nexus[network] = try await PortfolioReadDeadline.run(seconds: readDeadline) {
                    try await nexusReader.xorBalance(account: account)
                }
            } catch {
                failed.append(network)
            }
        }
        if !failed.contains(.sora2) { state.lastRead = Date() }
        state.failed = failed
        cache.reads[wallet.id] = state
        if wallet.isSelected { selectedDirty = selectedBalanceRevision != readRevision }
        publish()
    }

    private func loadWallets() async throws {
        let accounts: [AccountItem] = try await withCheckedThrowingContinuation { continuation in
            let operation = accountRepository.fetchAllOperation(with: RepositoryFetchOptions())
            operation.completionBlock = {
                do {
                    continuation.resume(returning: try operation.extractNoCancellableResultData())
                } catch {
                    continuation.resume(throwing: error)
                }
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
        // A removed wallet's saved balances leave with it.
        let ids = Set(wallets.map(\.id))
        cache.reads = cache.reads.filter { ids.contains($0.key) }
    }

    private func loadPrices(assets: [PortfolioAssetSource]) async {
        let held = Set(cache.reads.values.flatMap { read in
            (read.sora2 ?? [:]).filter { $0.value.total > 0 }.map(\.key)
        } + [PortfolioSnapshotBuilder.xorId])
        let ids = assets.map(\.id).filter { held.contains($0) }
        guard !ids.isEmpty else { return }
        let priceService = self.priceService
        let info = try? await PortfolioReadDeadline.run(seconds: readDeadline) {
            await priceService.getPriceInfo(for: ids)
        }
        var prices = cache.prices
        if let info, !info.fiatData.isEmpty {
            // FiatService returns the complete catalog snapshot. A missing or unpriced asset
            // no longer has a quote: merging would keep its old value and call it current.
            prices.usd = Dictionary(info.fiatData.compactMap { fiat in
                fiat.priceUsd?.decimalValue.map { (fiat.id, $0) }
            }, uniquingKeysWith: { _, latest in latest })
            prices.change = Dictionary(info.marketCapInfo.map { ($0.assetId, $0.hourDelta) },
                                       uniquingKeysWith: { _, latest in latest })
            prices.asOf = info.pricesAsOf
            prices.readAt = info.pricesAsOf ?? Date()
        } else {
            // No answer: the saved prices stand, and the hero says how old they are.
            prices.asOf = prices.asOf ?? prices.readAt
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
        selectedBalanceRevision &+= 1
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
