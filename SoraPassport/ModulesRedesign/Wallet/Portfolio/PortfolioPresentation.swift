// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

import Foundation

// MARK: - View models

struct PortfolioSkyModel: Equatable {
    var segments: [PortfolioFanSegment]
    var highlightedKey: String?
    var showsFan: Bool
}

enum PortfolioChangeDirection: Equatable {
    case up
    case down
    case flat
}

enum PortfolioChipTone: Equatable {
    case live
    case saved
    case partial
    case offline
}

enum PortfolioIcon: Equatable {
    case token(id: String, symbol: String, icon: String?)
    case network(PortfolioNetwork)
    case wallet(id: String, name: String)
    case allWallets
}

enum PortfolioTag: Equatable {
    /// On SORA2 and listed on Polkaswap.
    case swapReady
    /// The app's network tag (`WalletNetworkDirectory`): Main, Coming soon or Testnet.
    case network(WalletNetworkTag)
}

struct PortfolioLegendChip: Equatable {
    let key: String
    let title: String
    let percent: String
    let slot: PortfolioSlot
    let isSelected: Bool
    /// A second tap opens Where it lives (token groups only).
    let opensToken: Bool
    let accessibilityLabel: String
}

struct PortfolioHeroModel: Equatable {
    let scopeTitle: String
    let scopeIcon: PortfolioIcon
    let canChangeScope: Bool
    let totalWhole: String
    let totalFraction: String
    /// Offline: amounts stay, total and change in the secondary colour.
    let isDimmed: Bool
    let changeAmount: String?
    let changePercent: String?
    let direction: PortfolioChangeDirection
    let caption: String?
    let chipText: String
    let chipTone: PortfolioChipTone
    let unreachable: [PortfolioNetwork]
    let sky: PortfolioSkyModel
    let legend: [PortfolioLegendChip]
    let isEmpty: Bool
    /// The first read is running and nothing is known yet: a dash for the total, no chip.
    let isLoading: Bool
    let accessibilityTotal: String
}

struct PortfolioChildRow: Equatable {
    enum Target: Equatable {
        case holding(String)
        case token(String)
    }

    let key: String
    let icon: PortfolioIcon
    let title: String
    let subtitle: String
    let walletSlot: PortfolioSlot?
    let value: String
    let detail: String
    let tag: PortfolioTag?
    let target: Target
    let accessibilityLabel: String
}

struct PortfolioRow: Equatable {
    enum Kind: Equatable {
        case token
        case network
        case wallet
    }

    let key: String
    let kind: Kind
    let icon: PortfolioIcon
    let title: String
    let change: String?
    let direction: PortfolioChangeDirection
    let subtitle: String
    let walletDots: [PortfolioSlot]
    let value: String
    let detail: String
    let tag: PortfolioTag?
    let isExpandable: Bool
    let isExpanded: Bool
    let children: [PortfolioChildRow]
    /// "Open Main alone" under an expanded wallet row.
    let link: String?
    let accessibilityLabel: String
}

struct PortfolioListModel: Equatable {
    let lenses: [PortfolioLens]
    let lens: PortfolioLens
    let rows: [PortfolioRow]
    let emptyText: String?
}

struct PortfolioRender: Equatable {
    let hero: PortfolioHeroModel
    let list: PortfolioListModel
}

struct PortfolioPresentationState: Equatable {
    var scope: PortfolioScope
    var lens: PortfolioLens
    var expanded: Set<String> = []
    var highlighted: String?
}

/// Persistent chart slots per scope and lens (`portfolio.slots.v1`).
protocol PortfolioSlotStoring: AnyObject {
    func slots(scope: PortfolioScope, lens: PortfolioLens) -> [String: Int]?
    func setSlots(_ slots: [String: Int], scope: PortfolioScope, lens: PortfolioLens)
}

// MARK: - Presenter

enum PortfolioPresenter {
    static let childLimit = 5

    /// Lenses available in a scope: Wallets only in All wallets.
    static func lenses(for scope: PortfolioScope) -> [PortfolioLens] {
        scope == .allWallets ? [.tokens, .networks, .wallets] : [.tokens, .networks]
    }

