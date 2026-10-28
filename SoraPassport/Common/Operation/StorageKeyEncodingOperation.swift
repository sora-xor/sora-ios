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

protocol NMapKeyParamProtocol {
    func encode(encoder: DynamicScaleEncoding, type: String) throws -> Data
}

struct NMapKeyParam<T: Encodable>: NMapKeyParamProtocol {
    var value: T

    func encode(encoder: DynamicScaleEncoding, type: String) throws -> Data {
        try encoder.append(value, ofType: type)
        return try encoder.encode()
    }
}

enum StorageKeyEncodingOperationError: Error {
    case missingRequiredParams
    case incompatibleStorageType
    case invalidStoragePath
}

class UnkeyedEncodingOperation: BaseOperation<Data> {
    var codingFactory: RuntimeCoderFactoryProtocol?

    let path: StorageCodingPath
    let storageKeyFactory: StorageKeyFactoryProtocol

    init(path: StorageCodingPath, storageKeyFactory: StorageKeyFactoryProtocol) {
        self.path = path
        self.storageKeyFactory = storageKeyFactory

        super.init()
    }

    private func performEncoding() {
        do {
            guard let factory = codingFactory else {
                throw StorageKeyEncodingOperationError.missingRequiredParams
            }

            guard factory.metadata.getStorageMetadata(in: path.moduleName, storageName: path.itemName) != nil else {
                throw StorageKeyEncodingOperationError.invalidStoragePath
            }

            let keyData: Data = try storageKeyFactory.createStorageKey(
                moduleName: path.moduleName,
                storageName: path.itemName
            )

            result = .success(keyData)
        } catch {
            result = .failure(error)
        }
    }

    override func main() {
        super.main()

        if isCancelled {
            return
        }

        if result != nil {
            return
        }

        performEncoding()
    }
}

class MapKeyEncodingOperation<T: Encodable>: BaseOperation<[Data]> {
    var keyParams: [T]?
    var codingFactory: RuntimeCoderFactoryProtocol?

    let path: StorageCodingPath
    let storageKeyFactory: StorageKeyFactoryProtocol

    init(path: StorageCodingPath, storageKeyFactory: StorageKeyFactoryProtocol, keyParams: [T]? = nil) {
        self.path = path
        self.keyParams = keyParams
        self.storageKeyFactory = storageKeyFactory

        super.init()
    }

    private func performEncoding() {
        do {
            guard let factory = codingFactory, let keyParams = keyParams else {
                throw StorageKeyEncodingOperationError.missingRequiredParams
            }

            guard let entry = factory.metadata.getStorageMetadata(
                in: path.moduleName,
                storageName: path.itemName
            ) else {
                throw StorageKeyEncodingOperationError.invalidStoragePath
            }

            let keyType: String
            let hasher: StorageHasher

            switch entry.type {
            case let .map(mapEntry):
                keyType = mapEntry.key
                hasher = mapEntry.hasher
            case let .doubleMap(doubleMapEntry):
                keyType = doubleMapEntry.key1
                hasher = doubleMapEntry.hasher
            case let .nMap(nMapEntry):
                guard
                    let firstKey = try nMapEntry.keys(using: factory.metadata.schemaResolver).first,
                    let firstHasher = nMapEntry.hashers.first else {
                    throw StorageKeyEncodingOperationError.missingRequiredParams
                }

                keyType = firstKey
                hasher = firstHasher
            case .plain:
                throw StorageKeyEncodingOperationError.incompatibleStorageType
            }
            
            let encoder = factory.createEncoder()
            keyParams.forEach { keyParam in
                try? encoder.append(keyParam, ofType: keyType)
            }
            let encodedParam = try encoder.encode()

            let keys: [Data] = [
                try storageKeyFactory.createStorageKey(
                    moduleName: path.moduleName,
                    storageName: path.itemName,
                    key: encodedParam,
                    hasher: hasher
                )
            ]

            result = .success(keys)
        } catch {
            result = .failure(error)
        }
    }

    override func main() {
        super.main()

        if isCancelled {
            return
        }

        if result != nil {
            return
        }

        performEncoding()
    }
}

class DoubleMapKeyEncodingOperation<T1: Encodable, T2: Encodable>: BaseOperation<[Data]> {
    var keyParams1: [T1]?
    var keyParams2: [T2]?
    var codingFactory: RuntimeCoderFactoryProtocol?

    let path: StorageCodingPath
    let storageKeyFactory: StorageKeyFactoryProtocol

    init(
        path: StorageCodingPath,
        storageKeyFactory: StorageKeyFactoryProtocol,
        keyParams1: [T1]? = nil,
        keyParams2: [T2]? = nil
    ) {
        self.path = path
        self.keyParams1 = keyParams1
        self.keyParams2 = keyParams2
        self.storageKeyFactory = storageKeyFactory

        super.init()
    }

