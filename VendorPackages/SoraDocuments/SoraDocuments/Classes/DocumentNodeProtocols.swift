/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public protocol DocumentReferenceProtocol {
    var referenceName: String { get }

    func documentQuery(in storage: DocumentsStorageProtocol) -> DocumentsQueryProtocol
}

public protocol DocumentNodeProtocol {
    mutating func set(integer: Int, for key: String)
    mutating func set(string: String, for key: String)
    mutating func set(node: DocumentNodeProtocol, for key: String)
    mutating func set(list: [DocumentNodeProtocol], for key: String)
    mutating func set(reference: DocumentReferenceProtocol, for key: String)

    func integer(for key: String) -> Int?
    func string(for key: String) -> String?
    func node(for key: String) -> DocumentNodeProtocol?
    func list(for key: String) -> [DocumentNodeProtocol]?
    func reference(for key: String) -> DocumentReferenceProtocol?

    func allKeys() -> Set<String>

    func toDictionary() -> [String: Any]

    mutating func remove(for key: String)
}

public protocol DocumentNodeVisitorProtocol {
    func visit(value: Int)
    func visit(value: String)
    func visit(reference: DocumentReferenceProtocol)
    func visit(node: DocumentNodeProtocol)
    func visit(list: [DocumentNodeProtocol])
}

extension DocumentNodeProtocol {
    public func accept(visitor: DocumentNodeVisitorProtocol, for key: String) {
        if let value = integer(for: key) {
            visitor.visit(value: value)
            return
        }

        if let value = string(for: key) {
            visitor.visit(value: value)
            return
        }

        if let value = reference(for: key) {
            visitor.visit(reference: value)
            return
        }

        if let value = node(for: key) {
            visitor.visit(node: value)
        }

        if let value = list(for: key) {
            visitor.visit(list: value)
        }
    }
}
