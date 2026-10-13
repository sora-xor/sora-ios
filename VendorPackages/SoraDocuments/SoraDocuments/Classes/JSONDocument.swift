/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

public struct JSONDocumentReference: DocumentReferenceProtocol {
    static let referenceKey = "_id"

    public var referenceName: String

    public init(referenceName: String) {
        self.referenceName = referenceName
    }

    public func documentQuery(in storage: DocumentsStorageProtocol) -> DocumentsQueryProtocol {
        return storage.query(by: referenceName)
    }
}

public struct JSONDocumentNode: DocumentNodeProtocol {
    fileprivate var attributes = [String: Any]()

    fileprivate init(attributes: [String: Any]) {
        self.attributes = attributes
    }

    public init() {}

    public mutating func set(integer: Int, for key: String) {
        attributes[key] = NSNumber(value: integer)
    }

    public mutating func set(string: String, for key: String) {
        attributes[key] = string
    }

    public mutating func set(list: [DocumentNodeProtocol], for key: String) {
        let node = list.map { return $0.toDictionary() }
        attributes[key] = node
    }

    public mutating func set(node: DocumentNodeProtocol, for key: String) {
        attributes[key] = node.toDictionary()
    }

    public mutating func set(reference: DocumentReferenceProtocol, for key: String) {
        attributes[key] = [JSONDocumentReference.referenceKey: reference.referenceName]
    }

    public func integer(for key: String) -> Int? {
        guard let value = attributes[key] as? Int else {
            return nil
        }

        return value
    }

    public func string(for key: String) -> String? {
        guard let value = attributes[key] as? String else {
            return nil
        }

        return value
    }

    public func node(for key: String) -> DocumentNodeProtocol? {
        if reference(for: key) != nil {
            return nil
        }

        guard let value = attributes[key] as? [String: Any] else {
            return nil
        }

        return JSONDocumentNode(attributes: value)
    }

    public func list(for key: String) -> [DocumentNodeProtocol]? {
        guard let value = attributes[key] as? [[String: Any]] else {
            return nil
        }

        let list: [DocumentNodeProtocol] = value.map { return JSONDocumentNode(attributes: $0) }

        return list
    }

    public func reference(for key: String) -> DocumentReferenceProtocol? {
        guard let referenceDic = attributes[key] as? [String: String] else {
            return nil
        }

        guard let referenceName = referenceDic[JSONDocumentReference.referenceKey] else {
            return nil
        }

        return JSONDocumentReference(referenceName: referenceName)
    }

    public func allKeys() -> Set<String> {
        return attributes.keys.reduce(into: Set<String>()) { $0.insert($1) }
    }

    public func toDictionary() -> [String: Any] {
        return attributes
    }

    public mutating func remove(for key: String) {
        attributes.removeValue(forKey: key)
    }
}

public class JSONDocumentSerializer: DocumentBaseSerializer {

    override public init() {}

    override public func handleDeserialization(of data: Data) throws -> Any {
        let jsonObject = try JSONSerialization.jsonObject(with: data)

        guard let attributes = jsonObject as? [String: Any] else {
            throw DocumentSerializationError.unsupportedDeserializationFormat
        }

        return JSONDocumentNode(attributes: attributes)
    }

    override public func handleSerialization(of node: Any) throws -> Data {
        guard let jsonNode = node as? JSONDocumentNode else {
            throw DocumentSerializationError.unsupportedSerializationFormat
        }

        return try JSONSerialization.data(withJSONObject: jsonNode.attributes)
    }
}
