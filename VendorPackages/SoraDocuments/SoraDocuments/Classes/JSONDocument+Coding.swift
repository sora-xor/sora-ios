/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

enum JSONDocumentNodeCodingError: Error {
    case invalidEncodingKey
    case invalidDecodingKey
}

extension JSONDocumentNode: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DocumentDynamicCodingKey.self)
        try JSONDocumentNode.encode(node: self, to: &container)
    }

    private static func encode(node: JSONDocumentNode,
                               to container: inout KeyedEncodingContainer<DocumentDynamicCodingKey>) throws {
        let keys = node.allKeys()

        for key in keys {
            if let intValue = node.integer(for: key) {
                try _encode(object: intValue, for: key, to: &container)
            } else if let stringValue = node.string(for: key) {
                try _encode(object: stringValue, for: key, to: &container)
            } else if let reference = node.reference(for: key) as? JSONDocumentReference {
                try _encode(object: reference, for: key, to: &container)
            } else if let nestedNode = node.node(for: key) as? JSONDocumentNode {
                try _encode(object: nestedNode, for: key, to: &container)
            } else if let list = node.list(for: key) as? [JSONDocumentNode] {
                try _encode(object: list, for: key, to: &container)
            }
        }
    }
}

extension JSONDocumentNode: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DocumentDynamicCodingKey.self)

        for codingKey in container.allKeys {
            if let intValue = try? container.decode(Int.self, forKey: codingKey) {
                set(integer: intValue, for: codingKey.stringValue)
            } else if let stringValue = try? container.decode(String.self, forKey: codingKey) {
                set(string: stringValue, for: codingKey.stringValue)
            } else if let reference = try? container.decode(JSONDocumentReference.self, forKey: codingKey) {
                set(reference: reference, for: codingKey.stringValue)
            } else if let node = try? container.decode(JSONDocumentNode.self, forKey: codingKey) {
                set(node: node, for: codingKey.stringValue)
            } else if let list = try? container.decode([JSONDocumentNode].self, forKey: codingKey) {
                set(list: list, for: codingKey.stringValue)
            }
        }
    }
}

extension JSONDocumentReference: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DocumentDynamicCodingKey.self)
        try _encode(object: referenceName, for: JSONDocumentReference.referenceKey, to: &container)
    }
}

extension JSONDocumentReference: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DocumentDynamicCodingKey.self)

        guard let codingKey = DocumentDynamicCodingKey(stringValue: JSONDocumentReference.referenceKey) else {
            throw JSONDocumentNodeCodingError.invalidDecodingKey
        }

        referenceName = try container.decode(String.self, forKey: codingKey)
    }
}

private func _encode<T>(object: T, for key: String,
                        to container: inout KeyedEncodingContainer<DocumentDynamicCodingKey>) throws where T: Encodable {
    guard let codingKey = DocumentDynamicCodingKey(stringValue: key) else {
        throw JSONDocumentNodeCodingError.invalidEncodingKey
    }

    try container.encode(object, forKey: codingKey)
}
