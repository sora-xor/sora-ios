/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

enum JSONDocumentKeyPathElement {
    case list(index: Int)
    case dictionary(key: String)
}

enum JSONDocumentKeyPathError: Error {
    case unexpectedVertexType
    case invalidListIndex
}

extension JSONDocumentNode {
    public func jsonNode(bySetting leafNode: JSONDocumentNode, for keyPath: [String]) throws -> JSONDocumentNode {
        let documentKeyPath: [JSONDocumentKeyPathElement] = keyPath.map { return .dictionary(key: $0) }

        return try jsonNode(bySetting: leafNode, for: documentKeyPath)
    }

    public func jsonNode(bySetting leafReference: JSONDocumentReference,
                         for keyPath: [String]) throws -> JSONDocumentNode {
        let documentKeyPath: [JSONDocumentKeyPathElement] = keyPath.map { return .dictionary(key: $0) }

        return try jsonNode(bySetting: leafReference, for: documentKeyPath)
    }

    func jsonNode(bySetting string: String, for keyPath: [JSONDocumentKeyPathElement]) throws -> JSONDocumentNode {
        return try JSONDocumentNode.jsonNode(bySetting: string, in: self, for: keyPath)
    }

    func jsonNode(bySetting integer: Int, for keyPath: [JSONDocumentKeyPathElement]) throws -> JSONDocumentNode {
        return try JSONDocumentNode.jsonNode(bySetting: integer, in: self, for: keyPath)
    }

    func jsonNode(bySetting reference: JSONDocumentReference,
                  for keyPath: [JSONDocumentKeyPathElement]) throws -> JSONDocumentNode {
        return try JSONDocumentNode.jsonNode(bySetting: reference, in: self, for: keyPath)
    }

    func jsonNode(bySetting node: JSONDocumentNode,
                  for keyPath: [JSONDocumentKeyPathElement]) throws -> JSONDocumentNode {
        return try JSONDocumentNode.jsonNode(bySetting: node, in: self, for: keyPath)
    }

    func jsonNode(bySetting list: [JSONDocumentNode],
                  for keyPath: [JSONDocumentKeyPathElement]) throws -> JSONDocumentNode {
        return try JSONDocumentNode.jsonNode(bySetting: list, in: self, for: keyPath)
    }

    private static func jsonList(bySetting object: Any, in list: [JSONDocumentNode],
                                 for keyPath: [JSONDocumentKeyPathElement]) throws -> [JSONDocumentNode] {
        if keyPath.count == 0 {
            return list
        }

        guard case .list(let index) = keyPath[0] else {
            throw JSONDocumentKeyPathError.unexpectedVertexType
        }

        guard index <= list.count else {
            throw JSONDocumentKeyPathError.invalidListIndex
        }

        var newList = list

        guard keyPath.count == 1 else {

            if index < list.count {
                let nextNode = try jsonNode(bySetting: object, in: list[index], for: Array(keyPath[1...]))
                newList[index] = nextNode
            } else {
                let nextNode = try jsonNode(bySetting: object, in: JSONDocumentNode(), for: Array(keyPath[1...]))
                newList.append(nextNode)
            }

            return newList
        }

        guard let insertingNode = object as? JSONDocumentNode else {
            throw JSONDocumentKeyPathError.unexpectedVertexType
        }

        if index < list.count {
            newList[index] = insertingNode
        } else {
            newList.append(insertingNode)
        }

        return newList
    }

    private static func jsonNode(bySetting object: Any, in node: JSONDocumentNode,
                                 for keyPath: [JSONDocumentKeyPathElement]) throws -> JSONDocumentNode {

        if keyPath.count == 0 {
            return node
        }

        guard case .dictionary(let key) = keyPath[0] else {
            throw JSONDocumentKeyPathError.unexpectedVertexType
        }

        var newNode = node

        guard keyPath.count == 1 else {

            if case .dictionary = keyPath[1] {
                var nextNode = node.node(for: key) as? JSONDocumentNode ?? JSONDocumentNode()
                nextNode = try jsonNode(bySetting: object, in: nextNode, for: Array(keyPath[1...]))
                newNode.set(node: nextNode, for: key)
            }

            if case .list = keyPath[1] {
                var nextList = node.list(for: key) as? [JSONDocumentNode] ?? [JSONDocumentNode]()
                nextList = try jsonList(bySetting: object, in: nextList, for: Array(keyPath[1...]))
                newNode.set(list: nextList, for: key)
            }

            return newNode
        }

        if let intValue = object as? Int {
            newNode.set(integer: intValue, for: key)
        } else if let stringValue = object as? String {
            newNode.set(string: stringValue, for: key)
        } else if let reference = object as? JSONDocumentReference {
            newNode.set(reference: reference, for: key)
        } else if let node = object as? JSONDocumentNode {
            newNode.set(node: node, for: key)
        } else if let list = object as? [JSONDocumentNode] {
            newNode.set(list: list, for: key)
        }

        return newNode
    }
}
