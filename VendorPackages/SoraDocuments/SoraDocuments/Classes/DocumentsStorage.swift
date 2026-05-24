/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

// MARK: Configuration

public struct DocumentsStorageConfiguration: DocumentsStorageConfigurationProtocol {
    public var encryptionAlgoritm: DocumentEncryptionAlgorithmProtocol?

    public var documentsURL: URL?

    public var excludeFromiCloudBackup: Bool

    public var serializer: SerializerProtocol

    public static func defaultConfiguration() -> DocumentsStorageConfiguration {
        let baseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first

        let rootSerializer = JSONDocumentSerializer()
        rootSerializer.chain(to: PNGImageSerializer())

        return DocumentsStorageConfiguration(encryptionAlgoritm: nil, documentsURL: baseURL,
                                             excludeFromiCloudBackup: true, serializer: rootSerializer)
    }
}

// MARK: Manager

public class DocumentsStorageManager: DocumentsStorageManagerProtocol {
    public static let shared = DocumentsStorageManager()

    private init() {}

    private var storages = [String: DocumentsStorage]()

    public var configuration: DocumentsStorageConfigurationProtocol =
        DocumentsStorageConfiguration.defaultConfiguration()

    public func documentsStorage(for name: String) -> DocumentsStorageProtocol {
        if let storage = storages[name] {
            return storage
        }

        let readWriteQueue = DispatchQueue(label: "documents.readwrite.queue.\(name)",
            qos: .default, attributes: .concurrent)

        let storage = DocumentsStorage(name: name, configuration: configuration, readWriteQueue: readWriteQueue)
        storages[name] = storage
        return storage
    }

    public func isOpenDocumentsStorage(for name: String) -> Bool {
        return storages[name] != nil
    }

    public func closeDocumentsStorage(for name: String) {
        storages.removeValue(forKey: name)
    }
}

// MARK: Storage

public enum DocumentsStorageError: Error {
    case invalidDocumentURL
    case documentSavingFailed
    case documentUnavailable
    case storageUnavailable
}

public class DocumentsStorage {

    public private(set) var name: String
    private let configuration: DocumentsStorageConfigurationProtocol

    private let readWriteQueue: DispatchQueue

    private lazy var readWriteFileManager = FileManager()

    private var observers = [String: DocumentsObserverWrapper]()

    public init(name: String, configuration: DocumentsStorageConfigurationProtocol, readWriteQueue: DispatchQueue) {
        self.name = name
        self.configuration = configuration
        self.readWriteQueue = readWriteQueue
    }

    fileprivate func readWriteOperation(with block: @escaping (FileManager) -> Void) {
        readWriteQueue.async(flags: .barrier) { block(self.readWriteFileManager) }
    }

    fileprivate func readOperation(with block: @escaping (FileManager) -> Void) {
        readWriteQueue.async { block(self.readWriteFileManager) }
    }

    fileprivate func register(subscriber: DocumentsObserverWrapper, for subscriptionId: String) {
        observers[subscriptionId] = subscriber
    }

    fileprivate func unregister(subscriptionId: String) {
        observers.removeValue(forKey: subscriptionId)
    }

    fileprivate func unregisterSafely(subscriptionIds: Set<String>) {
        readWriteOperation { _ in
            for subscriptionId in subscriptionIds {
                self.observers.removeValue(forKey: subscriptionId)
            }
        }
    }

    public func fetchSubscriptionIds(runInCompletion queue: DispatchQueue, block: @escaping (Set<String>) -> Void) {
        readOperation { _ in
            let keys = self.observers.keys.reduce(into: Set<String>()) { $0.insert($1) }

            queue.async {
                block(keys)
            }
        }
    }

    private func notifyObservers(for change: DocumentsStorageChanges, in filename: String) {
        for (_, wrapper) in observers {
            let observer = wrapper.observer

            if observer.changes.isDisjoint(with: change) {
                continue
            }

            if wrapper.queryCondition?(filename) == false {
                continue
            }

            let queue = observer.queue ?? .main
            queue.async { observer.block(filename, change) }
        }
    }

    fileprivate func encode(node: Any) throws -> Data {
        var data = try configuration.serializer.serialize(node: node)

        if let encryptionAlgorithm = configuration.encryptionAlgoritm {
            data = try encryptionAlgorithm.encrypt(data: data)
        }

        return data
    }

