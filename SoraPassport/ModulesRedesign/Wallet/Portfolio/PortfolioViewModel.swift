// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Per-device choices: scope, lens and the chart slot maps.
final class PortfolioPreferences: PortfolioSlotStoring {
    static let scopeKey = "portfolio.scope.v1"
    static let lensKey = "portfolio.lens.v1"
    static let slotsKey = "portfolio.slots.v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var scope: PortfolioScope? {
        get { defaults.string(forKey: Self.scopeKey).flatMap(PortfolioScope.init(storageKey:)) }
        set { defaults.set(newValue?.storageKey, forKey: Self.scopeKey) }
    }

    var lens: PortfolioLens {
        get { defaults.string(forKey: Self.lensKey).flatMap(PortfolioLens.init(rawValue:)) ?? .tokens }
        set { defaults.set(newValue.rawValue, forKey: Self.lensKey) }
    }

    private var allSlots: [String: [String: Int]] {
        get { defaults.dictionary(forKey: Self.slotsKey) as? [String: [String: Int]] ?? [:] }
        set { defaults.set(newValue, forKey: Self.slotsKey) }
    }

    private static func key(scope: PortfolioScope, lens: PortfolioLens) -> String {
        "\(scope.storageKey)|\(lens.rawValue)"
    }

    func slots(scope: PortfolioScope, lens: PortfolioLens) -> [String: Int]? {
        allSlots[Self.key(scope: scope, lens: lens)]
    }

    func setSlots(_ slots: [String: Int], scope: PortfolioScope, lens: PortfolioLens) {
        var all = allSlots
        all[Self.key(scope: scope, lens: lens)] = slots
        allSlots = all
    }
}

/// The source of the dashboard's numbers: the live wallets, or the debug sample.
@MainActor
protocol PortfolioDataSource: AnyObject {
    var snapshot: PortfolioSnapshot { get }
    var onChange: ((PortfolioSnapshot) -> Void)? { get set }
    /// True for the debug sample: nothing it shows is a real wallet.
    var isSample: Bool { get }
    /// The dashboard became visible: read now and keep refreshing (at most once a minute).
    func start()
    /// The dashboard is no longer visible: stop refreshing.
    func stop()
    /// Read every wallet again now.
    func refreshAll()
    /// Symbol and icon of an asset of the app's asset list (swap targets).
    func asset(_ id: String) -> (symbol: String, icon: String?)?
}

enum PortfolioQuickAction: Equatable {
    case send
    case receive
    case move
    case swap
}

/// What the dashboard asks its coordinator to show.
enum PortfolioRoute: Equatable {
    case walletsSheet
    case tokenDetail(tokenId: String, holdingId: String?)
    case howWeCount
    case partial([PortfolioNetwork])
    case quickAction(PortfolioQuickAction)
}

/// State and presentation of the dashboard. UIKit-free so it can be tested with a fake source.
@MainActor
final class PortfolioViewModel {
    var onRender: ((PortfolioRender) -> Void)?
    var onRoute: ((PortfolioRoute) -> Void)?

    private(set) var render: PortfolioRender?
    private(set) var state: PortfolioPresentationState
    private let dataSource: PortfolioDataSource
    private let preferences: PortfolioPreferences
    private let now: () -> Date
    private var ticker: Timer?
    private var isVisible = false

    var snapshot: PortfolioSnapshot { dataSource.snapshot }
    var isSample: Bool { dataSource.isSample }

    init(dataSource: PortfolioDataSource, preferences: PortfolioPreferences = PortfolioPreferences(),
         now: @escaping () -> Date = Date.init) {
        self.dataSource = dataSource
        self.preferences = preferences
        self.now = now
        state = PortfolioPresentationState(scope: .allWallets, lens: preferences.lens)
        state.scope = resolvedScope(preferences.scope, snapshot: dataSource.snapshot)
        dataSource.onChange = { [weak self] _ in self?.snapshotDidChange() }
    }

    /// Default scope: All wallets with two or more wallets, else the wallet. The last choice sticks.
    func resolvedScope(_ stored: PortfolioScope?, snapshot: PortfolioSnapshot) -> PortfolioScope {
        let wallets = snapshot.wallets
        if wallets.count >= 2 {
            if let stored {
                switch stored {
                case .allWallets: return .allWallets
                case let .wallet(id) where wallets.contains(where: { $0.id == id }): return stored
                default: break
                }
            }
            return .allWallets
        }
        if let only = wallets.first { return .wallet(only.id) }
        return stored ?? .allWallets
    }

    // MARK: Lifecycle

