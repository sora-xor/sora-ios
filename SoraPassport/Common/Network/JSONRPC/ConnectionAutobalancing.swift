// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation

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
        ChainNodeModel(url: URL(string: "wss://ws.mof.sora.org")!, name: "SORA Ministry of Finance", apikey: nil),
        ChainNodeModel(url: URL(string: "wss://mof2.sora.org")!, name: "SORA Ministry of Finance 2", apikey: nil),
    ]

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
            guard ["ws", "wss"].contains($0.url.scheme?.lowercased() ?? ""),
                  $0.url.host?.isEmpty == false else { return false }
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

    mutating func connected() {
        failedURLs.removeAll()
        hasPresentedUnavailable = false
    }
}
