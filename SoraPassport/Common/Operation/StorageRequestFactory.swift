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
import SSFUtils
import SSFStorageQueryKit

struct StorageResponse<T: Decodable> {
    let key: Data
    let data: Data?
    let value: T?
}

protocol StorageRequestFactoryProtocol {
    func queryItems<K, T>(
        engine: JSONRPCEngine,
        keyParams: @escaping () throws -> [K],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath,
        at blockHash: Data?
    )
        -> CompoundOperationWrapper<[StorageResponse<T>]> where K: Encodable, T: Decodable

    func queryItems<K1, K2, T>(
        engine: JSONRPCEngine,
        keyParams1: @escaping () throws -> [K1],
        keyParams2: @escaping () throws -> [K2],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath,
        at blockHash: Data?
    )
        -> CompoundOperationWrapper<[StorageResponse<T>]> where K1: Encodable, K2: Encodable, T: Decodable

    func queryItems<T>(
        engine: JSONRPCEngine,
        keys: @escaping () throws -> [Data],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath,
        at blockHash: Data?
    )
        -> CompoundOperationWrapper<[StorageResponse<T>]> where T: Decodable
}

final class StorageRequestFactory: StorageRequestFactoryProtocol {
    let remoteFactory: StorageKeyFactoryProtocol
    let operationManager: OperationManagerProtocol

    init(remoteFactory: StorageKeyFactoryProtocol, operationManager: OperationManagerProtocol) {
        self.remoteFactory = remoteFactory
        self.operationManager = operationManager
    }

    private func createMergeOperation<T>(
        dependingOn queryOperation: BaseOperation<[[StorageUpdate]]>,
        decodingOperation: BaseOperation<[T?]>,
        keys: @escaping () throws -> [Data]
    ) -> ClosureOperation<[StorageResponse<T>]> {
        ClosureOperation<[StorageResponse<T>]> {
            let result = try queryOperation.extractNoCancellableResultData().flatMap { $0 }

            let resultChangesData = result.flatMap { StorageUpdateData(update: $0).changes }

            let keyedEncodedItems = resultChangesData.reduce(into: [Data: Data]()) { result, change in
                if let data = change.value {
                    result[change.key] = data
                }
            }

            let allKeys = resultChangesData.map(\.key)

            let items = try decodingOperation.extractNoCancellableResultData()

            let keyedItems = zip(allKeys, items).reduce(into: [Data: T]()) { result, item in
                result[item.0] = item.1
            }

            let originalIndexedKeys = try keys().enumerated().reduce(into: [Data: Int]()) { result, item in
                result[item.element] = item.offset
            }

            return allKeys.map { key in
                StorageResponse(key: key, data: keyedEncodedItems[key], value: keyedItems[key])
            }.sorted { response1, response2 in
                guard
                    let index1 = originalIndexedKeys[response1.key],
                    let index2 = originalIndexedKeys[response2.key] else {
                    return false
                }

                return index1 < index2
            }
        }
    }

    private func createQueryOperation(
        for keys: @escaping () throws -> [Data],
        at blockHash: Data?,
        engine: JSONRPCEngine
    ) -> BaseOperation<[[StorageUpdate]]> {
        OperationCombiningService<[StorageUpdate]>(
            operationManager: operationManager) {
            let keys = try keys()

            let itemsPerPage = 1000
            let pageCount = (keys.count % itemsPerPage == 0) ?
                keys.count / itemsPerPage : (keys.count / itemsPerPage + 1)

            let wrappers: [CompoundOperationWrapper<[StorageUpdate]>] = (0 ..< pageCount).map { pageIndex in
                let pageStart = pageIndex * itemsPerPage
                let pageEnd = pageStart + itemsPerPage
                let subkeys = (pageEnd < keys.count) ?
                    Array(keys[pageStart ..< pageEnd]) :
                    Array(keys.suffix(from: pageStart))

                let params = StorageQuery(keys: subkeys, blockHash: blockHash)
                let queryOperation = JSONRPCQueryOperation(
                    engine: engine,
                    method: RPCMethod.queryStorageAt,
                    parameters: params
                )

                return CompoundOperationWrapper(targetOperation: queryOperation)
            }

            if !wrappers.isEmpty {
                for index in 1 ..< wrappers.count {
                    wrappers[index].allOperations
                        .forEach { $0.addDependency(wrappers[0].targetOperation) }
                }
            }

            return wrappers
        }.longrunOperation()
    }

