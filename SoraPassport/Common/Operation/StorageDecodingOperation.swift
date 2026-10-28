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

enum StorageDecodingOperationError: Error {
    case missingRequiredParams
    case invalidStoragePath
    case unexpectedTrailingBytes
}

protocol StorageDecodable {
    func decode(data: Data, path: StorageCodingPath, codingFactory: RuntimeCoderFactoryProtocol) throws -> JSON
}

extension StorageDecodable {
    func decode(data: Data, path: StorageCodingPath, codingFactory: RuntimeCoderFactoryProtocol) throws -> JSON {
        guard let entry = codingFactory.metadata.getStorageMetadata(
            in: path.moduleName,
            storageName: path.itemName
        ) else {
            throw StorageDecodingOperationError.invalidStoragePath
        }

        let decoder = try codingFactory.createDecoder(from: data)
        let type = try entry.type.typeName(using: codingFactory.metadata.schemaResolver)
        let value = try decoder.read(type: type)
        guard decoder.remained == 0 else {
            throw StorageDecodingOperationError.unexpectedTrailingBytes
        }
        return value
    }
}

protocol StorageModifierHandling {
    func handleModifier(at path: StorageCodingPath, codingFactory: RuntimeCoderFactoryProtocol) throws -> JSON?
}

extension StorageModifierHandling {
    func handleModifier(at path: StorageCodingPath, codingFactory: RuntimeCoderFactoryProtocol) throws -> JSON? {
        guard let entry = codingFactory.metadata.getStorageMetadata(
            in: path.moduleName,
            storageName: path.itemName
        ) else {
            throw StorageDecodingOperationError.invalidStoragePath
        }

        switch entry.modifier {
        case .defaultModifier:
            let decoder = try codingFactory.createDecoder(from: entry.defaultValue)
            let type = try entry.type.typeName(using: codingFactory.metadata.schemaResolver)
            let value = try decoder.read(type: type)
        guard decoder.remained == 0 else {
            throw StorageDecodingOperationError.unexpectedTrailingBytes
        }
        return value
        case .optional:
            return nil
        }
    }
}

final class StorageDecodingOperation<T: Decodable>: BaseOperation<T>, StorageDecodable {
    var data: Data?
    var codingFactory: RuntimeCoderFactoryProtocol?

    let path: StorageCodingPath

    init(path: StorageCodingPath, data: Data? = nil) {
        self.path = path
        self.data = data

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
            guard let data = data, let factory = codingFactory else {
                throw StorageDecodingOperationError.missingRequiredParams
            }

            let item = try decode(data: data, path: path, codingFactory: factory)
                .map(to: T.self)
            result = .success(item)
        } catch {
            result = .failure(error)
        }
    }
}

final class StorageFallbackDecodingOperation<T: Decodable>: BaseOperation<T?>,
    StorageDecodable, StorageModifierHandling {
    var data: Data?
    var codingFactory: RuntimeCoderFactoryProtocol?

    let path: StorageCodingPath

    init(path: StorageCodingPath, data: Data? = nil) {
        self.path = path
        self.data = data

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
            guard let factory = codingFactory else {
                throw StorageDecodingOperationError.missingRequiredParams
            }

            if let data = data {
                let item = try decode(data: data, path: path, codingFactory: factory).map(to: T.self)
                result = .success(item)
            } else {
                let item = try handleModifier(at: path, codingFactory: factory)?.map(to: T.self)
                result = .success(item)
            }

        } catch {
            result = .failure(error)
        }
    }
}

final class StorageDecodingListOperation<T: Decodable>: BaseOperation<[T]>, StorageDecodable {
    var dataList: [Data]?
    var codingFactory: RuntimeCoderFactoryProtocol?

    let path: StorageCodingPath

    init(path: StorageCodingPath, dataList: [Data]? = nil) {
        self.path = path
        self.dataList = dataList

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
            guard let dataList = dataList, let factory = codingFactory else {
                throw StorageDecodingOperationError.missingRequiredParams
            }

            let items: [T] = try dataList.map { try decode(data: $0, path: path, codingFactory: factory)
                .map(to: T.self)
            }

            result = .success(items)
        } catch {
            result = .failure(error)
        }
    }
}

final class StorageFallbackDecodingListOperation<T: Decodable>: BaseOperation<[T?]>,
    StorageDecodable, StorageModifierHandling {
    var dataList: [Data?]?
    var codingFactory: RuntimeCoderFactoryProtocol?

    let path: StorageCodingPath

    init(path: StorageCodingPath, dataList: [Data?]? = nil) {
        self.path = path
        self.dataList = dataList

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
            guard var dataList = dataList, let factory = codingFactory else {
                throw StorageDecodingOperationError.missingRequiredParams
            }

            let items: [T?] = try dataList.map { data in
                if let data = data {
                    return try decode(data: data, path: path, codingFactory: factory).map(to: T.self)
                } else {
                    return try handleModifier(at: path, codingFactory: factory)?.map(to: T.self)
                }
            }

            result = .success(items)
        } catch {
            print("StorageFallbackDecodingListOperation failed: ", error)
            result = .failure(error)
        }
    }
}

protocol ConstantDecodable {
    func decode(at path: ConstantCodingPath, codingFactory: RuntimeCoderFactoryProtocol) throws -> JSON
}

extension ConstantDecodable {
    func decode(at path: ConstantCodingPath, codingFactory: RuntimeCoderFactoryProtocol) throws -> JSON {
        guard let entry = codingFactory.metadata.getConstant(in: path.moduleName, constantName: path.constantName) else {
            throw StorageDecodingOperationError.invalidStoragePath
        }

        let decoder = try codingFactory.createDecoder(from: entry.value)
        let type = try entry.type(using: codingFactory.metadata.schemaResolver)
        let value = try decoder.read(type: type)
        guard decoder.remained == 0 else {
            throw StorageDecodingOperationError.unexpectedTrailingBytes
        }
        return value
    }
}

final class StorageConstantOperation<T: Decodable>: BaseOperation<T>, ConstantDecodable {
    var codingFactory: RuntimeCoderFactoryProtocol?

    let path: ConstantCodingPath

    init(path: ConstantCodingPath) {
        self.path = path

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
            guard let factory = codingFactory else {
                throw StorageDecodingOperationError.missingRequiredParams
            }

            let item: T = try decode(at: path, codingFactory: factory).map(to: T.self)
            result = .success(item)
        } catch {
            result = .failure(error)
        }
    }
}

final class PrimitiveConstantOperation<T: LosslessStringConvertible & Equatable>: BaseOperation<T>, ConstantDecodable {
    var codingFactory: RuntimeCoderFactoryProtocol?

    let path: ConstantCodingPath

    init(path: ConstantCodingPath) {
        self.path = path

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
            guard let factory = codingFactory else {
                throw StorageDecodingOperationError.missingRequiredParams
            }

            let item: StringScaleMapper<T> = try decode(at: path, codingFactory: factory)
                .map(to: StringScaleMapper<T>.self)
            result = .success(item.value)
        } catch {
            result = .failure(error)
        }
    }
}