    /// Stable fan for a scope and lens; persists the slot map.
    static func fan(_ snapshot: PortfolioSnapshot, scope: PortfolioScope, lens: PortfolioLens,
                    store: PortfolioSlotStoring) -> [PortfolioFanSegment] {
        let groups = PortfolioAggregator.groups(snapshot, scope: scope, lens: lens)
        let previous = store.slots(scope: scope, lens: lens) ?? PortfolioAllocation.seed(for: lens)
        let result = PortfolioAllocation.fan(values: groups.map { ($0.key, $0.value) }, previousSlots: previous)
        if result.slots != previous {
            store.setSlots(result.slots, scope: scope, lens: lens)
        }
        return result.segments
    }

    /// Colour of each wallet (its slot in the All wallets fan, by wallet).
    static func walletSlots(_ snapshot: PortfolioSnapshot, store: PortfolioSlotStoring) -> [String: PortfolioSlot] {
        let segments = fan(snapshot, scope: .allWallets, lens: .wallets, store: store)
        var result: [String: PortfolioSlot] = [:]
        for segment in segments where !segment.isOther {
            result[segment.key] = segment.slot
        }
        // Wallets without counted value still get a dot colour: the next free slots, then Other.
        let used = Set(result.values.compactMap { slot -> Int? in
            if case let .slot(index) = slot { return index }
            return nil
        })
        var free = (0..<PortfolioAllocation.slotCount).filter { !used.contains($0) }
        for wallet in snapshot.wallets.sorted(by: { $0.order < $1.order }) where result[wallet.id] == nil {
            result[wallet.id] = free.isEmpty ? .other : .slot(free.removeFirst())
        }
        return result
    }

    static func render(_ snapshot: PortfolioSnapshot, state: PortfolioPresentationState,
                       store: PortfolioSlotStoring, now: Date) -> PortfolioRender {
        let walletSlots = walletSlots(snapshot, store: store)
        let lens = lenses(for: state.scope).contains(state.lens) ? state.lens : .tokens
        let hero = hero(snapshot, state: state, lens: lens, store: store, now: now)
        let list = list(snapshot, state: state, lens: lens, walletSlots: walletSlots, now: now)
        return PortfolioRender(hero: hero, list: list)
    }

    // MARK: Hero

