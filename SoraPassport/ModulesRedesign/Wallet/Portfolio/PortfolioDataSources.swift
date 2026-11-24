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
    /// On the Polkaswap token blacklist: a holding of it is hidden (`AssetBlacklist`).
    var isBlacklisted = false
}

/// The latest reads of one wallet.
struct PortfolioWalletReadState: Equatable {
    var sora2: [String: PortfolioRawBalance]?
    var nexus: [PortfolioNetwork: Decimal] = [:]
    var lastRead: Date?
    var lastAttempt: Date?
    var failed: [PortfolioNetwork] = []
    /// SORA2 reads that failed in a row in this run (not saved): they bring the next attempt forward.
    var failedReads = 0
    /// When the last of them failed: the retry is counted from here, not from the attempt's start.
    var lastFailure: Date?
    /// The tokens (id and precision) the last SORA2 read recorded for this wallet asked about, in
    /// this process (not saved). A token listed since then has not been read for it.
    var sora2Coverage: Set<String>?
    /// The tokens the wallet's latest attempt asks about, from the moment it begins: a newly listed
    /// token does not make the wallet due again while that attempt already asks about it (the
    /// ordinary freshness rule applies then, as on master).
    var attemptCoverage: Set<String>?

    /// The time the next retry interval is counted from.
    var retryCountedFrom: Date? { failedReads > 0 ? (lastFailure ?? lastAttempt) : lastAttempt }
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

    /// What was read: the wallets, the app's assets, each wallet's last balances and the prices.
    struct Sources {
        let wallets: [PortfolioWalletSource]
        let assets: [PortfolioAssetSource]
        let reads: [String: PortfolioWalletReadState]
        let prices: PortfolioPriceSource
    }

    /// What the snapshot offers: the networks shown and live, and whether swaps can be used.
    struct Settings {
        let networks: [PortfolioNetwork]
        let liveNetworks: Set<PortfolioNetwork>
        let swapsAvailable: Bool
        let disclaimerAccepted: Bool
    }

