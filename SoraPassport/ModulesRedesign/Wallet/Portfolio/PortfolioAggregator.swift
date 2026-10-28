// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Why a holding is left out of the total. The caption names every exclusion.
enum PortfolioExclusion: Hashable {
    case hidden
    case testnet
    case unpriced
}

struct PortfolioSummary: Equatable {
    /// Counted value in USD.
    let total: Decimal
    /// Fiat change of the counted value over 24 h.
    let change24h: Decimal
    /// Percent change over 24 h; `nil` without an earlier value to compare with.
    let changePercent: Decimal?
    let hiddenCount: Int
    let unpricedCount: Int
    let testnetCount: Int
    let freshness: PortfolioFreshness

    var hasExclusions: Bool { hiddenCount + unpricedCount + testnetCount > 0 }
}

/// One row of a lens: a token, a network or a wallet.
struct PortfolioGroup: Equatable {
    enum Kind: Equatable {
        case token(PortfolioToken)
        case network(PortfolioNetwork)
        case wallet(PortfolioWallet)
    }

    /// Entity key for the slot map: the token id, the network raw value or the wallet id.
    let key: String
    let kind: Kind
    /// Counted value in USD.
    let value: Decimal
    /// Share of the scope total, 0...1.
    let share: Decimal
    /// The visible holdings of this group, largest counted value first.
    let holdings: [PortfolioHolding]

    /// The group's networks in the app's network order.
    var networks: [PortfolioNetwork] {
        PortfolioNetwork.ordered(Array(Set(holdings.map(\.network))))
    }

    var walletIds: [String] {
        var seen = Set<String>()
        return holdings.compactMap { seen.insert($0.walletId).inserted ? $0.walletId : nil }
    }

    /// Amount of a token group. Mainnet holdings add up; a group with only testnet
    /// holdings shows its testnet amount, which is never counted.
    var tokenAmount: Decimal {
        let mainnet = holdings.filter { !$0.network.isTestnet }
        let source = mainnet.isEmpty ? holdings : mainnet
        return source.reduce(Decimal(0)) { $0 + $1.amount }
    }

    var isTestnetOnly: Bool { !holdings.isEmpty && holdings.allSatisfy { $0.network.isTestnet } }
}

enum PortfolioAggregator {
    /// The first rule that excludes a holding from the total, if any.
    static func exclusion(for holding: PortfolioHolding) -> PortfolioExclusion? {
        if holding.isHidden { return .hidden }
        if holding.network.isTestnet { return .testnet }
        if holding.token.priceUSD == nil { return .unpriced }
        return nil
    }

    /// The total counts visible, priced, mainnet holdings.
    static func isCounted(_ holding: PortfolioHolding) -> Bool {
        holding.amount > 0 && exclusion(for: holding) == nil
    }

    /// Amount times the asset's own price; zero when the holding is not counted.
    static func value(of holding: PortfolioHolding) -> Decimal {
        guard isCounted(holding), let price = holding.token.priceUSD else { return 0 }
        return holding.amount * price
    }

    /// Fiat change over 24 h of a counted holding, from its asset's own price change.
    static func change24h(of holding: PortfolioHolding) -> Decimal {
        let current = value(of: holding)
        guard current > 0, let percent = holding.token.change24h else { return 0 }
        let factor = 1 + percent / 100
        guard factor > 0 else { return 0 }
        return current - current / factor
    }

    /// Holdings with a balance in the scope, hidden ones included.
    static func scopedHoldings(_ snapshot: PortfolioSnapshot, scope: PortfolioScope) -> [PortfolioHolding] {
        let walletIds = Set(snapshot.wallets.map(\.id))
        return snapshot.holdings.filter {
            $0.amount > 0 && walletIds.contains($0.walletId) && scope.contains(walletId: $0.walletId)
        }
    }

    /// Holdings the lists show: in scope, with a balance, not hidden.
    static func visibleHoldings(_ snapshot: PortfolioSnapshot, scope: PortfolioScope) -> [PortfolioHolding] {
        sortedLargestFirst(scopedHoldings(snapshot, scope: scope).filter { !$0.isHidden })
    }

    /// One wallet's own total.
    static func walletTotal(_ walletId: String, in snapshot: PortfolioSnapshot) -> Decimal {
        snapshot.holdings
            .filter { $0.walletId == walletId }
            .reduce(Decimal(0)) { $0 + value(of: $1) }
    }

    static func walletChange(_ walletId: String, in snapshot: PortfolioSnapshot) -> Decimal {
        snapshot.holdings
            .filter { $0.walletId == walletId }
            .reduce(Decimal(0)) { $0 + change24h(of: $1) }
    }

    static func wallets(in snapshot: PortfolioSnapshot, scope: PortfolioScope) -> [PortfolioWallet] {
        snapshot.wallets.filter { scope.contains(walletId: $0.id) }
    }