    static func hero(_ snapshot: PortfolioSnapshot, state: PortfolioPresentationState, lens: PortfolioLens,
                     store: PortfolioSlotStoring, now: Date) -> PortfolioHeroModel {
        let summary = PortfolioAggregator.summary(snapshot, scope: state.scope)
        let scoped = PortfolioAggregator.scopedHoldings(snapshot, scope: state.scope)
        let isLoading = snapshot.isLoading && scoped.isEmpty
        let isEmpty = scoped.isEmpty && !isLoading
        let segments = isEmpty ? [] : fan(snapshot, scope: state.scope, lens: lens, store: store)
        let groups = PortfolioAggregator.groups(snapshot, scope: state.scope, lens: lens)
        let highlighted = segments.contains(where: { $0.key == state.highlighted }) ? state.highlighted : nil

        let legend = segments.map { segment -> PortfolioLegendChip in
            let title = segment.isOther ? PortfolioStrings.other : groupTitle(segment.key, groups: groups,
                                                                             snapshot: snapshot)
            let percent = PortfolioAllocation.percentText(rays: segment.rays, share: segment.share)
            return PortfolioLegendChip(key: segment.key, title: title, percent: percent, slot: segment.slot,
                                       isSelected: segment.key == highlighted,
                                       opensToken: lens == .tokens && !segment.isOther,
                                       accessibilityLabel: "\(title), \(percent), \(PortfolioFormat.fiat(segment.value))")
        }

        let parts = PortfolioFormat.fiatParts(summary.total)
        let direction: PortfolioChangeDirection
        if PortfolioFormat.isFlat(summary.changePercent) {
            direction = .flat
        } else {
            direction = summary.change24h < 0 ? .down : .up
        }

        let scopeTitle: String
        let scopeIcon: PortfolioIcon
        switch state.scope {
        case .allWallets:
            scopeTitle = PortfolioStrings.allWallets
            scopeIcon = .allWallets
        case let .wallet(id):
            let wallet = snapshot.wallet(id)
            scopeTitle = wallet?.name ?? PortfolioFormat.shortAddress(id)
            scopeIcon = .wallet(id: id, name: scopeTitle)
        }

        let chip = isLoading ? (text: "", tone: PortfolioChipTone.saved)
            : PortfolioPresenter.chip(summary.freshness, now: now)
        let caption = isLoading ? nil : PortfolioStrings.notIncluded(hidden: summary.hiddenCount,
                                                                     unpriced: summary.unpricedCount,
                                                                     testnet: summary.testnetCount)
        let changeAmount = summary.changePercent == nil || isLoading ? nil : PortfolioFormat.signedFiat(summary.change24h)
        let changePercent = isLoading ? nil : summary.changePercent.map(PortfolioFormat.signedPercent)
        guard !isLoading else {
            return PortfolioHeroModel(scopeTitle: scopeTitle, scopeIcon: scopeIcon,
                                      canChangeScope: snapshot.wallets.count >= 2, totalWhole: "—", totalFraction: "",
                                      isDimmed: true, changeAmount: nil, changePercent: nil, direction: .flat,
                                      caption: nil, chipText: "", chipTone: chip.tone, unreachable: [],
                                      sky: PortfolioSkyModel(segments: [], highlightedKey: nil, showsFan: false),
                                      legend: [], isEmpty: false, isLoading: true,
                                      accessibilityTotal: PortfolioStrings.text("Total balance") + ", " +
                                          PortfolioStrings.readingBalances)
        }
        var spoken = "\(PortfolioStrings.text("Total balance")), \(PortfolioFormat.fiat(summary.total))"
        if let changeAmount, let changePercent {
            spoken += ". " + PortfolioStrings.format("%@, %@ in 24 hours", changeAmount, changePercent)
        }
        if let caption { spoken += ". " + caption }
        spoken += ". " + chip.text

        return PortfolioHeroModel(scopeTitle: scopeTitle,
                                  scopeIcon: scopeIcon,
                                  canChangeScope: snapshot.wallets.count >= 2,
                                  totalWhole: parts.whole,
                                  totalFraction: parts.fraction,
                                  isDimmed: summary.freshness.state == .offline,
                                  changeAmount: changeAmount,
                                  changePercent: changePercent,
                                  direction: direction,
                                  caption: caption,
                                  chipText: chip.text,
                                  chipTone: chip.tone,
                                  unreachable: summary.freshness.unreachable,
                                  sky: PortfolioSkyModel(segments: segments, highlightedKey: highlighted,
                                                         showsFan: !isEmpty && summary.total > 0),
                                  legend: legend,
                                  isEmpty: isEmpty,
                                  isLoading: false,
                                  accessibilityTotal: spoken)
    }

    static func chip(_ freshness: PortfolioFreshness, now: Date) -> (text: String, tone: PortfolioChipTone) {
        let age = PortfolioFreshnessPolicy.ageText(since: freshness.updatedAt, now: now)
        switch freshness.state {
        case .live:
            return (age.map { "\(PortfolioStrings.live) · \($0)" } ?? PortfolioStrings.live, .live)
        case .saved:
            return (age.map { "\(PortfolioStrings.saved) · \($0)" } ?? PortfolioStrings.saved, .saved)
        case .partial:
            return (PortfolioStrings.partial, .partial)
        case .offline:
            return (PortfolioStrings.offline, .offline)
        }
    }

    private static func groupTitle(_ key: String, groups: [PortfolioGroup], snapshot: PortfolioSnapshot) -> String {
        guard let group = groups.first(where: { $0.key == key }) else { return key }
        switch group.kind {
        case let .token(token): return token.symbol
        case let .network(network): return PortfolioStrings.networkName(network)
        case let .wallet(wallet): return wallet.name
        }
    }