    static func build(_ sources: Sources, settings: Settings, now: Date) -> PortfolioSnapshot {
        let wallets = sources.wallets, assets = sources.assets, reads = sources.reads, prices = sources.prices
        let networks = settings.networks
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
                // A blacklisted token is hidden like one the user turned off: out of the lists and
                // the total, counted in the note under it. The wallet's full asset list still
                // shows it, marked hidden.
                holdings.append(PortfolioHolding(walletId: wallet.id, network: .sora2, token: token(asset),
                                                 amount: balance.total, transferable: balance.transferable,
                                                 isHidden: asset.isBlacklisted || !isVisible(assetId: assetId, wallet: wallet),
                                                 isBlacklisted: asset.isBlacklisted))
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
                                 swapsAvailable: settings.swapsAvailable,
                                 swapDisclaimerAccepted: settings.disclaimerAccepted,
                                 liveNetworks: settings.liveNetworks, pricesAsOf: oldPricesDate)
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
    /// The account list is read on a queue of its own. Until 2026-11-22 it took its turn on the
    /// app's shared operation queue, behind the selected wallet's balance requests: a 7 ms fetch
    /// that answered after 1 to 10 s on a busy phone, and nothing shows before it.
    private static let listQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "portfolio.accounts"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 2
        return queue
    }()

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
    /// Every wallet's accounts on the other networks, as stored.
    private let storedNetworkAccounts: () throws -> [NetworkAccount]
    private var wallets: [PortfolioWalletSource] = []
    /// Each wallet's accounts on networks other than SORA2 (public addresses only), for the reads.
    private var networkAccounts: [String: [PortfolioNetwork: NetworkAccount]] = [:]
    private var refreshTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    /// Prices are read on their own, so a slow price service never holds back the next balance read.
    private var priceTask: Task<Void, Never>?
    private var pendingPriceIds: [String]?
    private var pendingForce = false
    private var pendingRefresh = false
    private var selectedBalanceRevision: UInt64 = 0
    private var timer: Timer?
    private var started = false
    private var selectedDirty = false
    /// Until every wallet has been tried once, the snapshot says it is loading, so the hero shows
    /// neither the empty state nor OFFLINE for a wallet not read yet. Saved balances show meanwhile.
    private var firstPassDone: Bool
    /// Passes that have run to their end (tests wait for this instead of for time).
    private(set) var finishedPasses = 0
    /// The Polkaswap token blacklist: a blacklisted holding is hidden like one the user turned
    /// off. A new list is applied at once, without reading any balance.
    var assetBlacklist: AssetBlacklistStoring = AssetBlacklistStore.shared
    private var blacklistObserver: NSObjectProtocol?

    init(assetManager: AssetManagerProtocol,
         sora2Reader: PortfolioSora2BalanceReading = PortfolioSora2BalanceReader(),
         nexusReader: PortfolioNexusBalanceReading = PortfolioNexusBalanceReader(),
         accountRepository: AnyDataProviderRepository<AccountItem> = AnyDataProviderRepository(
             UserDataStorageFacade.shared.createRepository(filter: nil, sortDescriptors: [],
                                                           mapper: AnyCoreDataMapper(AccountItemMapper()))),
         cache: PortfolioReadCache = .shared,
         priceService: PriceInfoServiceProtocol = PriceInfoService.shared,
         readDeadline: TimeInterval = 15,
         networkAccounts: @escaping () throws -> [NetworkAccount] = { try WalletNetworkStore().load()?.accounts ?? [] }) {
        self.assetManager = assetManager
        self.storedNetworkAccounts = networkAccounts
        self.sora2Reader = sora2Reader
        self.nexusReader = nexusReader
        self.accountRepository = accountRepository
        self.cache = cache
        self.priceService = priceService
        self.readDeadline = readDeadline
        // A shared cache can outlive Forget all / import, or an account switch. Only reuse its
        // first frame when it belongs to the selected account, and update the selection immediately.
        let selected = SelectedWalletSettings.shared.currentAccount?.address
        if let selected, cache.wallets.contains(where: { $0.id == selected }) {
            wallets = cache.wallets.map { wallet in
                PortfolioWalletSource(id: wallet.id, name: wallet.name, order: wallet.order,
                                      isSelected: wallet.id == selected,
                                      visibleAssetIds: wallet.visibleAssetIds,
                                      orderedAssetIds: wallet.orderedAssetIds, addresses: wallet.addresses)
            }
        }
        firstPassDone = !wallets.isEmpty && !cache.reads.isEmpty
        EventCenter.shared.add(observer: self, dispatchIn: .main)
        blacklistObserver = NotificationCenter.default.addObserver(
            forName: AssetBlacklistStore.didChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.publish() }
        }
        publish()
    }

    deinit {
        timer?.invalidate()
        refreshTask?.cancel()
        retryTask?.cancel()
        priceTask?.cancel()
        if let blacklistObserver {
            NotificationCenter.default.removeObserver(blacklistObserver)
        }
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
        retryTask?.cancel()
        retryTask = nil
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
        let blacklist = assetBlacklist.current()
        return (assetManager.getAssetList() ?? []).map {
            PortfolioAssetSource(id: $0.assetId, symbol: $0.symbol, name: $0.name, icon: $0.icon,
                                 precision: Int16(clamping: $0.precision),
                                 isBlacklisted: blacklist.hides(assetId: $0.assetId))
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
                // A tab that was left reads again when it appears; only an explicit refresh
                // runs meanwhile.
                if force || self.started { self.refresh(force: force) }
            }
        }
    }

    /// A pass is under way (tests wait for this instead of for time).
    var isReading: Bool { refreshTask != nil }

    private func performRefresh(force: Bool) async {
        defer { finishedPasses += 1 }
        do {
            try await loadWallets()
        } catch {
            // A failed repository read says nothing about whether stored wallets were deleted.
            // Keep the last snapshot until an authoritative account list is available. A launch
            // that knows no wallet yet stays loading: it has not found the wallet empty.
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
        let asked = Self.coverage(assets)
        let now = Date()
        let due = wallets.filter { wallet in
            let state = cache.reads[wallet.id]
            // A token listed since this wallet's last read (or one whose precision changed) has not
            // been read for it: the wallet is due at once, without waiting out its minute, unless
            // its latest attempt already asks about every token. After a failed read its retry
            // intervals apply as to any other.
            let unreadTokens = (state?.failedReads ?? 0) == 0 &&
                (state?.sora2Coverage.map { !asked.isSubset(of: $0) } ?? false) &&
                !asked.isSubset(of: state?.attemptCoverage ?? [])
            return force || unreadTokens || (wallet.isSelected && selectedDirty) ||
                PortfolioFreshnessPolicy.isDue(lastAttempt: state?.retryCountedFrom,
                                               failedReads: state?.failedReads ?? 0, now: now)
        }
        // Prices are read beside the balances, for the tokens held when this pass began: a slow
        // price service never holds back a balance, nor the end of loading.
        let pricedIds = priceIds(assets: assets)
        readPrices(ids: pricedIds)
        // The selected wallet first, then the others, a few at a time.
        var waiting = (due.filter(\.isSelected) + due.filter { !$0.isSelected }).makeIterator()
        await withTaskGroup(of: Void.self) { group in
            func addNext() {
                guard !Task.isCancelled, let wallet = waiting.next() else { return }
                group.addTask { @MainActor [weak self] in
                    await self?.read(wallet, assets: readable, coverage: asked)
                }
            }
            (0..<Self.parallelReads).forEach { _ in addNext() }
            while await group.next() != nil { addNext() }
        }
        if Self.coverage(self.assets).isSubset(of: asked) {
            firstPassDone = true
        } else if started {
            // The token list grew while this pass was reading: the new tokens are unread, so the
            // first pass is not over, and the next one starts at once (or at the next appearance).
            pendingRefresh = true
        }
        cache.save()
        publish()
        scheduleRetryAfterFailures()
        // A token this pass found held that the price read did not ask about.
        let heldIds = priceIds(assets: assets)
        if !Set(heldIds).isSubset(of: Set(pricedIds)) {
            readPrices(ids: heldIds)
        }
    }

    /// What a pass asks every wallet about: each token with its precision.
    private static func coverage(_ assets: [PortfolioAssetSource]) -> Set<String> {
        Set(assets.map { "\($0.id):\($0.precision)" })
    }

    /// One price read at a time; a request made meanwhile runs once it has finished.
    private func readPrices(ids: [String]) {
        guard priceTask == nil else {
            pendingPriceIds = ids
            return
        }
        priceTask = Task { @MainActor [weak self] in
            await self?.loadPrices(ids: ids)
            guard let self, !Task.isCancelled else { return }
            self.cache.save()
            self.publish()
            self.priceTask = nil
            if let next = self.pendingPriceIds {
                self.pendingPriceIds = nil
                self.readPrices(ids: next)
            }
        }
    }

    /// Reads one wallet on every network at once. Each network's answer shows as soon as it
    /// arrives: SORA2 never waits for SORA Nexus or Taira, nor they for each other.
    private func read(_ wallet: PortfolioWalletSource, assets: [(id: String, precision: Int16)],
                      coverage: Set<String>) async {
        // A wallet removed while this read waited for its turn (here or in a newer tab, which
        // keeps the shared list) is not read, nor put back.
        guard cache.wallets.contains(where: { $0.id == wallet.id }) else { return }
        let readRevision = selectedBalanceRevision
        let sora2Reader = self.sora2Reader, nexusReader = self.nexusReader, deadline = readDeadline
        let networks = liveNetworks.subtracting([.sora2]).sorted(by: { $0.rank() < $1.rank() })
            .compactMap { network in networkAccounts[wallet.id]?[network].map { (network, $0) } }
        var attempt = cache.reads[wallet.id] ?? PortfolioWalletReadState()
        let attemptStart = Date()
        attempt.lastAttempt = attemptStart
        attempt.attemptCoverage = coverage
        // A network this attempt does not read (turned off since) is no longer reported as failing.
        attempt.failed = attempt.failed.filter { failed in
            failed == .sora2 || networks.contains { $0.0 == failed }
        }
        cache.reads[wallet.id] = attempt
        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor [weak self] in
                let balances = try? await PortfolioReadDeadline.run(seconds: deadline) {
                    try await sora2Reader.balances(address: wallet.id, assets: assets)
                }
                self?.record(wallet: wallet.id, attempt: attemptStart, network: .sora2,
                             succeeded: balances != nil) { state in
                    guard let balances else {
                        state.failedReads += 1
                        state.lastFailure = Date()
                        return
                    }
                    state.sora2 = balances
                    state.sora2Coverage = coverage
                    state.lastRead = Date()
                    state.failedReads = 0
                }
            }
            for (network, account) in networks {
                group.addTask { @MainActor [weak self] in
                    var amount: Decimal?
                    if !Task.isCancelled {
                        amount = try? await PortfolioReadDeadline.run(seconds: deadline) {
                            try await nexusReader.xorBalance(account: account)
                        }
                    }
                    self?.record(wallet: wallet.id, attempt: attemptStart, network: network,
                                 succeeded: amount != nil) { state in
                        if let amount { state.nexus[network] = amount }
                    }
                }
            }
        }
        if wallet.isSelected { selectedDirty = selectedBalanceRevision != readRevision }
    }

    /// A wallet whose SORA2 read failed is read again after its retry interval, sooner than the
    /// 15-second tick would get to it.
    private func scheduleRetryAfterFailures() {
        let now = Date()
        let waits = wallets.compactMap { wallet -> TimeInterval? in
            guard let state = cache.reads[wallet.id], state.failedReads > 0, let since = state.retryCountedFrom else {
                return nil
            }
            return PortfolioFreshnessPolicy.retryInterval(failedReads: state.failedReads) - now.timeIntervalSince(since)
        }
        guard let wait = waits.min(), wait < 15 else { return }
        retryTask?.cancel()
        retryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(max(0.5, wait) * 1_000_000_000))
            guard !Task.isCancelled, let self, self.started else { return }
            self.refresh(force: false)
        }
    }

    /// One network's answer for one wallet. A failed network stays listed until it answers again.
    /// The answer is dropped when its attempt is no longer the wallet's latest in the shared cache:
    /// the wallet was removed meanwhile (by this tab or a newer one), or a newer attempt began, so an
    /// older answer never replaces a newer one.
    private func record(wallet id: String, attempt: Date, network: PortfolioNetwork, succeeded: Bool,
                        _ update: (inout PortfolioWalletReadState) -> Void) {
        guard wallets.contains(where: { $0.id == id }),
              var state = cache.reads[id], state.lastAttempt == attempt else { return }
        update(&state)
        var failed = state.failed.filter { $0 != network }
        if !succeeded { failed.append(network) }
        state.failed = failed.sorted { $0.rank() < $1.rank() }
        cache.reads[id] = state
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
            Self.listQueue.addOperation(operation)
        }
        let selected = SelectedWalletSettings.shared.currentAccount?.address
        let stored = (try? storedNetworkAccounts()) ?? []
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

    /// The tokens whose prices are read: those any wallet holds, and XOR.
    private func priceIds(assets: [PortfolioAssetSource]) -> [String] {
        let held = Set(cache.reads.values.flatMap { read in
            (read.sora2 ?? [:]).filter { $0.value.total > 0 }.map(\.key)
        } + [PortfolioSnapshotBuilder.xorId])
        return assets.map(\.id).filter { held.contains($0) }
    }

    private func loadPrices(ids: [String]) async {
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
        var next = PortfolioSnapshotBuilder.build(
            PortfolioSnapshotBuilder.Sources(wallets: wallets, assets: assets, reads: cache.reads, prices: cache.prices),
            settings: PortfolioSnapshotBuilder.Settings(networks: shownNetworks, liveNetworks: liveNetworks,
                                                        swapsAvailable: true,
                                                        disclaimerAccepted: ApplicationConfig.shared.isDisclamerShown),
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