    /// Total, 24 h change, exclusions and freshness of a scope.
    /// All wallets is the sum of each wallet's own total.
    static func summary(_ snapshot: PortfolioSnapshot, scope: PortfolioScope) -> PortfolioSummary {
        let wallets = wallets(in: snapshot, scope: scope)
        let total = wallets.reduce(Decimal(0)) { $0 + walletTotal($1.id, in: snapshot) }
        let change = wallets.reduce(Decimal(0)) { $0 + walletChange($1.id, in: snapshot) }
        let previous = total - change
        let percent: Decimal? = previous > 0 ? change / previous * 100 : nil

        var hidden = 0, unpriced = 0, testnet = 0
        for holding in scopedHoldings(snapshot, scope: scope) {
            switch exclusion(for: holding) {
            case .hidden: hidden += 1
            case .unpriced: unpriced += 1
            case .testnet: testnet += 1
            case .none: break
            }
        }

        return PortfolioSummary(total: total,
                                change24h: change,
                                changePercent: percent,
                                hiddenCount: hidden,
                                unpricedCount: unpriced,
                                testnetCount: testnet,
                                freshness: PortfolioFreshnessPolicy.combined(wallets.map(\.freshness)))
    }

    /// Rows of a lens, largest counted value first. Rows add up to the summary total.
    static func groups(_ snapshot: PortfolioSnapshot, scope: PortfolioScope, lens: PortfolioLens) -> [PortfolioGroup] {
        let holdings = visibleHoldings(snapshot, scope: scope)
        let total = summary(snapshot, scope: scope).total

        func share(_ value: Decimal) -> Decimal { total > 0 ? value / total : 0 }

        switch lens {
        case .tokens:
            var order: [String] = []
            var byToken: [String: [PortfolioHolding]] = [:]
            for holding in holdings {
                if byToken[holding.token.id] == nil { order.append(holding.token.id) }
                byToken[holding.token.id, default: []].append(holding)
            }
            let groups = order.compactMap { tokenId -> PortfolioGroup? in
                guard let members = byToken[tokenId], !members.isEmpty else { return nil }
                // A SORA2 member carries the asset's own metadata; Nexus members reuse its identity.
                let token = members.first { $0.network == .sora2 }?.token ?? members[0].token
                let value = members.reduce(Decimal(0)) { $0 + Self.value(of: $1) }
                return PortfolioGroup(key: tokenId, kind: .token(token), value: value,
                                      share: share(value), holdings: sortedLargestFirst(members))
            }
            return groups.sorted(by: groupOrder)

        case .networks:
            let walletNetworks = Set(wallets(in: snapshot, scope: scope).flatMap(\.networks))
            let groups = snapshot.networks
                .filter { network in
                    walletNetworks.contains(network) || holdings.contains { $0.network == network }
                }
                .map { network -> PortfolioGroup in
                    let members = holdings.filter { $0.network == network }
                    let value = members.reduce(Decimal(0)) { $0 + Self.value(of: $1) }
                    return PortfolioGroup(key: network.rawValue, kind: .network(network), value: value,
                                          share: share(value), holdings: sortedLargestFirst(members))
                }
            return groups.sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                guard case let .network(left) = lhs.kind, case let .network(right) = rhs.kind else { return false }
                return left.rank(in: snapshot.directory) < right.rank(in: snapshot.directory)
            }

        case .wallets:
            let groups = wallets(in: snapshot, scope: scope).map { wallet -> PortfolioGroup in
                let members = holdings.filter { $0.walletId == wallet.id }
                let value = walletTotal(wallet.id, in: snapshot)
                return PortfolioGroup(key: wallet.id, kind: .wallet(wallet), value: value,
                                      share: share(value), holdings: sortedLargestFirst(members))
            }
            return groups.sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                guard case let .wallet(left) = lhs.kind, case let .wallet(right) = rhs.kind else { return false }
                return left.order < right.order
            }
        }
    }

    /// Holdings of one token in a scope, largest first, hidden ones left out.
    static func holdings(ofToken tokenId: String, in snapshot: PortfolioSnapshot,
                         scope: PortfolioScope) -> [PortfolioHolding] {
        visibleHoldings(snapshot, scope: scope).filter { $0.token.id == tokenId }
    }

    static func sortedLargestFirst(_ holdings: [PortfolioHolding]) -> [PortfolioHolding] {
        holdings.sorted { lhs, rhs in
            let left = value(of: lhs), right = value(of: rhs)
            if left != right { return left > right }
            if lhs.network.isTestnet != rhs.network.isTestnet { return !lhs.network.isTestnet }
            if lhs.amount != rhs.amount { return lhs.amount > rhs.amount }
            if lhs.network != rhs.network { return lhs.network.rank() < rhs.network.rank() }
            return lhs.walletId < rhs.walletId
        }
    }

    private static func groupOrder(_ lhs: PortfolioGroup, _ rhs: PortfolioGroup) -> Bool {
        if lhs.value != rhs.value { return lhs.value > rhs.value }
        if lhs.isTestnetOnly != rhs.isTestnetOnly { return !lhs.isTestnetOnly }
        guard case let .token(left) = lhs.kind, case let .token(right) = rhs.kind else { return lhs.key < rhs.key }
        if left.symbol != right.symbol { return left.symbol < right.symbol }
        return left.id < right.id
    }
}