    override func main() {
        super.main()

        if isCancelled {
            return
        }

        if result != nil {
            return
        }

        do {
            guard let factory = codingFactory,
                  let keyParams1 = keyParams1,
                  let keyParams2 = keyParams2,
                  keyParams1.count == keyParams2.count
            else {
                throw StorageKeyEncodingOperationError.missingRequiredParams
            }

            guard let entry = factory.metadata.getStorageMetadata(
                in: path.moduleName,
                storageName: path.itemName
            ) else {
                throw StorageKeyEncodingOperationError.invalidStoragePath
            }

            guard case let .doubleMap(doubleMapEntry) = entry.type else {
                throw StorageKeyEncodingOperationError.incompatibleStorageType
            }

            let keys: [Data] = try zip(keyParams1, keyParams2).map { param in
                let encodedParam1 = try encodeParam(
                    param.0,
                    factory: factory,
                    type: doubleMapEntry.key1
                )

                let encodedParam2 = try encodeParam(
                    param.1,
                    factory: factory,
                    type: doubleMapEntry.key2
                )

                return try storageKeyFactory.createStorageKey(
                    moduleName: path.moduleName,
                    storageName: path.itemName,
                    key1: encodedParam1,
                    hasher1: doubleMapEntry.hasher,
                    key2: encodedParam2,
                    hasher2: doubleMapEntry.key2Hasher
                )
            }

            result = .success(keys)
        } catch {
            result = .failure(error)
        }
    }

    private func encodeParam<T: Encodable>(
        _ param: T,
        factory: RuntimeCoderFactoryProtocol,
        type: String
    ) throws -> Data {
        let encoder = factory.createEncoder()
        try encoder.append(param, ofType: type)
        return try encoder.encode()
    }
}

class NMapKeyEncodingOperation: BaseOperation<[Data]> {
    var keyParams: [[NMapKeyParamProtocol]]?
    var codingFactory: RuntimeCoderFactoryProtocol?

    let path: StorageCodingPath
    let storageKeyFactory: StorageKeyFactoryProtocol

    init(
        path: StorageCodingPath,
        storageKeyFactory: StorageKeyFactoryProtocol,
        keyParams: [[NMapKeyParamProtocol]]? = nil
    ) {
        self.path = path
        self.keyParams = keyParams
        self.storageKeyFactory = storageKeyFactory

        super.init()
    }

    override func main() {
        super.main()

        if isCancelled {
            return
        }

        if result != nil {
            return
        }

        do {
            guard let factory = codingFactory,
                  let keyParams = keyParams
            else {
                throw StorageKeyEncodingOperationError.missingRequiredParams
            }

            guard let entry = factory.metadata.getStorageMetadata(
                in: path.moduleName,
                storageName: path.itemName
            ) else {
                throw StorageKeyEncodingOperationError.invalidStoragePath
            }

            guard case let .nMap(nMapEntry) = entry.type else {
                throw StorageKeyEncodingOperationError.incompatibleStorageType
            }

            let keyEntries = try nMapEntry.keys(using: factory.metadata.schemaResolver)
            guard keyEntries.count == keyParams.count else {
                throw StorageKeyEncodingOperationError.incompatibleStorageType
            }

            var params: [[NMapKeyParamProtocol]] = []
            for index in 0 ..< keyParams[0].count {
                var array: [NMapKeyParamProtocol] = []
                for param in keyParams {
                    array.append(param[index])
                }
                params.append(array)
            }

            let keys: [Data] = try params.map { params in
                let encodedParams: [Data] = try params.enumerated().map { index, param in
                    try param.encode(encoder: factory.createEncoder(), type: keyEntries[index])
                }

                return try storageKeyFactory.createStorageKey(
                    moduleName: path.moduleName,
                    storageName: path.itemName,
                    keys: encodedParams,
                    hashers: nMapEntry.hashers
                )
            }

            result = .success(keys)
        } catch {
            result = .failure(error)
        }
    }

    private func encodeParam(
        _ param: NMapKeyParamProtocol,
        factory: RuntimeCoderFactoryProtocol,
        type: String
    ) throws -> Data {
        try param.encode(encoder: factory.createEncoder(), type: type)
    }
}

extension MapKeyEncodingOperation {
    func localWrapper(for factory: ChainStorageIdFactoryProtocol) -> CompoundOperationWrapper<[String]> {
        baseLocalWrapper(for: factory)
    }
}

extension DoubleMapKeyEncodingOperation {
    func localWrapper(for factory: ChainStorageIdFactoryProtocol) -> CompoundOperationWrapper<[String]> {
        baseLocalWrapper(for: factory)
    }
}

private extension BaseOperation where ResultType == [Data] {
    func baseLocalWrapper(for factory: ChainStorageIdFactoryProtocol) -> CompoundOperationWrapper<[String]> {
        let mapOperation = ClosureOperation<[String]> {
            let keys = try self.extractNoCancellableResultData()
            return keys.map { factory.createIdentifier(for: $0) }
        }

        mapOperation.addDependency(self)
        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [self])
    }
}
