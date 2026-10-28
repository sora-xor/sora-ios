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
import RobinHood

enum RuntimeHotBootSnapshotFactoryError: Error {
    case unexpectedError
}

protocol RuntimeHotBootSnapshotFactoryProtocol {
    func createRuntimeSnapshotWrapper(
        for typesUsage: ChainModel.TypesUsage,
        dataHasher: StorageHasher
    ) -> CompoundOperationWrapper<RuntimeSnapshot?>
}

final class RuntimeHotBootSnapshotFactory {
    private let chainId: ChainModel.Id
    private let runtimeItem: RuntimeMetadataItem
    private let commonTypes: Data
    private let filesOperationFactory: RuntimeFilesOperationFactoryProtocol

    init(
        chainId: ChainModel.Id,
        runtimeItem: RuntimeMetadataItem,
        commonTypes: Data,
        filesOperationFactory: RuntimeFilesOperationFactoryProtocol
    ) {
        self.chainId = chainId
        self.runtimeItem = runtimeItem
        self.commonTypes = commonTypes
        self.filesOperationFactory = filesOperationFactory
    }

    private func createWrapperForCommonAndChainTypes(
        _ dataHasher: StorageHasher
    ) -> CompoundOperationWrapper<RuntimeSnapshot?> {
        let chainTypesFetchOperation = filesOperationFactory.fetchChainTypesOperation(for: chainId)

        let snapshotOperation = ClosureOperation<RuntimeSnapshot?> { [weak self] in
            guard let self else { throw RuntimeHotBootSnapshotFactoryError.unexpectedError }
            let chainTypes = try chainTypesFetchOperation.targetOperation.extractNoCancellableResultData()
            try ReviewedSoraRuntimeSnapshotAdmission
                .validateTypeRegistryUsage(
                    chainId: self.chainId,
                    typesUsage: .both
                )
            guard let chainTypes = chainTypes else {
                throw RuntimeHotBootSnapshotFactoryError.unexpectedError
            }
            try ReviewedSoraRuntimeSnapshotAdmission.validateCommonTypes(
                chainId: self.chainId,
                data: self.commonTypes
            )
            try ReviewedSoraRuntimeSnapshotAdmission.validateChainTypes(
                chainId: self.chainId,
                data: chainTypes
            )
            try ReviewedSoraRuntimeSnapshotAdmission.validate(
                chainId: self.chainId,
                item: self.runtimeItem
            )

            let decoder = try ScaleDecoder(data: self.runtimeItem.metadata)
            var runtimeMetadata: RuntimeMetadata
            if let resolver = self.runtimeItem.resolver {
                runtimeMetadata = try RuntimeMetadata(scaleDecoder: decoder)
            } else {
                runtimeMetadata = try RuntimeMetadata(scaleDecoder: decoder)
            }

            let catalog = try TypeRegistryCatalog.createFromTypeDefinition(
                self.commonTypes,
                versioningData: chainTypes,
                runtimeMetadata: runtimeMetadata, 
                usedRuntimePaths: [:]
            )

            return RuntimeSnapshot(
                localCommonHash: try dataHasher.hash(data: self.commonTypes).toHex(),
                localChainHash: try dataHasher.hash(data: chainTypes).toHex(),
                typeRegistryCatalog: catalog,
                specVersion: self.runtimeItem.version,
                txVersion: self.runtimeItem.txVersion,
                metadata: runtimeMetadata
            )
        }

        let dependencies = chainTypesFetchOperation.allOperations

        dependencies.forEach { snapshotOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: snapshotOperation, dependencies: dependencies)
    }

    private func createWrapperForCommonTypes(
        _ dataHasher: StorageHasher
    ) -> CompoundOperationWrapper<RuntimeSnapshot?> {
        let snapshotOperation = ClosureOperation<RuntimeSnapshot?> { [weak self] in
            guard let strongSelf = self else { throw RuntimeHotBootSnapshotFactoryError.unexpectedError }
            try ReviewedSoraRuntimeSnapshotAdmission
                .validateTypeRegistryUsage(
                    chainId: strongSelf.chainId,
                    typesUsage: .onlyCommon
                )
            try ReviewedSoraRuntimeSnapshotAdmission.validateCommonTypes(
                chainId: strongSelf.chainId,
                data: strongSelf.commonTypes
            )
            try ReviewedSoraRuntimeSnapshotAdmission.validate(
                chainId: strongSelf.chainId,
                item: strongSelf.runtimeItem
            )

            let decoder = try ScaleDecoder(data: strongSelf.runtimeItem.metadata)
            let runtimeMetadata = try RuntimeMetadata(scaleDecoder: decoder)

            let catalog = try TypeRegistryCatalog.createFromTypeDefinition(
                strongSelf.commonTypes,
                runtimeMetadata: runtimeMetadata,
                usedRuntimePaths: [:]
            )

            return RuntimeSnapshot(
                localCommonHash: try dataHasher.hash(data: strongSelf.commonTypes).toHex(),
                localChainHash: nil,
                typeRegistryCatalog: catalog,
                specVersion: strongSelf.runtimeItem.version,
                txVersion: strongSelf.runtimeItem.txVersion,
                metadata: runtimeMetadata
            )
        }

        return CompoundOperationWrapper(targetOperation: snapshotOperation, dependencies: [])
    }

    private func createWrapperForChainTypes(
        _ dataHasher: StorageHasher
    ) -> CompoundOperationWrapper<RuntimeSnapshot?> {
        let chainTypesFetchOperation = filesOperationFactory.fetchChainTypesOperation(for: chainId)

        let snapshotOperation = ClosureOperation<RuntimeSnapshot?> { [weak self] in
            guard let strongSelf = self else {
                throw RuntimeHotBootSnapshotFactoryError.unexpectedError
            }
            let ownTypes = try chainTypesFetchOperation.targetOperation.extractNoCancellableResultData()
            try ReviewedSoraRuntimeSnapshotAdmission
                .validateTypeRegistryUsage(
                    chainId: strongSelf.chainId,
                    typesUsage: .onlyOwn
                )
            guard let ownTypes = ownTypes else {
                throw RuntimeHotBootSnapshotFactoryError.unexpectedError
            }
            try ReviewedSoraRuntimeSnapshotAdmission.validateChainTypes(
                chainId: strongSelf.chainId,
                data: ownTypes
            )
            try ReviewedSoraRuntimeSnapshotAdmission.validate(
                chainId: strongSelf.chainId,
                item: strongSelf.runtimeItem
            )

            let decoder = try ScaleDecoder(data: strongSelf.runtimeItem.metadata)
            let runtimeMetadata = try RuntimeMetadata(scaleDecoder: decoder)

            // Common types are empty because this snapshot uses only the chain's own types.
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
                specVersion: strongSelf.runtimeItem.version,
                txVersion: strongSelf.runtimeItem.txVersion,
                metadata: runtimeMetadata
            )
        }

        let dependencies = chainTypesFetchOperation.allOperations

        dependencies.forEach { snapshotOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: snapshotOperation, dependencies: dependencies)
    }
}

extension RuntimeHotBootSnapshotFactory: RuntimeHotBootSnapshotFactoryProtocol {
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