    // MARK: List

    static func list(_ snapshot: PortfolioSnapshot, state: PortfolioPresentationState, lens: PortfolioLens,
                     walletSlots: [String: PortfolioSlot], now: Date) -> PortfolioListModel {
        var groups = PortfolioAggregator.groups(snapshot, scope: state.scope, lens: lens)
        if lens == .networks {
            // A list of networks follows the app's network order (main first); the fan stays largest first.
            let order = PortfolioNetwork.ordered(PortfolioNetwork.allCases, directory: snapshot.directory)
            func rank(_ group: PortfolioGroup) -> Int {
                guard case let .network(network) = group.kind else { return order.count }
                return order.firstIndex(of: network) ?? order.count
            }
            groups.sort { rank($0) < rank($1) }
        }
        let showsWalletDots = state.scope == .allWallets && snapshot.wallets.count > 1
        let rows: [PortfolioRow] = groups.compactMap { group in
            switch group.kind {
            case let .token(token):
                return tokenRow(group, token: token, snapshot: snapshot, state: state,
                                walletSlots: walletSlots, showsWalletDots: showsWalletDots)
            case let .network(network):
                return networkRow(group, network: network, snapshot: snapshot, state: state,
                                  walletSlots: walletSlots, showsWalletDots: showsWalletDots)
            case let .wallet(wallet):
                return walletRow(group, wallet: wallet, snapshot: snapshot, state: state, now: now)
            }
        }
        let emptyText = rows.isEmpty
            ? (snapshot.isLoading ? PortfolioStrings.readingBalances : PortfolioStrings.noBalanceYet) : nil
        return PortfolioListModel(lenses: lenses(for: state.scope), lens: lens, rows: rows, emptyText: emptyText)
    }

    static func direction(of percent: Decimal?) -> PortfolioChangeDirection {
        guard let percent, !PortfolioFormat.isFlat(percent) else { return .flat }
        return percent < 0 ? .down : .up
    }

    static func changeText(_ percent: Decimal?) -> String? {
        guard let percent, !PortfolioFormat.isFlat(percent) else { return nil }
        return (percent < 0 ? "▼ " : "▲ ") + PortfolioFormat.signedPercent(percent)
    }

    static func valueText(of holdings: [PortfolioHolding]) -> String {
        let value = holdings.reduce(Decimal(0)) { $0 + PortfolioAggregator.value(of: $1) }
        if value > 0 { return PortfolioFormat.fiat(value) }
        if holdings.allSatisfy({ $0.network.isTestnet }) { return "—" }
        if holdings.contains(where: { $0.token.priceUSD == nil && !$0.network.isTestnet }) {
            return PortfolioStrings.noPrice
        }
        return PortfolioFormat.fiat(0)
    }

    static func holdingValueText(_ holding: PortfolioHolding) -> String {
        if holding.network.isTestnet { return "—" }
        guard holding.token.priceUSD != nil else { return PortfolioStrings.noPrice }
        return PortfolioFormat.fiat(PortfolioAggregator.value(of: holding))
    }

    /// Swap-ready when actionable; otherwise the network's own tag where a row needs one (Testnet,
    /// Coming soon). Rows on the main network and other live mainnets carry none.
    static func tag(for holding: PortfolioHolding, snapshot: PortfolioSnapshot) -> PortfolioTag? {
        switch PortfolioReadiness.evaluate(holding, swapsAvailable: snapshot.swapsAvailable) {
        case .ready: return .swapReady
        case .test: return .network(.testnet)
        case .notTradable, .noRoute:
            return snapshot.tag(for: holding.network) == .comingSoon ? .network(.comingSoon) : nil
        }
    }

