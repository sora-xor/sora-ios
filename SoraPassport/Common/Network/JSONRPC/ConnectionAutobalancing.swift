// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import Darwin

struct ConnectionRank {
    let url: URL
    let rank: Int32
}

protocol ConnectionAutobalancing {
    var ranking: [ConnectionRank] { get }
    func set(ranking: [ConnectionRank])
    func disconnectIfNeeded()
    var url: URL? { get set }
}

extension ConnectionRank {
    init(chainNode: ChainNodeModel) {
        url = chainNode.url
        rank = 0
    }
}

/// Node choice is connection state, not a change to the user's saved preference.
/// Only the known SORA mainnet identity receives the bundled mainnet fallbacks.
enum SoraNodeConnectionPolicy {
    static let mainnetGenesis = "0x7e4e32d0feafd4f9c9414b0be86373f9a1efa904809b683453a9af6856d38ad5"
    static let bundledMainnetNodes = [
        ChainNodeModel(url: URL(string: "wss://mof2.sora.org")!, name: "SORA Ministry of Finance 2", apikey: nil),
    ]

    /// Excludes the reported compromised host even when cached or supplied remotely.
    static func isAllowedEndpoint(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              ["ws", "wss"].contains(components.scheme?.lowercased() ?? ""),
              let originalHost = components.host, !originalHost.isEmpty,
              components.user == nil, components.password == nil, components.fragment == nil,
              !isCompromisedEndpoint(url) else { return false }
        if let port = components.port, !(1...65535).contains(port) { return false }
        // URLComponents represents an explicitly empty port as nil. Reject it.
        let authority = url.absoluteString.components(separatedBy: "://").dropFirst().joined(separator: "://")
            .prefix { $0 != "/" && $0 != "?" && $0 != "#" }
        guard !authority.hasSuffix(":") else { return false }
        if originalHost.hasPrefix("["), originalHost.hasSuffix("]") {
            let host = String(originalHost.dropFirst().dropLast())
            var address = in6_addr()
            return host.withCString { inet_pton(AF_INET6, $0, &address) } == 1
        }
        let host = originalHost.lowercased()
        if host.allSatisfy({ $0.isNumber || $0 == "." }) {
            var address = in_addr()
            return host.withCString { inet_pton(AF_INET, $0, &address) } == 1
        }
        let domain = host.hasSuffix(".") ? String(host.dropLast()) : host
        guard domain.utf8.count <= 253 else { return false }
        return domain.split(separator: ".", omittingEmptySubsequences: false).allSatisfy { label in
            !label.isEmpty && label.utf8.count <= 63 && label.first != "-" && label.last != "-" &&
            label.utf8.allSatisfy { (97...122).contains($0) || (48...57).contains($0) || $0 == 45 }
        }
    }

    static func isCompromisedEndpoint(_ url: URL) -> Bool {
        let host = url.host?.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return ["ws.mof.sora.org", "mof.sora.org", "mof3.sora.org", "207.254.29.218"].contains(host ?? "")
    }

    static func isMainnet(chainId: String, addressPrefix: UInt16) -> Bool {
        chainId.lowercased() == mainnetGenesis && addressPrefix == 69
    }

    static func candidates(for chain: ChainModel) -> [ChainNodeModel] {
        let bundled = isMainnet(chainId: chain.chainId, addressPrefix: chain.addressPrefix)
            ? bundledMainnetNodes : []
        let defaults = chain.nodes.sorted { $0.url.absoluteString < $1.url.absoluteString }
        let custom = (chain.customNodes ?? []).sorted { $0.url.absoluteString < $1.url.absoluteString }
        var seen: Set<URL> = []
        return ([chain.selectedNode].compactMap { $0 } + bundled + defaults + custom).filter {
            guard isAllowedEndpoint($0.url) else { return false }
            return seen.insert($0.url).inserted
        }
    }
}

struct NodeConnectionFailover {
    struct Decision {
        let nextNode: ChainNodeModel?
        let shouldPresentUnavailable: Bool
    }

    private var failedURLs: Set<URL> = []
    private var hasPresentedUnavailable = false

    mutating func failed(url: URL, candidates: [ChainNodeModel]) -> Decision {
        guard let current = candidates.firstIndex(where: { $0.url == url }) else {
            return Decision(nextNode: nil, shouldPresentUnavailable: false)
        }
        failedURLs.insert(url)
        let ordered = Array(candidates.dropFirst(current + 1)) + Array(candidates.prefix(current + 1))
        if let next = ordered.first(where: { !failedURLs.contains($0.url) }) {
            return Decision(nextNode: next, shouldPresentUnavailable: false)
        }
        let shouldPresent = !hasPresentedUnavailable
        hasPresentedUnavailable = true
        failedURLs.removeAll()
        return Decision(nextNode: ordered.first(where: { $0.url != url }),
                        shouldPresentUnavailable: shouldPresent)
    }

    /// A node is connected. Returns whether the "no node can be reached"
    /// status was presented since the last connection: it is no longer true
    /// and has to be taken down.
    @discardableResult
    mutating func connected() -> Bool {
        let wasUnavailablePresented = hasPresentedUnavailable
        failedURLs.removeAll()
        hasPresentedUnavailable = false
        return wasUnavailablePresented
    }
}