    func viewWillAppear() {
        isVisible = true
        dataSource.start()
        update()
        ticker?.invalidate()
        // Ages ("LIVE · 31s") move on without new reads; nothing is animated.
        ticker = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.update() }
        }
    }

    func viewDidDisappear() {
        isVisible = false
        ticker?.invalidate()
        ticker = nil
        dataSource.stop()
    }

    func refreshAll() {
        dataSource.refreshAll()
    }

    private func snapshotDidChange() {
        let scope = resolvedScope(state.scope, snapshot: dataSource.snapshot)
        if scope != state.scope { state.scope = scope }
        update()
    }

    func update() {
        if !PortfolioPresenter.lenses(for: state.scope).contains(state.lens) { state.lens = .tokens }
        let render = PortfolioPresenter.render(dataSource.snapshot, state: state, store: preferences, now: now())
        guard render != self.render else { return }
        self.render = render
        onRender?(render)
    }

    // MARK: Intents

    func selectScope(_ scope: PortfolioScope) {
        let resolved = resolvedScope(scope, snapshot: dataSource.snapshot)
        guard resolved != state.scope else { return }
        state.scope = resolved
        state.expanded = []
        state.highlighted = nil
        preferences.scope = resolved
        update()
    }

    func selectLens(_ lens: PortfolioLens) {
        guard PortfolioPresenter.lenses(for: state.scope).contains(lens), lens != state.lens else { return }
        state.lens = lens
        state.expanded = []
        state.highlighted = nil
        preferences.lens = lens
        update()
    }

    func toggleRow(_ key: String) {
        if state.expanded.contains(key) {
            state.expanded.remove(key)
        } else {
            state.expanded.insert(key)
        }
        update()
    }

    /// A legend chip or a ray: the first tap highlights the group; a second tap on a token opens
    /// Where it lives, on any other group it clears the highlight.
    func tapGroup(_ key: String) {
        if state.highlighted == key {
            if state.lens == .tokens, key != PortfolioAllocation.otherKey {
                onRoute?(.tokenDetail(tokenId: key, holdingId: nil))
            }
            state.highlighted = nil
        } else {
            state.highlighted = key
        }
        update()
    }

    func clearHighlight() {
        guard state.highlighted != nil else { return }
        state.highlighted = nil
        update()
    }

    func openRow(_ row: PortfolioRow) {
        switch row.kind {
        case .token:
            if row.isExpandable {
                toggleRow(row.key)
            } else {
                let holding = PortfolioAggregator.holdings(ofToken: row.key, in: dataSource.snapshot,
                                                           scope: state.scope).first
                onRoute?(.tokenDetail(tokenId: row.key, holdingId: holding?.id))
            }
        case .network, .wallet:
            toggleRow(row.key)
        }
    }

    func openChild(_ child: PortfolioChildRow) {
        switch child.target {
        case let .holding(id):
            guard let holding = dataSource.snapshot.holdings.first(where: { $0.id == id }) else { return }
            onRoute?(.tokenDetail(tokenId: holding.token.id, holdingId: id))
        case let .token(id):
            onRoute?(.tokenDetail(tokenId: id, holdingId: nil))
        }
    }

    func openWalletAlone(_ walletId: String) {
        selectScope(.wallet(walletId))
    }

    func tapScope() {
        guard dataSource.snapshot.wallets.count >= 2 else { return }
        onRoute?(.walletsSheet)
    }

    func tapCaption() {
        onRoute?(.howWeCount)
    }

    func tapChip() {
        let summary = PortfolioAggregator.summary(dataSource.snapshot, scope: state.scope)
        switch summary.freshness.state {
        case .partial, .offline, .saved:
            onRoute?(.partial(summary.freshness.unreachable))
        case .live:
            break
        }
    }

    func quickAction(_ action: PortfolioQuickAction) {
        onRoute?(.quickAction(action))
    }

    // MARK: Queries for the coordinator

    var walletSlots: [String: PortfolioSlot] {
        PortfolioPresenter.walletSlots(dataSource.snapshot, store: preferences)
    }

    func detailModel(tokenId: String, holdingId: String?) -> PortfolioDetailModel? {
        PortfolioDetailPresenter.model(tokenId: tokenId, selectedHoldingId: holdingId, snapshot: dataSource.snapshot,
                                       scope: state.scope, walletSlots: walletSlots)
    }

    func holding(_ id: String) -> PortfolioHolding? {
        dataSource.snapshot.holdings.first { $0.id == id }
    }

    /// Wallets in scope for the Send and Receive pickers (selected first).
    var walletsForPicker: [PortfolioWallet] {
        PortfolioAggregator.wallets(in: dataSource.snapshot, scope: state.scope)
            .sorted { lhs, rhs in
                if lhs.isSelected != rhs.isSelected { return lhs.isSelected }
                return lhs.order < rhs.order
            }
    }

    /// Holdings that Move can start from: transferable, on a live network, with another wallet there.
    var movableHoldings: [PortfolioHolding] {
        let snapshot = dataSource.snapshot
        return PortfolioAggregator.visibleHoldings(snapshot, scope: state.scope).filter { holding in
            holding.transferable > 0 && snapshot.liveNetworks.contains(holding.network) &&
                snapshot.wallets.contains { $0.id != holding.walletId && $0.networks.contains(holding.network) }
        }
    }

    /// Holdings that can be swapped now.
    var swappableHoldings: [PortfolioHolding] {
        let snapshot = dataSource.snapshot
        return PortfolioAggregator.visibleHoldings(snapshot, scope: state.scope).filter {
            PortfolioReadiness.evaluate($0, swapsAvailable: snapshot.swapsAvailable) == .ready
        }
    }
}