    private static func holdingChild(_ holding: PortfolioHolding, snapshot: PortfolioSnapshot,
                                     walletSlots: [String: PortfolioSlot]) -> PortfolioChildRow {
        let walletName = snapshot.wallet(holding.walletId)?.name ?? ""
        let network = PortfolioStrings.networkName(holding.network)
        let amount = PortfolioFormat.amount(holding.amount, symbol: holding.token.symbol)
        let value = holdingValueText(holding)
        let tag = tag(for: holding, snapshot: snapshot)
        var spoken = "\(network), \(walletName), \(amount), \(value)"
        if tag == .swapReady { spoken += ", " + PortfolioStrings.swapReady }
        if tag == .network(.testnet) { spoken += ", " + PortfolioStrings.testnetNoValue }
        return PortfolioChildRow(key: holding.id, icon: .network(holding.network), title: network,
                                 subtitle: walletName, walletSlot: walletSlots[holding.walletId],
                                 value: value, detail: amount, tag: tag, target: .holding(holding.id),
                                 accessibilityLabel: spoken)
    }

    static func tokenRow(_ group: PortfolioGroup, token: PortfolioToken, snapshot: PortfolioSnapshot,
                         state: PortfolioPresentationState, walletSlots: [String: PortfolioSlot],
                         showsWalletDots: Bool) -> PortfolioRow {
        let networks = group.networks
        let walletIds = group.walletIds
        let subtitle: String
        if networks.count > 1 {
            subtitle = PortfolioStrings.networksCount(networks.count)
        } else if walletIds.count > 1 {
            subtitle = PortfolioStrings.walletsCount(walletIds.count)
        } else {
            subtitle = networks.first.map(PortfolioStrings.networkName) ?? ""
        }
        let expandable = group.holdings.count >= 2
        let expanded = expandable && state.expanded.contains(group.key)
        let value = valueText(of: group.holdings)
        let amount = PortfolioFormat.amount(group.tokenAmount, symbol: token.symbol)
        let change = changeText(token.change24h)
        var spoken = "\(token.symbol), \(value), \(amount), \(subtitle)"
        if let change { spoken += ", " + change }
        return PortfolioRow(key: group.key, kind: .token,
                            icon: .token(id: token.id, symbol: token.symbol, icon: token.icon),
                            title: token.symbol, change: change, direction: direction(of: token.change24h),
                            subtitle: subtitle,
                            walletDots: showsWalletDots ? walletIds.compactMap { walletSlots[$0] } : [],
                            value: value, detail: amount, tag: group.isTestnetOnly ? .network(.testnet) : nil,
                            isExpandable: expandable, isExpanded: expanded,
                            children: expanded ? group.holdings.map {
                                holdingChild($0, snapshot: snapshot, walletSlots: walletSlots)
                            } : [],
                            link: nil, accessibilityLabel: spoken)
    }

