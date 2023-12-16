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

protocol ConnectionPoolProtocol {
    func setupConnection(for chain: ChainModel) throws -> ChainConnection
    func setupConnection(for chain: ChainModel, ignoredUrl: URL?) throws -> ChainConnection
    func getConnection(for chainId: ChainModel.Id) -> ChainConnection?
    func setDelegate(_ delegate: ConnectionPoolDelegate)
}

protocol ConnectionPoolDelegate: AnyObject {
    func connectionNeedsReconnect(url: URL, attempt: Int)
    func connectionUpdated(url: URL)
}

class ConnectionPool {
    let connectionFactory: ConnectionFactoryProtocol
    weak var delegate: ConnectionPoolDelegate?

    private var mutex = NSLock()

    private(set) var connectionsByChainIds: [ChainModel.Id: WeakWrapper] = [:]

    private func clearUnusedConnections() {
        connectionsByChainIds = connectionsByChainIds.filter { $0.value.target != nil }
    }

    init(connectionFactory: ConnectionFactoryProtocol) {
        self.connectionFactory = connectionFactory
    }
}

extension ConnectionPool: ConnectionPoolProtocol {
    func setDelegate(_ delegate: ConnectionPoolDelegate) {
        self.delegate = delegate
    }

    func setupConnection(for chain: ChainModel) throws -> ChainConnection {
        try setupConnection(for: chain, ignoredUrl: nil)
    }

    func setupConnection(for chain: ChainModel, ignoredUrl: URL?) throws -> ChainConnection {
        let node = chain.selectedNode ?? chain.nodes.first

        guard let url = node?.url else {
            throw JSONRPCEngineError.unknownError
        }

        mutex.lock()

        defer {
            mutex.unlock()
        }

        clearUnusedConnections()

        if let connection = connectionsByChainIds[chain.chainId]?.target as? ChainConnection {
            if connection.url == url {
                return connection
            } else {
                connectionsByChainIds[chain.chainId] = nil
            }
        }

        let connection = connectionFactory.createConnection(for: url, delegate: self)
        let wrapper = WeakWrapper(target: connection)
        Logger.shared.info("Connected node: \(url)")
        connectionsByChainIds[chain.chainId] = wrapper

        return connection
    }

    func getConnection(for chainId: ChainModel.Id) -> ChainConnection? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return connectionsByChainIds[chainId]?.target as? ChainConnection
    }
}

extension ConnectionPool: WebSocketEngineDelegate {
    func webSocketDidChangeState(engine: WebSocketEngine, from _: WebSocketEngine.State, to newState: WebSocketEngine.State) {
        guard let previousUrl = engine.url else {
            return
        }

        switch newState {
        case let .connecting(attempt):
            if attempt > 1 {
                // temporary disable autobalance , maybe this causing crashes
                delegate?.connectionNeedsReconnect(url: previousUrl, attempt: attempt)
            }
        case .connected:
            delegate?.connectionUpdated(url: previousUrl)

        case .notConnected, .notReachable:
            break
        case .waitingReconnection(attempt: let attempt):
            break
        }
    }
}
