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

protocol LocalTransactionStorageProtocol {
    var transactions: [String: [Transaction]] { get set }
}

/// The transactions sent in this run of the app, by account, until the
/// indexer lists them. Events arrive on the event center's queue and the
/// history is read on others, so every access goes through one lock.
final class LocalTransactionStorage: LocalTransactionStorageProtocol {
    
    static let shared = LocalTransactionStorage()
    private let lock = NSLock()
    private var stored: [String: [Transaction]] = [:]
    var transactions: [String: [Transaction]] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return stored
        }
        set {
            lock.lock()
            stored = newValue
            lock.unlock()
        }
    }
    init(eventCenter: EventCenterProtocol = EventCenter.shared) {
        eventCenter.add(observer: self)
    }

    private func update(_ address: String, _ change: (inout [Transaction]) -> Void) {
        lock.lock()
        var list = stored[address] ?? []
        change(&list)
        stored[address] = list
        lock.unlock()
    }
}

extension LocalTransactionStorage: EventVisitorProtocol {
    func processNewTransactionCreated(event: NewTransactionCreatedEvent) {
        guard let address = event.accountAddress else { return }
        update(address) { $0.append(event.item) }
    }
    
    func processNewTransaction(event: WalletNewTransactionInserted) {
        guard !event.items.isEmpty else { return }
        var statuses: [String: TransactionBase.Status] = [:]
        for transaction in event.items {
            statuses[transaction.extrinsicHash.toHex(includePrefix: true)] =
                transaction.processingResult.isSuccess ? .success : .failed
        }
        // Confirmation may arrive after the user switched wallets. The signed
        // transaction hash identifies the stored row independently of selection.
        lock.lock()
        defer { lock.unlock() }
        for address in Array(stored.keys) {
            guard var list = stored[address] else { continue }
            for index in list.indices {
                if let status = statuses[list[index].base.txHash] {
                    list[index].base.status = status
                }
            }
            stored[address] = list
        }
    }
}
