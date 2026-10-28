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
import RobinHood
import SSFUtils
import SSFStorageQueryKitFixed

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

            let failureClosure: (Error, Bool) -> Void = { [weak self] _, _ in
                self?.logger.error("Storage subscription failed")
            }

            subscriptionId = try engine.subscribe(
                RPCMethod.storageSubscribe,
                params: [storageKeys],
                updateClosure: updateClosure,
                failureClosure: failureClosure
            )
        } catch {
            logger.error("Storage subscription setup failed")
        }
    }

    private func unsubscribe() {
        if let identifier = subscriptionId {
            engine.cancelForIdentifier(identifier)
        }
    }

    private func handleUpdate(_ update: StorageUpdate) {
        let updateData = StorageUpdateData(update: update)

        for rawChange in update.changes ?? [] {
            guard rawChange.count == 2,
                  let rawKey = rawChange[0],
                  let key = try? Data(hexStringSSF: rawKey) else { continue }
            let value: Data?
            if let rawValue = rawChange[1] {
                guard let decoded = try? Data(hexStringSSF: rawValue) else { continue }
                value = decoded
            } else { value = nil }
            children.filter { $0.remoteStorageKey == key }.forEach {
                $0.processUpdate(value, blockHash: updateData.blockHash)
            }
        }
    }
}
