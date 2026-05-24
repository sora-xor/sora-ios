/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

public class DocumentBaseSerializer: ChainableSerializerProtocol {
    public var next: ChainableSerializerProtocol?

    @discardableResult
    public func chain(to serializer: ChainableSerializerProtocol) -> ChainableSerializerProtocol {
        next = serializer
        return serializer
    }

    public func deserialize(data: Data) throws -> Any {
        do {
            return try handleDeserialization(of: data)
        } catch {
            if let existingNext = next {
                return try existingNext.deserialize(data: data)
            }

            throw error
        }
    }

    public func serialize(node: Any) throws -> Data {
        do {
            return try handleSerialization(of: node)
        } catch {
            if let existingNext = next {
                return try existingNext.serialize(node: node)
            }

            throw error
        }
    }

    public func handleDeserialization(of data: Data) throws -> Any {
        throw DocumentSerializationError.unsupportedSerializationFormat
    }

    public func handleSerialization(of node: Any) throws -> Data {
        throw DocumentSerializationError.unsupportedSerializationFormat
    }
}

public class PNGImageSerializer: DocumentBaseSerializer {
    override public func handleDeserialization(of data: Data) throws -> Any {
        guard let image = UIImage(data: data) else {
            throw DocumentSerializationError.unsupportedDeserializationFormat
        }

        return image
    }

    override public func handleSerialization(of node: Any) throws -> Data {
        guard let image = node as? UIImage else {
            throw DocumentSerializationError.unsupportedSerializationFormat
        }

        guard let data = image.pngData() else {
            throw DocumentSerializationError.unsupportedSerializationFormat
        }

        return data
    }
}