    static func networkRow(_ group: PortfolioGroup, network: PortfolioNetwork, snapshot: PortfolioSnapshot,
                           state: PortfolioPresentationState, walletSlots: [String: PortfolioSlot],
                           showsWalletDots: Bool) -> PortfolioRow {
        let tokenGroups = Dictionary(grouping: group.holdings, by: { $0.token.id })
        let tokens = tokenGroups.values
            .map { PortfolioAggregator.sortedLargestFirst($0) }
            .sorted { lhs, rhs in
                let left = lhs.reduce(Decimal(0)) { $0 + PortfolioAggregator.value(of: $1) }
                let right = rhs.reduce(Decimal(0)) { $0 + PortfolioAggregator.value(of: $1) }
                if left != right { return left > right }
                return (lhs.first?.token.symbol ?? "") < (rhs.first?.token.symbol ?? "")
            }
        let name = PortfolioStrings.networkName(network)
        let networkTag = snapshot.tag(for: network)
        let subtitle: String
        if group.holdings.isEmpty {
            // A network that is not live yet only has an address to copy.
            subtitle = networkTag == .comingSoon ? PortfolioStrings.addressReady : PortfolioStrings.noBalanceYet
        } else if network.isTestnet {
            subtitle = PortfolioStrings.tokensCount(tokens.count)
        } else {
            subtitle = PortfolioStrings.tokensCount(tokens.count) + " · " + PortfolioFormat.share(group.share)
        }
        // Nexus rows always open: their well links to the app's own Nexus network screens.
        let expandable = !group.holdings.isEmpty || network != .sora2
        let expanded = expandable && state.expanded.contains(group.key)
        let children: [PortfolioChildRow] = expanded ? tokens.prefix(childLimit).compactMap { holdings in
            guard let token = holdings.first?.token else { return nil }
            let amount = holdings.reduce(Decimal(0)) { $0 + $1.amount }
            let walletIds = Set(holdings.map(\.walletId))
            let walletText = walletIds.count == 1
                ? (snapshot.wallet(holdings[0].walletId)?.name ?? "")
                : PortfolioStrings.walletsCount(walletIds.count)
            let value = valueText(of: holdings)
            let amountText = PortfolioFormat.amount(amount, symbol: token.symbol)
            return PortfolioChildRow(key: "\(network.rawValue)|\(token.id)",
                                     icon: .token(id: token.id, symbol: token.symbol, icon: token.icon),
                                     title: token.symbol, subtitle: walletText,
                                     walletSlot: walletIds.count == 1 ? walletSlots[holdings[0].walletId] : nil,
                                     value: value, detail: amountText,
                                     tag: nil, target: .token(token.id),
                                     accessibilityLabel: "\(token.symbol), \(walletText), \(amountText), \(value)")
        } : []
        let value = network.isTestnet ? "—" : PortfolioFormat.fiat(group.value)
        return PortfolioRow(key: group.key, kind: .network, icon: .network(network), title: name, change: nil,
                            direction: .flat, subtitle: subtitle,
                            walletDots: showsWalletDots
                                ? Array(Set(group.holdings.map(\.walletId))).sorted().compactMap { walletSlots[$0] } : [],
                            value: value, detail: PortfolioStrings.holdingsCount(group.holdings.count),
                            tag: networkTag.map { .network($0) }, isExpandable: expandable, isExpanded: expanded,
                            children: children,
                            link: expanded && network != .sora2 ? PortfolioStrings.openNetwork(name) : nil,
                            accessibilityLabel: [name, networkTag?.title, subtitle, value].compactMap { $0 }
                                .joined(separator: ", "))
    }

    static func walletRow(_ group: PortfolioGroup, wallet: PortfolioWallet, snapshot: PortfolioSnapshot,
                          state: PortfolioPresentationState, now: Date) -> PortfolioRow {
        // Share and networks under the name; total over freshness at the right.
        let freshness = chip(wallet.freshness, now: now).text
        let share = PortfolioFormat.share(group.share)
        let subtitle = share + " · " + PortfolioStrings.networksCount(wallet.networks.count)
        let expanded = state.expanded.contains(group.key)
        let children: [PortfolioChildRow] = expanded ? group.holdings.prefix(childLimit).map { holding in
            let amount = PortfolioFormat.amount(holding.amount, symbol: holding.token.symbol)
            let value = holdingValueText(holding)
            let network = PortfolioStrings.networkName(holding.network)
            return PortfolioChildRow(key: holding.id,
                                     icon: .token(id: holding.token.id, symbol: holding.token.symbol,
                                                  icon: holding.token.icon),
                                     title: holding.token.symbol, subtitle: network, walletSlot: nil,
                                     value: value, detail: amount,
                                     tag: tag(for: holding, snapshot: snapshot),
                                     target: .holding(holding.id),
                                     accessibilityLabel: "\(holding.token.symbol), \(network), \(amount), \(value)")
        } : []
        let value = PortfolioFormat.fiat(group.value)
        return PortfolioRow(key: group.key, kind: .wallet, icon: .wallet(id: wallet.id, name: wallet.name),
                            title: wallet.name, change: nil, direction: .flat, subtitle: subtitle, walletDots: [],
                            value: value, detail: freshness, tag: nil, isExpandable: true, isExpanded: expanded,
                            children: children, link: expanded ? PortfolioStrings.openAlone(wallet.name) : nil,
                            accessibilityLabel: "\(wallet.name), \(value), \(subtitle), \(freshness)")
    }
}
