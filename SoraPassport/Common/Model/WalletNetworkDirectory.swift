// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import Foundation

/// The one wallet: networks are a label on a balance or an address, never a
/// mode the whole app switches into. Every place that lists networks (the
/// home's asset rows, the Receive and Send network choices, the Networks
/// screen) takes its names, tags and order from here, so they always agree.
struct WalletNetworkInfo: Equatable {
    let id: NetworkId
    /// "SORA2", "SORA Nexus" or "Taira". Never translated.
    let name: String
    let isTestnet: Bool
    /// The network has live balances, history and transfers in this build. A
    /// mainnet that is not live yet only has an address to copy.
    let isLive: Bool
}

enum WalletNetworkTag: Equatable {
    case main
    case comingSoon
    case testnet

    var title: String {
        switch self {
        case .main:
            return WalletUX.text("Main")
        case .comingSoon:
            return WalletUX.text("Coming soon")
        case .testnet:
            return WalletUX.text("Testnet")
        }
    }
}

/// Which network is the wallet's main one: listed first everywhere, tagged
/// "Main", the first choice for Receive and Send, and the network whose asset
/// rows carry no network label.
///
/// Today that is SORA2. SORA Nexus is expected to become the main network:
/// set `preferred` to `.minamoto` in the release that makes SORA Nexus
/// production live. Until then the policy keeps SORA2, because it never
/// promotes a testnet, a network that is not live in this build, or a network
/// the wallet has no account on (for example a raw-seed SORA2 wallet).
enum MainNetworkPolicy {
    static let preferred: NetworkId = .sora2
}

struct WalletNetworkDirectory {
    static let current = WalletNetworkDirectory(isLive: { networkId in
        switch networkId {
        case .sora2:
            return true
        case .minamoto, .taira:
            return NexusNetworkConfiguration.configuration(for: networkId)?.isLive ?? false
        }
    })

    /// Injected so tests can show the layout after SORA Nexus goes live.
    let isLive: (NetworkId) -> Bool

    func info(_ networkId: NetworkId) -> WalletNetworkInfo {
        switch networkId {
        case .sora2:
            return WalletNetworkInfo(id: .sora2, name: "SORA2", isTestnet: false, isLive: isLive(.sora2))
        case .minamoto:
            return WalletNetworkInfo(id: .minamoto, name: "SORA Nexus", isTestnet: false, isLive: isLive(.minamoto))
        case .taira:
            return WalletNetworkInfo(id: .taira, name: "Taira", isTestnet: true, isLive: isLive(.taira))
        }
    }

    /// The main network of a wallet that has accounts on `walletNetworks`.
    func mainNetwork(
        walletNetworks: Set<NetworkId>,
        preferred: NetworkId = MainNetworkPolicy.preferred
    ) -> NetworkId {
        let candidate = info(preferred)
        guard !candidate.isTestnet, candidate.isLive, walletNetworks.contains(preferred) else {
            return .sora2
        }
        return preferred
    }

    func tag(for networkId: NetworkId, main: NetworkId) -> WalletNetworkTag? {
        if networkId == main {
            return .main
        }
        let network = info(networkId)
        if network.isTestnet {
            return .testnet
        }
        return network.isLive ? nil : .comingSoon
    }

    /// The main network first, then the other live mainnets, then mainnets
    /// that are not live yet, then testnets. Duplicates are dropped.
    func ordered(_ networkIds: [NetworkId], main: NetworkId) -> [NetworkId] {
        var unique: [NetworkId] = []
        for networkId in networkIds where !unique.contains(networkId) {
            unique.append(networkId)
        }
        return unique.sorted { rank($0, main: main) < rank($1, main: main) }
    }

    /// The network label of an asset row: none on the main network, the
    /// network's name on any other.
    func rowLabel(for networkId: NetworkId, main: NetworkId) -> String? {
        networkId == main ? nil : info(networkId).name
    }

    private func rank(_ networkId: NetworkId, main: NetworkId) -> (Int, Int) {
        let network = info(networkId)
        let group: Int
        if networkId == main {
            group = 0
        } else if network.isTestnet {
            group = 3
        } else {
            group = network.isLive ? 1 : 2
        }
        return (group, NetworkId.allCases.firstIndex(of: networkId) ?? NetworkId.allCases.count)
    }
}

/// What the wallet offers for one network when the user taps Receive or Send.
struct WalletNetworkChoice: Equatable {
    let account: NetworkAccount
    let network: WalletNetworkInfo
    let tag: WalletNetworkTag?
    /// The XOR balance as text, or nil when it has not been read.
    let balance: String?
    /// Why this network cannot be used for the action now, or nil.
    let unavailableReason: String?

    var isAvailable: Bool { unavailableReason == nil }
}

enum WalletNetworkAction: Equatable {
    case receive
    case send
}

enum WalletNetworkChoices {
    /// The choices for `action`, main network first. Receive offers every
    /// network the wallet has an address on; a network that is not live yet
    /// still offers its address to copy. Send offers only networks it can
    /// send on now and says why the others cannot.
    static func make(
        action: WalletNetworkAction,
        accounts: [NetworkAccount],
        balances: [NetworkId: String],
        canSend: (NetworkId) -> Bool,
        directory: WalletNetworkDirectory = .current,
        preferred: NetworkId = MainNetworkPolicy.preferred
    ) -> [WalletNetworkChoice] {
        let main = directory.mainNetwork(
            walletNetworks: Set(accounts.map(\.networkId)),
            preferred: preferred
        )
        let order = directory.ordered(accounts.map(\.networkId), main: main)
        return order.compactMap { networkId in
            guard let account = accounts.first(where: { $0.networkId == networkId }) else {
                return nil
            }
            let network = directory.info(networkId)
            return WalletNetworkChoice(
                account: account,
                network: network,
                tag: directory.tag(for: networkId, main: main),
                balance: balances[networkId],
                unavailableReason: unavailableReason(
                    action: action,
                    network: network,
                    canSend: canSend
                )
            )
        }
    }

    /// The Receive or Send flow opens straight on the network when there is
    /// nothing to choose: only one live network can be used. A network that
    /// is not live yet keeps its home row, so its address stays one tap away.
    static func onlyChoice(_ choices: [WalletNetworkChoice]) -> WalletNetworkChoice? {
        let usable = choices.filter { $0.isAvailable && $0.network.isLive }
        return usable.count == 1 ? usable.first : nil
    }

    private static func unavailableReason(
        action: WalletNetworkAction,
        network: WalletNetworkInfo,
        canSend: (NetworkId) -> Bool
    ) -> String? {
        switch action {
        case .receive:
            return nil
        case .send:
            if !network.isLive {
                return WalletUX.format("Sending on %@ starts when the network launches.", network.name)
            }
            return canSend(network.id)
                ? nil
                : WalletUX.format("Sending on %@ is paused right now.", network.name)
        }
    }
}
