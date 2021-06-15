import Foundation
import RobinHood
import FearlessUtils

struct StorageRequest: Encodable {
    let keys: [String]
    let blockHash: String?

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        try container.encode(keys)

        if let blockHash = blockHash {
            try container.encode(blockHash)
        }
    }
}

struct StorageResponse<T: Decodable> {
    let key: Data
    let data: Data?
    let value: T?
}

protocol StorageRequestFactoryProtocol {
    func queryItems<K, T>(engine: JSONRPCEngine,
                          keyParams: @escaping  () throws -> [K],
                          factory: @escaping  () throws -> RuntimeCoderFactoryProtocol,
                          storagePath: StorageCodingPath,
                          blockHash: String?)
    -> CompoundOperationWrapper<[StorageResponse<T>]> where K: Encodable, T: Decodable

    func queryItems<K1, K2, T>(engine: JSONRPCEngine,
                               keyParams1: @escaping  () throws -> [K1],
                               keyParams2: @escaping  () throws -> [K2],
                               factory: @escaping  () throws -> RuntimeCoderFactoryProtocol,
                               storagePath: StorageCodingPath,
                               blockHash: String?)
    -> CompoundOperationWrapper<[StorageResponse<T>]> where K1: Encodable, K2: Encodable, T: Decodable

    func queryItems<T>(engine: JSONRPCEngine,
                       keys: @escaping () throws -> [Data],
                       factory: @escaping  () throws -> RuntimeCoderFactoryProtocol,
                       storagePath: StorageCodingPath,
                       blockHash: String?)
    -> CompoundOperationWrapper<[StorageResponse<T>]> where T: Decodable
}

final class StorageRequestFactory: StorageRequestFactoryProtocol {
    let remoteFactory: StorageKeyFactoryProtocol

    init(remoteFactory: StorageKeyFactoryProtocol) {
        self.remoteFactory = remoteFactory
    }

