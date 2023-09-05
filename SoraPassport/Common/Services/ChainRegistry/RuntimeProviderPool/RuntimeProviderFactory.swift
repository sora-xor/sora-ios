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

protocol RuntimeProviderFactoryProtocol {
    func createRuntimeProvider(for chain: ChainModel) -> RuntimeProviderProtocol
    func createHotRuntimeProvider(
        for chain: ChainModel,
        runtimeItem: RuntimeMetadataItem,
        commonTypes: Data
    ) -> RuntimeProviderProtocol
}

final class RuntimeProviderFactory {
    let fileOperationFactory: RuntimeFilesOperationFactoryProtocol
    let repository: AnyDataProviderRepository<RuntimeMetadataItem>
    let dataOperationFactory: DataOperationFactoryProtocol
    let eventCenter: EventCenterProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol?

    init(
        fileOperationFactory: RuntimeFilesOperationFactoryProtocol,
        repository: AnyDataProviderRepository<RuntimeMetadataItem>,
        dataOperationFactory: DataOperationFactoryProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol? = nil
    ) {
        self.fileOperationFactory = fileOperationFactory
        self.repository = repository
        self.dataOperationFactory = dataOperationFactory
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

extension RuntimeProviderFactory: RuntimeProviderFactoryProtocol {
    func createRuntimeProvider(for chain: ChainModel) -> RuntimeProviderProtocol {
        let snapshotOperationFactory = RuntimeSnapshotFactory(
            chainId: chain.chainId,
            filesOperationFactory: fileOperationFactory,
            repository: repository
        )

        return RuntimeProvider(
            chainModel: chain,
            snapshotOperationFactory: snapshotOperationFactory,
            snapshotHotOperationFactory: nil,
            eventCenter: eventCenter,
            operationQueue: operationQueue,
            logger: logger,
            repository: repository
        )
    }

    func createHotRuntimeProvider(
        for chain: ChainModel,
        runtimeItem: RuntimeMetadataItem,
        commonTypes: Data
    ) -> RuntimeProviderProtocol {
        let snapshotOperationFactory = RuntimeSnapshotFactory(
            chainId: chain.chainId,
            filesOperationFactory: fileOperationFactory,
            repository: repository
        )

        let snapshotHotOperationFactory = RuntimeHotBootSnapshotFactory(
            chainId: chain.chainId,
            runtimeItem: runtimeItem,
            commonTypes: commonTypes,
            filesOperationFactory: fileOperationFactory
        )

        return RuntimeProvider(
            chainModel: chain,
            snapshotOperationFactory: snapshotOperationFactory,
            snapshotHotOperationFactory: snapshotHotOperationFactory,
            eventCenter: eventCenter,
            operationQueue: operationQueue,
            logger: logger,
            repository: repository
        )
    }
}
