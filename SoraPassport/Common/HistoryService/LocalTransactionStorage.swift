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
