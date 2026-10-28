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

enum RuntimeRegistryServiceError: Error {
    case missingBaseTypes
    case missingNetworkTypes
    case brokenMetadata
    case noNeedToUpdateTypes
    case unexpectedCoderFetchingFailure
    case timedOut
}

final class RuntimeRegistryService {
    private(set) var chain: Chain
    private(set) var isActive: Bool = false

    private let mutex = NSLock()

    let chainRegistry: ChainRegistryProtocol

    init(chain: Chain, chainRegistry: ChainRegistryProtocol) {
        self.chain = chain
        self.chainRegistry = chainRegistry
    }

    private var chainRuntimeProvider: RuntimeProviderProtocol? {
        chainRegistry.getRuntimeProvider(for: chain.genesisHash())
    }
}

extension RuntimeRegistryService: RuntimeRegistryServiceProtocol {
    func update(to chain: Chain, forced: Bool = false) {
        mutex.lock()

        self.chain = chain

        mutex.unlock()
    }

    func setup() {
        mutex.lock()

        isActive = true

        mutex.unlock()
    }

    func throttle() {
        mutex.lock()

        isActive = false

        mutex.unlock()
    }
}

extension RuntimeRegistryService: RuntimeCodingServiceProtocol {
    var snapshot: RuntimeSnapshot? {
        chainRuntimeProvider?.snapshot
    }

    func fetchCoderFactoryOperation(
        with timeout: TimeInterval,
        closure: RuntimeMetadataClosure?
    ) -> BaseOperation<RuntimeCoderFactoryProtocol> {
        chainRuntimeProvider?.fetchCoderFactoryOperation(with: timeout, closure: closure) ??
            BaseOperation.createWithError(RuntimeProviderError.providerUnavailable)
    }

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return chainRuntimeProvider?.fetchCoderFactoryOperation() ??
            BaseOperation.createWithError(RuntimeProviderError.providerUnavailable)
    }
}
