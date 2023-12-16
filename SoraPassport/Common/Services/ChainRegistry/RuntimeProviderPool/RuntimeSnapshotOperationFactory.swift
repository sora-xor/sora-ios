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
import RobinHood

protocol RuntimeSnapshotFactoryProtocol {
    func createRuntimeSnapshotWrapper(
        for typesUsage: ChainModel.TypesUsage,
        dataHasher: StorageHasher
    ) -> CompoundOperationWrapper<RuntimeSnapshot?>
}

final class RuntimeSnapshotFactory {
    let chainId: ChainModel.Id
    let filesOperationFactory: RuntimeFilesOperationFactoryProtocol
    let repository: AnyDataProviderRepository<RuntimeMetadataItem>

    init(
        chainId: ChainModel.Id,
        filesOperationFactory: RuntimeFilesOperationFactoryProtocol,
        repository: AnyDataProviderRepository<RuntimeMetadataItem>
    ) {
        self.chainId = chainId
        self.filesOperationFactory = filesOperationFactory
        self.repository = repository
    }

    private func createWrapperForCommonAndChainTypes(
        _ dataHasher: StorageHasher
    ) -> CompoundOperationWrapper<RuntimeSnapshot?> {
        let baseTypesFetchOperation = filesOperationFactory.fetchCommonTypesOperation()
        let chainTypesFetchOperation = filesOperationFactory.fetchChainTypesOperation(for: chainId)

        let runtimeMetadataOperation = repository.fetchOperation(
            by: chainId,
            options: RepositoryFetchOptions()
        )

        let snapshotOperation = ClosureOperation<RuntimeSnapshot?> {
            let commonTypes = try baseTypesFetchOperation.targetOperation.extractNoCancellableResultData()
            let chainTypes = try chainTypesFetchOperation.targetOperation.extractNoCancellableResultData()

            guard let runtimeMetadataItem = try runtimeMetadataOperation
                .extractNoCancellableResultData() else {
                return nil
            }

            let decoder = try ScaleDecoder(data: runtimeMetadataItem.metadata)
            let runtimeMetadata = try RuntimeMetadata(scaleDecoder: decoder)

            guard let commonTypes = commonTypes, let chainTypes = chainTypes else {
                return nil
            }

            let catalog = try TypeRegistryCatalog.createFromTypeDefinition(
                commonTypes,
                versioningData: chainTypes,
                runtimeMetadata: runtimeMetadata,
                usedRuntimePaths: [:]
            )

            return RuntimeSnapshot(
                localCommonHash: try dataHasher.hash(data: commonTypes).toHex(),
                localChainHash: try dataHasher.hash(data: chainTypes).toHex(),
                typeRegistryCatalog: catalog,
                specVersion: runtimeMetadataItem.version,
                txVersion: runtimeMetadataItem.txVersion,
                metadata: runtimeMetadata
            )
        }

        let dependencies = baseTypesFetchOperation.allOperations + chainTypesFetchOperation.allOperations +
            [runtimeMetadataOperation]

        dependencies.forEach { snapshotOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: snapshotOperation, dependencies: dependencies)
    }

    private func createWrapperForCommonTypes(
        _ dataHasher: StorageHasher
    ) -> CompoundOperationWrapper<RuntimeSnapshot?> {
        let commonTypesFetchOperation = filesOperationFactory.fetchCommonTypesOperation()

        let runtimeMetadataOperation = repository.fetchOperation(
            by: chainId,
            options: RepositoryFetchOptions()
        )

        let snapshotOperation = ClosureOperation<RuntimeSnapshot?> {
            let commonTypes = try commonTypesFetchOperation.targetOperation.extractNoCancellableResultData()

            guard let runtimeMetadataItem = try runtimeMetadataOperation
                .extractNoCancellableResultData() else {
                return nil
            }

            let decoder = try ScaleDecoder(data: runtimeMetadataItem.metadata)
            let runtimeMetadata = try RuntimeMetadata(scaleDecoder: decoder)

            guard let commonTypes = commonTypes else {
                return nil
            }

            let catalog = try TypeRegistryCatalog.createFromTypeDefinition(
                commonTypes,
                runtimeMetadata: runtimeMetadata,
                usedRuntimePaths: [:]
            )

            return RuntimeSnapshot(
                localCommonHash: try dataHasher.hash(data: commonTypes).toHex(),
                localChainHash: nil,
                typeRegistryCatalog: catalog,
                specVersion: runtimeMetadataItem.version,
                txVersion: runtimeMetadataItem.txVersion,
                metadata: runtimeMetadata
            )
        }

        let dependencies = commonTypesFetchOperation.allOperations + [runtimeMetadataOperation]

        dependencies.forEach { snapshotOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: snapshotOperation, dependencies: dependencies)
    }

    private func createWrapperForChainTypes(
        _ dataHasher: StorageHasher
    ) -> CompoundOperationWrapper<RuntimeSnapshot?> {
        let chainTypesFetchOperation = filesOperationFactory.fetchChainTypesOperation(for: chainId)

        let runtimeMetadataOperation = repository.fetchOperation(
            by: chainId,
            options: RepositoryFetchOptions()
        )

        let snapshotOperation = ClosureOperation<RuntimeSnapshot?> {
            let ownTypes = try chainTypesFetchOperation.targetOperation.extractNoCancellableResultData()

            guard let runtimeMetadataItem = try runtimeMetadataOperation
                .extractNoCancellableResultData() else {
                return nil
            }

            let decoder = try ScaleDecoder(data: runtimeMetadataItem.metadata)
            let runtimeMetadata = try RuntimeMetadata(scaleDecoder: decoder)

            guard let ownTypes = ownTypes else {
                return nil
            }

            // TODO: think about it
            let json: JSON = .dictionaryValue(["types": .dictionaryValue([:])])
            let catalog = try TypeRegistryCatalog.createFromTypeDefinition(
                try JSONEncoder().encode(json),
                versioningData: ownTypes,
                runtimeMetadata: runtimeMetadata,
                usedRuntimePaths: [:]
            )

            return RuntimeSnapshot(
                localCommonHash: nil,
                localChainHash: try dataHasher.hash(data: ownTypes).toHex(),
                typeRegistryCatalog: catalog,
                specVersion: runtimeMetadataItem.version,
                txVersion: runtimeMetadataItem.txVersion,
                metadata: runtimeMetadata
            )
        }

        let dependencies = chainTypesFetchOperation.allOperations + [runtimeMetadataOperation]

        dependencies.forEach { snapshotOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: snapshotOperation, dependencies: dependencies)
    }
}

extension RuntimeSnapshotFactory: RuntimeSnapshotFactoryProtocol {
    func createRuntimeSnapshotWrapper(
        for typesUsage: ChainModel.TypesUsage,
        dataHasher: StorageHasher
    ) -> CompoundOperationWrapper<RuntimeSnapshot?> {
        switch typesUsage {
        case .onlyCommon:
            return createWrapperForCommonTypes(dataHasher)
        case .onlyOwn:
            return createWrapperForChainTypes(dataHasher)
        case .both:
            return createWrapperForCommonAndChainTypes(dataHasher)
        }
    }
}
