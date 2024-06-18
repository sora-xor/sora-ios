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
