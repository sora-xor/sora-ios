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
    private var preferredURLs: [ChainModel.Id: URL] = [:]

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
        let node = SoraNodeConnectionPolicy.candidates(for: chain).first { $0.url != ignoredUrl }

        guard let url = node?.url else {
            throw JSONRPCEngineError.unknownError
        }

        mutex.lock()

        defer {
            mutex.unlock()
        }

        clearUnusedConnections()

        if let connection = connectionsByChainIds[chain.chainId]?.target as? ChainConnection {
            if preferredURLs[chain.chainId] == url {
                return connection
            } else {
                // Runtime metadata and subscriptions retain this engine. A
                // same-chain user choice must update every holder's URL too.
                preferredURLs[chain.chainId] = url
                connection.disconnectIfNeeded()
                connection.reconnect(url: url)
                connection.connectIfNeeded()
                return connection
            }
        }

        preferredURLs[chain.chainId] = url
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
            guard case let .connecting(currentAttempt) = engine.state, currentAttempt == attempt else { return }
            if attempt > 1 {
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
