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
import SSFModels
import SSFStorageQueryKit

protocol SpecVersionSubscriptionProtocol: AnyObject {
    func subscribe()
    func unsubscribe()
}

final class SpecVersionSubscription {
    let chainId: ChainModel.Id
    let runtimeSyncService: RuntimeSyncServiceProtocol
    let connection: JSONRPCEngine
    let logger: LoggerProtocol?

    private(set) var subscriptionId: UInt16?

    init(
        chainId: ChainModel.Id,
        runtimeSyncService: RuntimeSyncServiceProtocol,
        connection: JSONRPCEngine,
        logger: LoggerProtocol? = nil
    ) {
        self.chainId = chainId
        self.runtimeSyncService = runtimeSyncService
        self.connection = connection
        self.logger = logger
    }
}

extension SpecVersionSubscription: SpecVersionSubscriptionProtocol {
    func subscribe() {
        do {
            let updateClosure: (RuntimeVersionUpdate) -> Void = { [weak self] update in
                guard let strongSelf = self else {
                    return
                }

                let runtimeVersion = update.params.result
                strongSelf.logger?.debug("For chain: \(strongSelf.chainId)")
                strongSelf.logger?.debug("Did receive spec version: \(runtimeVersion.specVersion)")
                strongSelf.logger?.debug("Did receive tx version: \(runtimeVersion.transactionVersion)")

                strongSelf.runtimeSyncService.apply(
                    version: runtimeVersion,
                    for: strongSelf.chainId
                )
            }

            let failureClosure: (Error, Bool) -> Void = { [weak self] error, unsubscribed in
                self?.logger?.error("Unexpected failure after subscription: \(error) \(unsubscribed)")
            }

            let params: [String] = []
            subscriptionId = try connection.subscribe(
                RPCMethod.runtimeVersionSubscribe,
                params: params,
                updateClosure: updateClosure,
                failureClosure: failureClosure
            )
        } catch {
            logger?.error("Unexpected chain \(chainId) subscription failure: \(error)")
        }
    }

    func unsubscribe() {
        if let identifier = subscriptionId {
            subscriptionId = nil
            connection.cancelForIdentifier(identifier)
        }
    }
}
