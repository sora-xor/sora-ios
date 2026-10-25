// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import Foundation

/// Networks the portfolio can show: the wallet network model's `NetworkId`. Names, tags, order and
/// testnet status come from `WalletNetworkDirectory`, so the portfolio agrees with every other
/// network list in the app.
enum PortfolioNetwork: String, CaseIterable, Hashable, Codable {
    case sora2
    case minamoto
    case taira

    init(_ networkId: NetworkId) {
        switch networkId {
        case .sora2: self = .sora2
        case .minamoto: self = .minamoto
        case .taira: self = .taira
        }
    }

    var networkId: NetworkId {
        switch self {
        case .sora2: return .sora2
        case .minamoto: return .minamoto
        case .taira: return .taira
        }
    }

    /// Testnet value has no monetary value and is never counted.
    var isTestnet: Bool { WalletNetworkDirectory.current.info(networkId).isTestnet }

    /// Polkaswap runs on SORA2 only.
    var hostsPolkaswap: Bool { self == .sora2 }

    /// `networks` in the app's network order: the main network, live mainnets, mainnets not live
    /// yet, then testnets.
    static func ordered(_ networks: [PortfolioNetwork],
                        directory: WalletNetworkDirectory = .current) -> [PortfolioNetwork] {
        let main = directory.mainNetwork(walletNetworks: Set(allCases.map(\.networkId)))
        return directory.ordered(networks.map(\.networkId), main: main).map { PortfolioNetwork($0) }
    }

    /// Position in that order, for sorting.
    func rank(in directory: WalletNetworkDirectory = .current) -> Int {
        Self.ordered(Self.allCases, directory: directory).firstIndex(of: self) ?? Self.allCases.count
    }
}

/// A token as the portfolio groups it. Native XOR on every network shares the
/// SORA2 XOR identifier so the Tokens lens shows it as one token.
struct PortfolioToken: Hashable {
    let id: String
    let symbol: String
    let name: String
    /// Data URL or SVG source as the asset list provides it.
    let icon: String?
    /// USD price of this asset. `nil` means the asset is unpriced; a group never lends a price.
    let priceUSD: Decimal?
    /// 24 h price change in percent (3.4 means +3.4 %), as the app's price service reports it.
    let change24h: Decimal?
    /// The asset trades on Polkaswap.
    let isSwappable: Bool
}

/// One asset balance of one wallet on one network.
struct PortfolioHolding: Hashable {
    let walletId: String
    let network: PortfolioNetwork
    let token: PortfolioToken
    /// Total balance as the app defines it (free plus reserved).
    let amount: Decimal
    /// The part that can move now.
    let transferable: Decimal
    /// Hidden by the wallet's own asset visibility settings.
    let isHidden: Bool

    var id: String { "\(walletId)|\(network.rawValue)|\(token.id)" }

    /// Reserved, frozen or bonded: everything that is counted but cannot move now.
    var locked: Decimal { max(0, amount - transferable) }
}

enum PortfolioFreshnessState: Int, Comparable, Hashable {
    case live
    case saved
    case partial
    case offline

    static func < (lhs: PortfolioFreshnessState, rhs: PortfolioFreshnessState) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// How current a wallet's numbers are.
struct PortfolioFreshness: Hashable {
    let state: PortfolioFreshnessState
    /// Time of the last complete read (`nil` when nothing was ever read).
    let updatedAt: Date?
    /// Counted networks that could not be read (PARTIAL).
    let unreachable: [PortfolioNetwork]

    static let offline = PortfolioFreshness(state: .offline, updatedAt: nil, unreachable: [])

    static func live(_ date: Date) -> PortfolioFreshness {
        PortfolioFreshness(state: .live, updatedAt: date, unreachable: [])
    }

    static func saved(_ date: Date) -> PortfolioFreshness {
        PortfolioFreshness(state: .saved, updatedAt: date, unreachable: [])
    }

    static func partial(_ date: Date?, unreachable: [PortfolioNetwork]) -> PortfolioFreshness {
        PortfolioFreshness(state: .partial, updatedAt: date, unreachable: unreachable)
    }
}

struct PortfolioWallet: Hashable {
    /// The wallet's SORA2 address, the app's stable local wallet identifier.
    let id: String
    let name: String
    let isSelected: Bool
    let order: Int
    /// Networks on which this wallet has an account that this build shows.
    let networks: [PortfolioNetwork]
    /// Receive addresses by network (public data only).
    let addresses: [PortfolioNetwork: String]
    let freshness: PortfolioFreshness
}

/// Everything the dashboard shows, as one immutable value.
struct PortfolioSnapshot: Equatable {
    let wallets: [PortfolioWallet]
    let holdings: [PortfolioHolding]
    /// Networks this build shows, in display order.
    let networks: [PortfolioNetwork]
    /// Polkaswap swaps are available in this build.
    let swapsAvailable: Bool
    /// The Polkaswap disclaimer the app requires has been accepted on this device.
    let swapDisclaimerAccepted: Bool
    /// Networks that admit network I/O in this version (Minamoto is not live yet).
    let liveNetworks: Set<PortfolioNetwork>
    /// The first read of the wallets is still running: neither the empty state nor OFFLINE applies yet.
    var isLoading = false

    /// The app's network directory with this snapshot's live networks (the debug sample shows every
    /// network as live).
    var directory: WalletNetworkDirectory {
        let live = liveNetworks
        return WalletNetworkDirectory(isLive: { live.contains(PortfolioNetwork($0)) })
    }

    /// The main network of these wallets (SORA2 today), listed first and tagged Main.
    var mainNetwork: PortfolioNetwork {
        PortfolioNetwork(directory.mainNetwork(walletNetworks: Set(networks.map(\.networkId))))
    }

    /// Main, Coming soon or Testnet next to a network's name.
    func tag(for network: PortfolioNetwork) -> WalletNetworkTag? {
        directory.tag(for: network.networkId, main: mainNetwork.networkId)
    }

    static let empty = PortfolioSnapshot(wallets: [], holdings: [], networks: [.sora2],
                                         swapsAvailable: true, swapDisclaimerAccepted: false,
                                         liveNetworks: [.sora2])

    func wallet(_ id: String) -> PortfolioWallet? { wallets.first { $0.id == id } }

    var selectedWallet: PortfolioWallet? { wallets.first { $0.isSelected } }
}

enum PortfolioScope: Hashable {
    case allWallets
    case wallet(String)

    var storageKey: String {
        switch self {
        case .allWallets: return "all"
        case let .wallet(id): return "wallet:" + id
        }
    }

    init?(storageKey: String) {
        if storageKey == "all" {
            self = .allWallets
        } else if storageKey.hasPrefix("wallet:") {
            let id = String(storageKey.dropFirst("wallet:".count))
            guard !id.isEmpty else { return nil }
            self = .wallet(id)
        } else {
            return nil
        }
    }

    func contains(walletId: String) -> Bool {
        switch self {
        case .allWallets: return true
        case let .wallet(id): return id == walletId
        }
    }
}

enum PortfolioLens: String, CaseIterable, Hashable {
    case tokens
    case networks
    case wallets
}
