// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import Foundation

enum PortfolioFreshnessPolicy {
    /// A read younger than this is live.
    static let liveWindow: TimeInterval = 120
    /// Non-selected wallets refresh at most once a minute while the dashboard is visible.
    static let refreshInterval: TimeInterval = 60

    /// The worst wallet's state. Live and saved report their oldest update;
    /// partial names every unreachable network.
    static func combined(_ items: [PortfolioFreshness]) -> PortfolioFreshness {
        guard let worst = items.map(\.state).max() else { return .offline }
        let same = items.filter { $0.state == worst }
        let oldest = same.compactMap(\.updatedAt).min()
        var unreachable: [PortfolioNetwork] = []
        for network in same.flatMap(\.unreachable) where !unreachable.contains(network) {
            unreachable.append(network)
        }
        return PortfolioFreshness(state: worst, updatedAt: oldest,
                                  unreachable: PortfolioNetwork.ordered(unreachable))
    }

    /// State of one wallet from the time of its last complete read and the counted
    /// networks that failed on the latest attempt.
    static func freshness(lastRead: Date?, failedNetworks: [PortfolioNetwork], now: Date) -> PortfolioFreshness {
        let counted = failedNetworks.filter { !$0.isTestnet }
        guard let lastRead else {
            return counted.isEmpty ? .offline : .partial(nil, unreachable: counted)
        }
        if !counted.isEmpty {
            // Something was read before: keep the age, but say which network is missing.
            return now.timeIntervalSince(lastRead) <= liveWindow
                ? .partial(lastRead, unreachable: counted)
                : .saved(lastRead)
        }
        return now.timeIntervalSince(lastRead) <= liveWindow ? .live(lastRead) : .saved(lastRead)
    }

    /// Compact age: 31s, 12m, 2h, 3d.
    static func ageText(since date: Date?, now: Date) -> String? {
        guard let date else { return nil }
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        switch seconds {
        case ..<60: return "\(seconds)s"
        case ..<3_600: return "\(seconds / 60)m"
        case ..<86_400: return "\(seconds / 3_600)h"
        default: return "\(seconds / 86_400)d"
        }
    }

    /// Whether a non-selected wallet is due for another read.
    static func isDue(lastAttempt: Date?, now: Date) -> Bool {
        guard let lastAttempt else { return true }
        return now.timeIntervalSince(lastAttempt) >= refreshInterval
    }
}

/// What stands between a holding and a Polkaswap swap.
enum PortfolioReadiness: Equatable {
    /// On SORA2, the asset trades on Polkaswap and swaps are on in this build.
    case ready
    /// On SORA2, but the asset is not listed on Polkaswap or swaps are off.
    case notTradable
    /// On a mainnet network without a route to SORA2 in this version.
    case noRoute(PortfolioNetwork)
    /// On a testnet: no monetary value.
    case test

    static func evaluate(_ holding: PortfolioHolding, swapsAvailable: Bool) -> PortfolioReadiness {
        if holding.network.isTestnet { return .test }
        guard holding.network.hostsPolkaswap else { return .noRoute(holding.network) }
        return holding.token.isSwappable && swapsAvailable ? .ready : .notTradable
    }

    /// Lists show a chip only when it is actionable or a testnet tag.
    var showsChip: Bool {
        switch self {
        case .ready, .test: return true
        case .notTradable, .noRoute: return false
        }
    }
}

/// Which action leads for a holding, and why the others are unavailable.
struct PortfolioActionPlan: Equatable {
    enum Action: Equatable {
        case swap
        case send
        case move
        case receiveOnSora2
    }

    struct Entry: Equatable {
        let action: Action
        /// Why the action cannot run here; `nil` when it can.
        let unavailableReason: UnavailableReason?
    }

    enum UnavailableReason: Equatable {
        case swapsRunOnSora2
        case notTradable
        case noOtherWallet
        case networkNotLive(PortfolioNetwork)
        case nothingTransferable
    }

    let primary: Entry
    let secondary: [Entry]

    static func plan(for holding: PortfolioHolding, readiness: PortfolioReadiness,
                     otherWalletsOnNetwork: Int, networkIsLive: Bool) -> PortfolioActionPlan {
        let moveReason: UnavailableReason? = {
            if !networkIsLive { return .networkNotLive(holding.network) }
            if otherWalletsOnNetwork == 0 { return .noOtherWallet }
            if holding.transferable <= 0 { return .nothingTransferable }
            return nil
        }()
        let sendReason: UnavailableReason? = {
            if !networkIsLive { return .networkNotLive(holding.network) }
            if holding.transferable <= 0 { return .nothingTransferable }
            return nil
        }()

        switch readiness {
        case .ready:
            return PortfolioActionPlan(primary: Entry(action: .swap, unavailableReason: nil),
                                       secondary: [Entry(action: .send, unavailableReason: sendReason),
                                                   Entry(action: .move, unavailableReason: moveReason)])
        case .notTradable:
            return PortfolioActionPlan(primary: Entry(action: .send, unavailableReason: sendReason),
                                       secondary: [Entry(action: .move, unavailableReason: moveReason),
                                                   Entry(action: .swap, unavailableReason: .notTradable)])
        case .noRoute, .test:
            return PortfolioActionPlan(primary: Entry(action: .send, unavailableReason: sendReason),
                                       secondary: [Entry(action: .receiveOnSora2, unavailableReason: nil),
                                                   Entry(action: .move, unavailableReason: moveReason)])
        }
    }
}
