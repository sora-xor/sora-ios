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

import BigInt
import Foundation
import CryptoKit
import SSFUtils
import RobinHood

enum RuntimeSnapshotFactoryError: Error {
    case unexpectedError
    case unreviewedSoraRuntime
}

/// The runtime identity that SORA2 metadata declares about itself in its
/// `System.Version` constant (`sp_version::RuntimeVersion`).
///
/// SORA2 mainnet upgrades its runtime often (130 → 132 → 133 within three
/// weeks in 2026). The app therefore never pins one runtime version or one
/// metadata hash. Instead it binds metadata bytes to the runtime version they
/// declare, and binds both to what the connected node reports as live.
struct Sora2RuntimeIdentity: Equatable {
    static let reviewedSpecName = "sora-substrate"
    /// The oldest SORA2 runtime this app was reviewed against. A lower value
    /// is a rollback or a different chain and is never admitted.
    static let minimumSpecVersion: UInt32 = 130

    let specName: String
    let specVersion: UInt32
    let transactionVersion: UInt32

    /// Reads `System.Version` from decoded metadata. The SCALE layout is
    /// `spec_name: String, impl_name: String, authoring_version: u32,
    /// spec_version: u32, impl_version: u32, apis: Vec<([u8; 8], u32)>,
    /// transaction_version: u32, ...`.
    static func declared(by metadata: RuntimeMetadata) throws -> Sora2RuntimeIdentity {
        guard
            let constant = metadata.getConstant(
                in: "System",
                constantName: "Version"
            )
        else {
            throw RuntimeSnapshotFactoryError.unreviewedSoraRuntime
        }
        do {
            let decoder = try ScaleDecoder(data: constant.value)
            let specName = try String(scaleDecoder: decoder)
            _ = try String(scaleDecoder: decoder)
            _ = try UInt32(scaleDecoder: decoder)
            let specVersion = try UInt32(scaleDecoder: decoder)
            _ = try UInt32(scaleDecoder: decoder)
            let apiCount = try BigUInt(scaleDecoder: decoder)
            guard apiCount <= 4_096 else {
                throw RuntimeSnapshotFactoryError.unreviewedSoraRuntime
            }
            let apiBytes = Int(apiCount) * 12
            if apiBytes > 0 {
                _ = try decoder.read(count: apiBytes)
                try decoder.confirm(count: apiBytes)
            }
            let transactionVersion = try UInt32(scaleDecoder: decoder)
            return Sora2RuntimeIdentity(
                specName: specName,
                specVersion: specVersion,
                transactionVersion: transactionVersion
            )
        } catch {
            throw RuntimeSnapshotFactoryError.unreviewedSoraRuntime
        }
    }

    /// Accepts metadata only when it declares a SORA2 runtime at or above the
    /// reviewed floor and exactly the spec and transaction versions it is
    /// stored or used under.
    static func requireDeclaredIdentity(
        of metadata: RuntimeMetadata,
        specVersion: UInt32,
        transactionVersion: UInt32
    ) throws {
        let declared = try declared(by: metadata)
        guard
            declared.specName == reviewedSpecName,
            declared.specVersion >= minimumSpecVersion,
            declared.specVersion == specVersion,
            declared.transactionVersion > 0,
            declared.transactionVersion == transactionVersion
        else {
            throw RuntimeSnapshotFactoryError.unreviewedSoraRuntime
        }
    }
}

enum ReviewedSoraRuntimeSnapshotAdmission {
    static let maximumMetadataBytes = 4 * 1024 * 1024
    static let maximumTypeRegistryBytes = 512 * 1024
    static let reviewedCommonTypesBytes = 122_551
    /// `runtime-sora.json`. 3.9.0 adds `"Index": "u32"`: runtime 133 renamed
    /// the nonce type to `Nonce`, and the extrinsic encoder still looks up
    /// `Index` (`KnownType.index`). Compact encoding is width-independent, so
    /// the bytes are unchanged for every earlier runtime.
    static let reviewedChainTypesBytes = 136_971
    static let reviewedCommonTypesSHA256 =
        "2bd6d5a58ceaecb5a1ac05f089e1269288d884ae8b768527d58ae217434bf580"
    static let reviewedChainTypesSHA256 =
        "7a96f47ac89a9db709744e21f0672e8cd535a483bff33eb6952e9537c79d4363"

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

    /// Admits SORA2 mainnet metadata for any live runtime at or above the
    /// reviewed floor. Chain identity stays pinned (genesis), and the bytes
    /// must declare exactly the spec and transaction versions they are stored
    /// under, so a runtime upgrade is picked up without an app update while a
    /// mismatched or foreign blob is rejected. Signing additionally compares
    /// the metadata with the live node (`Sora2LiveRuntimeValidator`).
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
            item.version >= Sora2RuntimeIdentity.minimumSpecVersion,
            item.txVersion > 0,
            !item.metadata.isEmpty,
            item.metadata.count <= maximumMetadataBytes
        else {
            throw RuntimeSnapshotFactoryError.unreviewedSoraRuntime
        }
        let metadata: RuntimeMetadata
        do {
            let decoder = try ScaleDecoder(data: item.metadata)
            metadata = try RuntimeMetadata(scaleDecoder: decoder)
            guard decoder.remained == 0 else {
                throw RuntimeSnapshotFactoryError.unreviewedSoraRuntime
            }
        } catch {
            throw RuntimeSnapshotFactoryError.unreviewedSoraRuntime
        }
        try Sora2RuntimeIdentity.requireDeclaredIdentity(
            of: metadata,
            specVersion: item.version,
            transactionVersion: item.txVersion
        )
    }

    /// SORA2 mainnet is admitted with the exact checked-in SORA override
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

            guard let runtimeMetadataItem = try runtimeMetadataOperation
                .extractNoCancellableResultData() else {
                throw RuntimeSnapshotFactoryError.unexpectedError
            }

            return try Self.makeOwnTypesSnapshot(
                chainId: self.chainId,
                runtimeMetadataItem: runtimeMetadataItem,
                ownTypes: ownTypes,
                dataHasher: dataHasher
            )
        }

        let dependencies = chainTypesFetchOperation.allOperations + [runtimeMetadataOperation]

        dependencies.forEach { snapshotOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: snapshotOperation, dependencies: dependencies)
    }
}

extension RuntimeSnapshotFactory {
    /// Builds a runtime snapshot from admitted metadata and the chain's own
    /// type registry (the bundled `runtime-sora.json` for SORA2). The runtime
    /// provider and the live-network signing test both use this, so the test
    /// encodes extrinsics with exactly the code the app uses.
    static func makeOwnTypesSnapshot(
        chainId: ChainModel.Id,
        runtimeMetadataItem: RuntimeMetadataItem,
        ownTypes: Data,
        dataHasher: StorageHasher
    ) throws -> RuntimeSnapshot {
        try ReviewedSoraRuntimeSnapshotAdmission.validateTypeRegistryUsage(
            chainId: chainId,
            typesUsage: .onlyOwn
        )
        try ReviewedSoraRuntimeSnapshotAdmission.validateChainTypes(
            chainId: chainId,
            data: ownTypes
        )
        try ReviewedSoraRuntimeSnapshotAdmission.validate(
            chainId: chainId,
            item: runtimeMetadataItem
        )

        let decoder = try ScaleDecoder(data: runtimeMetadataItem.metadata)
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
            specVersion: runtimeMetadataItem.version,
            txVersion: runtimeMetadataItem.txVersion,
            metadata: runtimeMetadata
        )
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