    fileprivate func decode(data: Data) throws -> Any {
        var decryptedData = data

        if let encryptionAlgorithm = configuration.encryptionAlgoritm {
            decryptedData = try encryptionAlgorithm.decrypt(data: data)
        }

        return try configuration.serializer.deserialize(data: decryptedData)
    }

    fileprivate func generateFilename() -> String {
        return UUID().uuidString
    }

    fileprivate func documentsURL(with fileManager: FileManager) -> URL? {
        guard var storageURL = configuration.documentsURL?.appendingPathComponent(name) else {
            return nil
        }

        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: storageURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return storageURL
        }

        do {
            try fileManager.createDirectory(at: storageURL, withIntermediateDirectories: true)

            var resources = URLResourceValues()
            resources.isExcludedFromBackup = configuration.excludeFromiCloudBackup
            try storageURL.setResourceValues(resources)

            return storageURL
        } catch {
            return nil
        }
    }

    fileprivate func urlFor(filename: String, with fileManager: FileManager) -> URL? {
        guard let storageURL = documentsURL(with: fileManager) else {
            return nil
        }

        return storageURL.appendingPathComponent(filename)
    }

}

extension DocumentsStorage: DocumentsStorageProtocol {
    public func create(_ node: Any, runCompletionIn queue: DispatchQueue,
                       with block: @escaping (String?, Error?) -> Void) {
        readWriteOperation { fileManager in
            let name = self.generateFilename()

            guard let fileURL = self.urlFor(filename: name, with: fileManager) else {
                queue.async {
                    block(nil, DocumentsStorageError.invalidDocumentURL)
                }
                return
            }

            do {
                let data = try self.encode(node: node)

                if fileManager.createFile(atPath: fileURL.path, contents: data) {
                    queue.async {
                        block(name, nil)
                    }

                    self.notifyObservers(for: .created, in: name)
                } else {
                    queue.async {
                        block(nil, DocumentsStorageError.documentSavingFailed)
                    }
                }

            } catch {
                queue.async {
                    block(nil, error)
                }
            }
        }
    }

    public func save(document: DocumentProtocol, runCompletionIn queue: DispatchQueue,
                     with block: @escaping (Error?) -> Void) {
        readWriteOperation { fileManager in
            guard let fileURL = self.urlFor(filename: document.name, with: fileManager) else {
                queue.async {
                    block(DocumentsStorageError.invalidDocumentURL)
                }
                return
            }

            do {

                let data = try self.encode(node: document.rootNode)
                try data.write(to: fileURL)
                queue.async { block(nil) }

                self.notifyObservers(for: .updated, in: document.name)

            } catch {
                queue.async { block(error) }
            }
        }
    }

    public func removeDocument(with name: String, runCompletionIn queue: DispatchQueue,
                               with block: @escaping (Error?) -> Void) {
        readWriteOperation { fileManager in
            guard let fileURL = self.urlFor(filename: name, with: fileManager) else {
                queue.async {
                    block(DocumentsStorageError.invalidDocumentURL)
                }
                return
            }

            do {

                try fileManager.removeItem(at: fileURL)
                queue.async { block(nil) }

                self.notifyObservers(for: .removed, in: name)

            } catch {
                queue.async { block(error) }
            }
        }
    }

    public func queryAll() -> DocumentsQueryProtocol {
        return DocumentsQuery(storage: self, fetchCondition: { _ in return true })
    }

    public func query(by name: String) -> DocumentsQueryProtocol {
        return DocumentsQuery(storage: self, fetchCondition: { return $0 == name })
    }
}

// MARK: Query

private class DocumentsQuery {
    private weak var _storage: DocumentsStorage?

    public var storage: DocumentsStorageProtocol? {
        return _storage
    }

    private var fetchCondition: (String) -> Bool

    private var subscribers = Set<String>()

    deinit {
        _storage?.unregisterSafely(subscriptionIds: subscribers)
    }

    init(storage: DocumentsStorage, fetchCondition: @escaping (String) -> Bool) {
        _storage = storage
        self.fetchCondition = fetchCondition
    }

    private func readDocumentFrom(url: URL, using fileManager: FileManager) throws -> DocumentProtocol {
        guard let data = fileManager.contents(atPath: url.path) else {
            throw DocumentsStorageError.documentUnavailable
        }

        guard let node = try _storage?.decode(data: data) else {
            throw DocumentsStorageError.documentUnavailable
        }

        return Document(name: url.lastPathComponent, storage: storage, rootNode: node)
    }

