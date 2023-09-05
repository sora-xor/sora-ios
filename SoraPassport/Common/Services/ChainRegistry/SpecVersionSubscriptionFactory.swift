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
import FearlessUtils

/**
 *  Protocol is designed to provide methods to create a subscription
 *  for runtime version in a particular chain
 */

protocol SpecVersionSubscriptionFactoryProtocol: AnyObject {
    /**
     *  Creates a subsription for runtime version in particular chain.
     *
     *  - Parameters:
     *      - chainId: Identifier of the chain for which subscription should be created;
     *      - connection: Connection to send request to the chain and receive updates.
     *
     *  - Returns: `SpecVersionSubscriptionProtocol` conforming subscription.
     */
    func createSubscription(
        for chainId: ChainModel.Id,
        connection: JSONRPCEngine
    ) -> SpecVersionSubscriptionProtocol
}

/**
 *  Class is designed to implement `SpecVersionSubscriptionFactoryProtocol` in a way to create
 *  `SpecVersionSubscription` subscription.
 */

final class SpecVersionSubscriptionFactory {
    let runtimeSyncService: RuntimeSyncServiceProtocol
    let logger: LoggerProtocol?

    /**
     *  Creates new subscription factory
     *
     *  - Paramaters:
     *      - runtimeSyncService: a sync service that is shared between
     *      subscriptions created by the factory;
     *      - logger: logger to provide info for debugging.
     */
    init(runtimeSyncService: RuntimeSyncServiceProtocol, logger: LoggerProtocol? = nil) {
        self.runtimeSyncService = runtimeSyncService
        self.logger = logger
    }
}

extension SpecVersionSubscriptionFactory: SpecVersionSubscriptionFactoryProtocol {
    func createSubscription(
        for chainId: ChainModel.Id,
        connection: JSONRPCEngine
    ) -> SpecVersionSubscriptionProtocol {
        SpecVersionSubscription(
            chainId: chainId,
            runtimeSyncService: runtimeSyncService,
            connection: connection
        )
    }
}
