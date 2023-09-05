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
import FearlessUtils
import RobinHood

enum StorageDecodingOperationError: Error {
    case missingRequiredParams
    case invalidStoragePath
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
        return try decoder.read(type: type)
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
            return try decoder.read(type: type)
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
        return try decoder.read(type: type)
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
