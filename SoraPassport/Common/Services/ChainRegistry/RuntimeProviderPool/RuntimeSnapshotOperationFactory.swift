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
import CryptoKit
import SSFUtils
import RobinHood

enum RuntimeSnapshotFactoryError: Error {
    case unexpectedError
    case unreviewedSoraRuntime
}

enum ReviewedSoraRuntimeSnapshotAdmission {
    static let maximumMetadataBytes = 4 * 1024 * 1024
    static let maximumTypeRegistryBytes = 512 * 1024
    static let reviewedCommonTypesBytes = 122_551
    static let reviewedChainTypesBytes = 136_939
    static let reviewedCommonTypesSHA256 =
        "2bd6d5a58ceaecb5a1ac05f089e1269288d884ae8b768527d58ae217434bf580"
    static let reviewedChainTypesSHA256 =
        "9ced79bb14808bd5e56145e834807e54cc5c623023b768bb415773035388ae92"

    static func isReviewedSoraChain(_ chainId: ChainModel.Id) -> Bool {
        guard
            let normalizedChainId =
                PolkamarktTransactionHash.normalized(chainId),
            let reviewedChainId =
                PolkamarktTransactionHash.normalized(
                    PIIndexerClient.soraMainnetGenesis
                )
        else {
            return false
        }
        return normalizedChainId == reviewedChainId
    }

    static func validate(
        chainId: ChainModel.Id,
        item: RuntimeMetadataItem
    ) throws {
        guard isReviewedSoraChain(chainId) else { return }
        guard
            let normalizedItemChain =
                PolkamarktTransactionHash.normalized(item.chain),
            let normalizedRequestedChain =
                PolkamarktTransactionHash.normalized(chainId),
            normalizedItemChain == normalizedRequestedChain,
            item.version == PolkamarktRuntimeContract.specVersion,
            item.txVersion ==
                PolkamarktRuntimeContract.transactionVersion,
            !item.metadata.isEmpty,
            item.metadata.count <= maximumMetadataBytes,
            PolkamarktRuntimeContract.rawMetadataSHA256(item.metadata) ==
                PolkamarktRuntimeContract.metadataFileSHA256
        else {
            throw RuntimeSnapshotFactoryError.unreviewedSoraRuntime
        }
    }

    /// SORA2 runtime-130 is admitted with the exact checked-in SORA override
    /// registry. A remotely supplied chain model cannot switch the reviewed
    /// signer to common-only or mixed type resolution.
    static func validateTypeRegistryUsage(
        chainId: ChainModel.Id,
        typesUsage: ChainModel.TypesUsage
    ) throws {
        guard isReviewedSoraChain(chainId) else { return }
        guard case .onlyOwn = typesUsage else {
            throw RuntimeSnapshotFactoryError.unreviewedSoraRuntime
        }
    }

    static func validateCommonTypes(
        chainId: ChainModel.Id,
        data: Data
    ) throws {
        guard isReviewedSoraChain(chainId) else { return }
        try validateReviewedCommonTypes(data)
    }

    static func validateChainTypes(
        chainId: ChainModel.Id,
        data: Data
    ) throws {
        guard isReviewedSoraChain(chainId) else { return }
        try validateTypeRegistry(
            data,
            expectedBytes: reviewedChainTypesBytes,
            expectedSHA256: reviewedChainTypesSHA256
        )
    }

    static func validateReviewedCommonTypes(_ data: Data) throws {
        try validateTypeRegistry(
            data,
            expectedBytes: reviewedCommonTypesBytes,
            expectedSHA256: reviewedCommonTypesSHA256
        )
    }

    static func loadReviewedCommonTypes() throws -> Data {
        let resourcePath: String? = R.file.runtimeDefaultJson.path()
        guard let path = resourcePath else {
            throw RuntimeSnapshotFactoryError.unreviewedSoraRuntime
        }
        let data = try loadBoundedResource(
            at: URL(fileURLWithPath: path),
            expectedBytes: reviewedCommonTypesBytes
        )
        try validateReviewedCommonTypes(data)
        return data
    }

    static func loadReviewedChainTypes() throws -> Data {
        let resourcePath: String? = R.file.runtimeSoraJson.path()
        guard let path = resourcePath else {
            throw RuntimeSnapshotFactoryError.unreviewedSoraRuntime
        }
        let data = try loadBoundedResource(
            at: URL(fileURLWithPath: path),
            expectedBytes: reviewedChainTypesBytes
        )
        try validateTypeRegistry(
            data,
            expectedBytes: reviewedChainTypesBytes,
            expectedSHA256: reviewedChainTypesSHA256
        )
        return data
    }

