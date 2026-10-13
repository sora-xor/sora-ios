/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public protocol DocumentsStorageConfigurationProtocol {
    var encryptionAlgoritm: DocumentEncryptionAlgorithmProtocol? { get }
    var documentsURL: URL? { get }
    var excludeFromiCloudBackup: Bool { get }
    var serializer: SerializerProtocol { get }
}

public protocol DocumentsStorageManagerProtocol: class {
    var configuration: DocumentsStorageConfigurationProtocol { get set }
    func isOpenDocumentsStorage(for name: String) -> Bool
    func documentsStorage(for name: String) -> DocumentsStorageProtocol
    func closeDocumentsStorage(for name: String)
}

public protocol DocumentsStorageProtocol: class {
    var name: String { get }

    func create(_ node: Any, runCompletionIn queue: DispatchQueue, with block: @escaping (String?, Error?) -> Void)
    func save(document: DocumentProtocol, runCompletionIn queue: DispatchQueue, with block: @escaping (Error?) -> Void)
    func removeDocument(with name: String, runCompletionIn queue: DispatchQueue, with block: @escaping (Error?) -> Void)

    func queryAll() -> DocumentsQueryProtocol
    func query(by name: String) -> DocumentsQueryProtocol
}

public protocol DocumentEncryptionAlgorithmProtocol: class {
    func encrypt(data: Data) throws -> Data
    func decrypt(data: Data) throws -> Data
}

public struct DocumentsStorageChanges: OptionSet {
    public static let created = DocumentsStorageChanges(rawValue: 1 << 0)
    public static let updated = DocumentsStorageChanges(rawValue: 1 << 1)
    public static let removed = DocumentsStorageChanges(rawValue: 1 << 2)
    public static let all: DocumentsStorageChanges = [.created, .updated, .removed]

    public typealias RawValue = UInt8

    public var rawValue: UInt8

    public init(rawValue: DocumentsStorageChanges.RawValue) {
        self.rawValue = rawValue
    }

    public mutating func formUnion(_ other: DocumentsStorageChanges) {
        rawValue |= other.rawValue
    }

    public mutating func formIntersection(_ other: DocumentsStorageChanges) {
        rawValue &= other.rawValue
    }

    public mutating func formSymmetricDifference(_ other: DocumentsStorageChanges) {
        rawValue ^= other.rawValue
    }
}

public typealias DocumentsStorageSubscriptionBlock = (String, DocumentsStorageChanges) -> Void

public protocol DocumentsQueryProtocol: class {
    var storage: DocumentsStorageProtocol? { get }

    func fetchFirst(runCompletionIn queue: DispatchQueue, with block: @escaping (DocumentProtocol?, Error?) -> Void)
    func fetchAll(runCompletionIn queue: DispatchQueue, with block: @escaping ([DocumentProtocol]?, Error?) -> Void)

    func subscribe(observer: DocumentsObserverProtocol) -> String
    func unsubscribe(subscriptionId: String)
}

public protocol DocumentsObserverProtocol {
    var block: DocumentsStorageSubscriptionBlock { get }
    var queue: DispatchQueue? { get }
    var changes: DocumentsStorageChanges { get }
}

public enum DocumentSerializationError: Error {
    case unsupportedSerializationFormat
    case unsupportedDeserializationFormat
}

public protocol SerializerProtocol: class {
    func deserialize(data: Data) throws -> Any
    func serialize(node: Any) throws -> Data
}

public protocol ChainableSerializerProtocol: SerializerProtocol {
    var next: ChainableSerializerProtocol? { get }
    func chain(to serializer: ChainableSerializerProtocol) -> ChainableSerializerProtocol
}

public protocol DocumentProtocol {
    var name: String { get }
    var storage: DocumentsStorageProtocol? { get }
    var rootNode: Any { get set }
}
