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

final class LocalTransactionStorage: LocalTransactionStorageProtocol {
    
    static let shared = LocalTransactionStorage()
    var transactions: [String: [Transaction]] = [:]
    var currentAccount = SelectedWalletSettings.shared
    
    init() {
        EventCenter.shared.add(observer: self)
    }
}

extension LocalTransactionStorage: EventVisitorProtocol {
    func processNewTransactionCreated(event: NewTransactionCreatedEvent) {
        guard let address = currentAccount.currentAccount?.address else { return }
        var transactions = transactions[address] ?? []
        transactions.append(event.item)
        self.transactions[address] = transactions
    }
    
    func processNewTransaction(event: WalletNewTransactionInserted) {
        if let transaction = event.items.first,
           let address = currentAccount.currentAccount?.address,
           var transactions = transactions[address],
           let foundedTransactionIndex = transactions.firstIndex(where: { $0.base.txHash == transaction.extrinsicHash.toHex(includePrefix: true) }) {
            
            transactions[foundedTransactionIndex].base.status = transaction.processingResult.isSuccess ? .success : .failed
            self.transactions[address] = transactions
        }
    }
}