    func queryItems<T>(engine: JSONRPCEngine,
                       keys: @escaping () throws -> [Data],
                       factory: @escaping  () throws -> RuntimeCoderFactoryProtocol,
                       storagePath: StorageCodingPath,
                       blockHash: String?)
    -> CompoundOperationWrapper<[StorageResponse<T>]> where T: Decodable {
        let queryOperation = JSONRPCQueryByBlockOperation(engine: engine,
                                                          method: RPCMethod.queryStorageAt)
        queryOperation.configurationBlock = {
            do {
                let keys = try keys().map { $0.toHex(includePrefix: true) }

                let request = StorageRequest(keys: keys, blockHash: blockHash)

                queryOperation.parameters = request

            } catch {
                queryOperation.result = .failure(error)
            }
        }

        let decodingOperation = StorageDecodingListOperation<T>(path: storagePath)
        decodingOperation.configurationBlock = {
            do {
                let result = try queryOperation.extractNoCancellableResultData()

                decodingOperation.codingFactory = try factory()

                decodingOperation.dataList = result
                    .flatMap({ StorageUpdateData(update: $0).changes })
                    .compactMap { $0.value }
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        decodingOperation.addDependency(queryOperation)

        let mapOperation = ClosureOperation<[StorageResponse<T>]> {
            let result = try queryOperation.extractNoCancellableResultData()

            let resultChangesData = result.flatMap { StorageUpdateData(update: $0).changes }

            let keyedEncodedItems = resultChangesData.reduce(into: [Data: Data]()) { (result, change) in
                if let data = change.value {
                    result[change.key] = data
                }
            }

            let allKeys = resultChangesData.map { $0.key }

            let allNonzeroKeys = resultChangesData.compactMap { $0.value != nil ? $0.key : nil }

            let items = try decodingOperation.extractNoCancellableResultData()

            let keyedItems = zip(allNonzeroKeys, items).reduce(into: [Data: T]()) { (result, item) in
                result[item.0] = item.1
            }

            return allKeys.map { key in
                StorageResponse(key: key, data: keyedEncodedItems[key], value: keyedItems[key])
            }
        }

        mapOperation.addDependency(decodingOperation)

        let dependencies = [queryOperation, decodingOperation]

        return CompoundOperationWrapper(targetOperation: mapOperation,
                                        dependencies: dependencies)
    }

    func queryItems<K, T>(engine: JSONRPCEngine,
                          keyParams: @escaping  () throws -> [K],
                          factory: @escaping  () throws -> RuntimeCoderFactoryProtocol,
                          storagePath: StorageCodingPath,
                          blockHash: String?)
    -> CompoundOperationWrapper<[StorageResponse<T>]> where K: Encodable, T: Decodable {

        let keysOperation = MapKeyEncodingOperation<K>(path: storagePath,
                                                       storageKeyFactory: remoteFactory)

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
            queryItems(engine: engine,
                       keys: keys,
                       factory: factory,
                       storagePath: storagePath,
                       blockHash: blockHash)

        queryWrapper.allOperations.forEach { $0.addDependency(keysOperation) }

        let dependencies = [keysOperation] + queryWrapper.dependencies

        return CompoundOperationWrapper(targetOperation: queryWrapper.targetOperation,
                                        dependencies: dependencies)
    }

    func queryItems<K1, K2, T>(engine: JSONRPCEngine,
                               keyParams1: @escaping  () throws -> [K1],
                               keyParams2: @escaping  () throws -> [K2],
                               factory: @escaping  () throws -> RuntimeCoderFactoryProtocol,
                               storagePath: StorageCodingPath,
                               blockHash: String?)
    -> CompoundOperationWrapper<[StorageResponse<T>]> where K1: Encodable, K2: Encodable, T: Decodable {
        let currentRemoteFactory = remoteFactory

        let keysOperation = DoubleMapKeyEncodingOperation<K1, K2>(path: storagePath,
                                                                  storageKeyFactory: currentRemoteFactory)

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
            queryItems(engine: engine,
                       keys: keys,
                       factory: factory,
                       storagePath: storagePath,
                       blockHash: blockHash)

        queryWrapper.allOperations.forEach { $0.addDependency(keysOperation) }

        let dependencies = [keysOperation] + queryWrapper.dependencies

        return CompoundOperationWrapper(targetOperation: queryWrapper.targetOperation,
                                        dependencies: dependencies)
    }
}

extension StorageRequestFactoryProtocol {
    func queryItems<K, T>(engine: JSONRPCEngine,
                          keyParams: @escaping  () throws -> [K],
                          factory: @escaping  () throws -> RuntimeCoderFactoryProtocol,
                          storagePath: StorageCodingPath)
    -> CompoundOperationWrapper<[StorageResponse<T>]> where K: Encodable, T: Decodable {
        queryItems(engine: engine, keyParams: keyParams, factory: factory, storagePath: storagePath, blockHash: nil)
    }

    func queryItems<K1, K2, T>(engine: JSONRPCEngine,
                               keyParams1: @escaping  () throws -> [K1],
                               keyParams2: @escaping  () throws -> [K2],
                               factory: @escaping  () throws -> RuntimeCoderFactoryProtocol,
                               storagePath: StorageCodingPath)
    -> CompoundOperationWrapper<[StorageResponse<T>]> where K1: Encodable, K2: Encodable, T: Decodable {
        queryItems(engine: engine,
                   keyParams1: keyParams1,
                   keyParams2: keyParams2,
                   factory: factory,
                   storagePath: storagePath,
                   blockHash: nil)
    }

    func queryItems<T>(engine: JSONRPCEngine,
                       keys: @escaping () throws -> [Data],
                       factory: @escaping  () throws -> RuntimeCoderFactoryProtocol,
                       storagePath: StorageCodingPath)
    -> CompoundOperationWrapper<[StorageResponse<T>]> where T: Decodable {
        queryItems(engine: engine,
                   keys: keys,
                   factory: factory,
                   storagePath: storagePath,
                   blockHash: nil)
    }
}