    func queryItems<T>(
        engine: JSONRPCEngine,
        keys: @escaping () throws -> [Data],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath,
        at blockHash: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> where T: Decodable {
        let queryOperation = createQueryOperation(for: keys, at: blockHash, engine: engine)

        let decodingOperation = StorageFallbackDecodingListOperation<T>(path: storagePath)
        decodingOperation.configurationBlock = {
            do {
                
                let result = try queryOperation.extractNoCancellableResultData().flatMap { $0 }

                decodingOperation.codingFactory = try factory()

                decodingOperation.dataList = result
                    .flatMap { StorageUpdateData(update: $0).changes }
                    .map(\.value)
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        decodingOperation.addDependency(queryOperation)

        let mergeOperation = createMergeOperation(
            dependingOn: queryOperation,
            decodingOperation: decodingOperation,
            keys: keys
        )

        mergeOperation.addDependency(decodingOperation)

        let dependencies = [queryOperation, decodingOperation]

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: dependencies
        )
    }

    func queryItems<K, T>(
        engine: JSONRPCEngine,
        keyParams: @escaping () throws -> [K],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath,
        at blockHash: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> where K: Encodable, T: Decodable {
        let keysOperation = MapKeyEncodingOperation<K>(
            path: storagePath,
            storageKeyFactory: remoteFactory
        )

        keysOperation.configurationBlock = {
            do {
                keysOperation.keyParams = try keyParams()
                keysOperation.codingFactory = try factory()
            } catch {
                keysOperation.result = .failure(error)
            }
        }

        let keys: () throws -> [Data] = {
            try keysOperation.extractNoCancellableResultData()
        }

        let queryWrapper: CompoundOperationWrapper<[StorageResponse<T>]> =
            queryItems(engine: engine, keys: keys, factory: factory, storagePath: storagePath, at: blockHash)

        queryWrapper.allOperations.forEach { $0.addDependency(keysOperation) }

        let dependencies = [keysOperation] + queryWrapper.dependencies

        return CompoundOperationWrapper(
            targetOperation: queryWrapper.targetOperation,
            dependencies: dependencies
        )
    }

    func queryItems<K1, K2, T>(
        engine: JSONRPCEngine,
        keyParams1: @escaping () throws -> [K1],
        keyParams2: @escaping () throws -> [K2],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath,
        at blockHash: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> where K1: Encodable, K2: Encodable, T: Decodable {
        let keysOperation = DoubleMapKeyEncodingOperation<K1, K2>(path: storagePath, 
                                                                  storageKeyFactory: remoteFactory as! StorageKeyFactoryProtocol)

        keysOperation.configurationBlock = {
            do {
                keysOperation.keyParams1 = try keyParams1()
                keysOperation.keyParams2 = try keyParams2()
                keysOperation.codingFactory = try factory()
            } catch {
                keysOperation.result = .failure(error)
            }
        }

        let keys: () throws -> [Data] = {
            try keysOperation.extractNoCancellableResultData()
        }

        let queryWrapper: CompoundOperationWrapper<[StorageResponse<T>]> =
            queryItems(engine: engine, keys: keys, factory: factory, storagePath: storagePath, at: blockHash)

        queryWrapper.allOperations.forEach { $0.addDependency(keysOperation) }

        let dependencies = [keysOperation] + queryWrapper.dependencies

        return CompoundOperationWrapper(
            targetOperation: queryWrapper.targetOperation,
            dependencies: dependencies
        )
    }
}

extension StorageRequestFactoryProtocol {
    func queryItems<K, T>(
        engine: JSONRPCEngine,
        keyParams: @escaping () throws -> [K],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> where K: Encodable, T: Decodable {
        queryItems(
            engine: engine,
            keyParams: keyParams,
            factory: factory,
            storagePath: storagePath,
            at: nil
        )
    }

    func queryItems<K1, K2, T>(
        engine: JSONRPCEngine,
        keyParams1: @escaping () throws -> [K1],
        keyParams2: @escaping () throws -> [K2],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> where K1: Encodable, K2: Encodable, T: Decodable {
        queryItems(
            engine: engine,
            keyParams1: keyParams1,
            keyParams2: keyParams2,
            factory: factory,
            storagePath: storagePath,
            at: nil
        )
    }

    func queryItems<T>(
        engine: JSONRPCEngine,
        keys: @escaping () throws -> [Data],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: StorageCodingPath
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> where T: Decodable {
        queryItems(
            engine: engine,
            keys: keys,
            factory: factory,
            storagePath: storagePath,
            at: nil
        )
    }
}