    static func typeRegistrySHA256(_ data: Data) -> String {
        Data(SHA256.hash(data: data))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func validateTypeRegistry(
        _ data: Data,
        expectedBytes: Int,
        expectedSHA256: String
    ) throws {
        guard
            expectedBytes > 0,
            expectedBytes <= maximumTypeRegistryBytes,
            data.count == expectedBytes,
            data.count <= maximumTypeRegistryBytes,
            typeRegistrySHA256(data) == expectedSHA256
        else {
            throw RuntimeSnapshotFactoryError.unreviewedSoraRuntime
        }
    }

    private static func loadBoundedResource(
        at url: URL,
        expectedBytes: Int
    ) throws -> Data {
        let values = try url.resourceValues(
            forKeys: [
                .fileSizeKey,
                .isRegularFileKey,
                .isSymbolicLinkKey,
            ]
        )
        guard
            values.isRegularFile == true,
            values.isSymbolicLink != true,
            values.fileSize == expectedBytes,
            expectedBytes <= maximumTypeRegistryBytes
        else {
            throw RuntimeSnapshotFactoryError.unreviewedSoraRuntime
        }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count == expectedBytes else {
            throw RuntimeSnapshotFactoryError.unreviewedSoraRuntime
        }
        return data
    }
}

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

            try ReviewedSoraRuntimeSnapshotAdmission
                .validateTypeRegistryUsage(
                    chainId: self.chainId,
                    typesUsage: .both
                )
            guard let commonTypes = commonTypes, let chainTypes = chainTypes else {
                throw RuntimeSnapshotFactoryError.unexpectedError
            }
            try ReviewedSoraRuntimeSnapshotAdmission.validateCommonTypes(
                chainId: self.chainId,
                data: commonTypes
            )
            try ReviewedSoraRuntimeSnapshotAdmission.validateChainTypes(
                chainId: self.chainId,
                data: chainTypes
            )

            guard let runtimeMetadataItem = try runtimeMetadataOperation
                .extractNoCancellableResultData() else {
                throw RuntimeSnapshotFactoryError.unexpectedError
            }
            try ReviewedSoraRuntimeSnapshotAdmission.validate(
                chainId: self.chainId,
                item: runtimeMetadataItem
            )

            let decoder = try ScaleDecoder(data: runtimeMetadataItem.metadata)
            let runtimeMetadata = try RuntimeMetadata(scaleDecoder: decoder)

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

            try ReviewedSoraRuntimeSnapshotAdmission
                .validateTypeRegistryUsage(
                    chainId: self.chainId,
                    typesUsage: .onlyCommon
                )
            guard let commonTypes = commonTypes else {
                throw RuntimeSnapshotFactoryError.unexpectedError
            }
            try ReviewedSoraRuntimeSnapshotAdmission.validateCommonTypes(
                chainId: self.chainId,
                data: commonTypes
            )

            guard let runtimeMetadataItem = try runtimeMetadataOperation.extractNoCancellableResultData() else {
                throw RuntimeSnapshotFactoryError.unexpectedError
            }
            try ReviewedSoraRuntimeSnapshotAdmission.validate(
                chainId: self.chainId,
                item: runtimeMetadataItem
            )

            let decoder = try ScaleDecoder(data: runtimeMetadataItem.metadata)
            let runtimeMetadata = try RuntimeMetadata(scaleDecoder: decoder)

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

            try ReviewedSoraRuntimeSnapshotAdmission
                .validateTypeRegistryUsage(
                    chainId: self.chainId,
                    typesUsage: .onlyOwn
                )
            guard let ownTypes = ownTypes else {
                throw RuntimeSnapshotFactoryError.unexpectedError
            }
            try ReviewedSoraRuntimeSnapshotAdmission.validateChainTypes(
                chainId: self.chainId,
                data: ownTypes
            )

            guard let runtimeMetadataItem = try runtimeMetadataOperation
                .extractNoCancellableResultData() else {
                throw RuntimeSnapshotFactoryError.unexpectedError
            }
            try ReviewedSoraRuntimeSnapshotAdmission.validate(
                chainId: self.chainId,
                item: runtimeMetadataItem
            )

            let decoder = try ScaleDecoder(data: runtimeMetadataItem.metadata)
            let runtimeMetadata = try RuntimeMetadata(scaleDecoder: decoder)

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
