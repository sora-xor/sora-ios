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