    private func generateSubscriptionId() -> String {
        return UUID().uuidString
    }
}

extension DocumentsQuery: DocumentsQueryProtocol {
    public func fetchFirst(runCompletionIn queue: DispatchQueue,
                           with block: @escaping (DocumentProtocol?, Error?) -> Void) {
        guard let existingStorage = _storage else {
            queue.async { block(nil, DocumentsStorageError.storageUnavailable) }
            return
        }

        existingStorage.readOperation { (fileManager) in
            guard let documentsURL = self._storage?.documentsURL(with: fileManager) else {
                queue.async { block(nil, DocumentsStorageError.invalidDocumentURL) }
                return
            }

            let options: FileManager.DirectoryEnumerationOptions =
                [.skipsHiddenFiles, .skipsSubdirectoryDescendants, .skipsPackageDescendants]
            let enumerator = fileManager.enumerator(at: documentsURL,
                                                    includingPropertiesForKeys: [.isDirectoryKey],
                                                    options: options)

            guard let documentsEnumerator = enumerator else {
                queue.async { block(nil, DocumentsStorageError.invalidDocumentURL) }
                return
            }

            var document: DocumentProtocol!

            for case let documentURL as URL in documentsEnumerator {
                guard
                    let resourceValues = try? documentURL.resourceValues(forKeys: [.isDirectoryKey]),
                    resourceValues.isDirectory == false else {

                        continue
                }

                if !self.fetchCondition(documentURL.lastPathComponent) {
                    continue
                }

                document = try? self.readDocumentFrom(url: documentURL, using: fileManager)

                if document != nil {
                    break
                }
            }

            queue.async { block(document, nil) }
        }
    }

    public func fetchAll(runCompletionIn queue: DispatchQueue,
                         with block: @escaping ([DocumentProtocol]?, Error?) -> Void) {
        guard let existingStorage = _storage else {
            queue.async { block(nil, DocumentsStorageError.storageUnavailable) }
            return
        }

        existingStorage.readOperation { fileManager in
            guard let documentsURL = self._storage?.documentsURL(with: fileManager) else {
                queue.async { block(nil, DocumentsStorageError.invalidDocumentURL) }
                return
            }

            let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles,
                                                                    .skipsSubdirectoryDescendants,
                                                                    .skipsPackageDescendants]
            let enumerator = fileManager.enumerator(at: documentsURL,
                                                    includingPropertiesForKeys: [.isDirectoryKey],
                                                    options: options)

            guard let documentsEnumerator = enumerator else {
                queue.async { block(nil, DocumentsStorageError.invalidDocumentURL) }
                return
            }

            var documents = [DocumentProtocol]()

            for case let documentURL as URL in documentsEnumerator {
                guard
                    let resourceValues = try? documentURL.resourceValues(forKeys: [.isDirectoryKey]),
                    resourceValues.isDirectory == false else {

                        continue
                }

                if !self.fetchCondition(documentURL.lastPathComponent) {
                    continue
                }

                if let document = try? self.readDocumentFrom(url: documentURL, using: fileManager) {
                    documents.append(document)
                }
            }

            queue.async { block(documents, nil) }
        }
    }

    func subscribe(observer: DocumentsObserverProtocol) -> String {
        let subscriptionId = generateSubscriptionId()

        _storage?.readWriteOperation { [weak self] _ in
            self?.subscribers.insert(subscriptionId)

            let wrapper = DocumentsObserverWrapper(observer: observer, queryCondition: self?.fetchCondition)
            self?._storage?.register(subscriber: wrapper, for: subscriptionId)
        }

        return subscriptionId
    }

    func unsubscribe(subscriptionId: String) {
        _storage?.readWriteOperation { [weak self] _ in
            self?.subscribers.remove(subscriptionId)
            self?._storage?.unregister(subscriptionId: subscriptionId)
        }
    }
}

// MARK: Document

private struct Document: DocumentProtocol {
    private(set) var name: String
    private(set) var storage: DocumentsStorageProtocol?
    var rootNode: Any
}

private struct DocumentsObserverWrapper {
    var observer: DocumentsObserverProtocol
    var queryCondition: ((String) -> Bool)?
}
