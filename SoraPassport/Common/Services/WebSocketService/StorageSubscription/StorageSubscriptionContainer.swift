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
import RobinHood
import SSFUtils
import SSFStorageQueryKit

final class StorageSubscriptionContainer: WebSocketSubscribing {
    let children: [StorageChildSubscribing]
    let engine: JSONRPCEngine
    let logger: LoggerProtocol

    private var subscriptionId: UInt16?

    init(
        engine: JSONRPCEngine,
        children: [StorageChildSubscribing],
        logger: LoggerProtocol
    ) {
        self.children = children
        self.engine = engine
        self.logger = logger

        subscribe()
    }

    deinit {
        unsubscribe()
    }

    private func subscribe() {
        do {
            let storageKeys = children.map { $0.remoteStorageKey.toHex(includePrefix: true) }

            let updateClosure: (StorageSubscriptionUpdate) -> Void = { [weak self] update in
                self?.handleUpdate(update.params.result)
            }

            let failureClosure: (Error, Bool) -> Void = { [weak self] error, unsubscribed in
                self?.logger.error("Did receive subscription error: \(error) \(unsubscribed)")
            }

            subscriptionId = try engine.subscribe(
                RPCMethod.storageSubscribe,
                params: [storageKeys],
                updateClosure: updateClosure,
                failureClosure: failureClosure
            )
        } catch {
            logger.error("Can't subscribe to storage: \(error)")
        }
    }

    private func unsubscribe() {
        if let identifier = subscriptionId {
            engine.cancelForIdentifier(identifier)
        }
    }

    private func handleUpdate(_ update: StorageUpdate) {
        let updateData = StorageUpdateData(update: update)

        for change in updateData.changes {
            let childrenToNotify = children.filter {
                $0.remoteStorageKey == change.key
            }

            childrenToNotify.forEach {
                $0.processUpdate(change.value, blockHash: updateData.blockHash)
            }
        }
    }
}
