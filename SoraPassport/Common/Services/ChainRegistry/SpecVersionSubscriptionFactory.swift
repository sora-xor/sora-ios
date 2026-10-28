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
