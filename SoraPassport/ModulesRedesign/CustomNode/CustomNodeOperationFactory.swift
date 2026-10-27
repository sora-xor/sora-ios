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
import SSFUtils
import RobinHood

protocol CustomNodeOperationFactoryProtocol {
    func createGetGenesisBlockOperation() -> BaseOperation<String>
}

final class CustomNodeOperationFactory {

    private let url: URL

    init(url: URL) {
        self.url = url
    }
}

extension CustomNodeOperationFactory: CustomNodeOperationFactoryProtocol {
    func createGetGenesisBlockOperation() -> BaseOperation<String> {
        let engine = WebSocketEngine(connectionName: nil, url: url)

        var currentBlock = 0
        let param = Data(Data(bytes: &currentBlock, count: MemoryLayout<UInt32>.size).reversed())
            .toHex(includePrefix: true)

        return JSONRPCListOperation<String>(engine: engine,
                                            method: RPCMethod.getBlockHash,
                                            parameters: [param])
    }
}

/// Whether a SORA mainnet node can carry the app's signing requests: one
/// HTTPS JSON-RPC POST at the node's own host, port and path, answered as
/// JSON by SORA mainnet. Checked before a custom node is saved.
enum Sora2NodeSigningRoute: Equatable {
    case available
    /// No HTTPS JSON-RPC answer at the node's address (a `ws://` address, a
    /// WebSocket-only proxy, no TLS listener, or an answer that is not
    /// JSON-RPC).
    case missing
    /// It answers, but it is not SORA mainnet.
    case anotherNetwork

    static var missingRouteMessage: String {
        WalletUX.text(
            "This node answers on its WebSocket address but not over HTTPS at the same address. The app needs both: balances use the WebSocket, and fee estimates and sends use HTTPS. With this node balances would load and every send would fail, so it was not saved. Use a node that serves wss:// and https:// at the same address."
        )
    }

    static var missingRouteFieldText: String {
        WalletUX.text("This node does not answer over HTTPS, so it can't send transactions")
    }

    static func probe(
        nodeURL: URL,
        session: URLSession? = nil
    ) async -> Sora2NodeSigningRoute {
        guard (try? Sora2BoundedHTTPJSONRPCEngine.httpEndpoint(for: nodeURL)) != nil else {
            return .missing
        }
        let client = PolkamarktRPCClient(
            engine: Sora2BoundedHTTPJSONRPCEngine(nodeURL: nodeURL, session: session)
        )
        do {
            _ = try await client.reviewedGenesisHash()
            return .available
        } catch PolkamarktRuntimeError.wrongChain {
            return .anotherNetwork
        } catch {
            return .missing
        }
    }
}
