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

import CryptoKit
import Foundation
import RobinHood
import sorawallet

typealias PIHistoryBlockHashResolver =
    @Sendable (Int) async throws -> String?

enum PIHistoryCheckpointValidator {
    private static let maximumRecords = 100
    private static let maximumConcurrentRPCChecks = 8

    static func validate(
        _ elements: [PIHistoryElement],
        expectedAddress: String,
        finalizedCheckpoint: Int,
        indexedCheckpointHash: String? = nil,
        canonicalBlockHash: @escaping PIHistoryBlockHashResolver
    ) async throws {
        guard
            !expectedAddress.isEmpty,
            expectedAddress ==
                expectedAddress.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
            expectedAddress.utf8.count <= 512,
            finalizedCheckpoint > 0,
            elements.count <= maximumRecords
        else {
            throw PIIndexerError.invalidResponse
        }

        var expectedHashesByHeight: [Int: String] = [:]
        if let indexedCheckpointHash {
            guard
                let normalizedCheckpointHash =
                    normalizedBlockHash(indexedCheckpointHash)
            else {
                throw PIIndexerError.invalidChainIdentity
            }
            expectedHashesByHeight[finalizedCheckpoint] =
                normalizedCheckpointHash
        }
        var historyIdentifiers = Set<String>()
        for element in elements {
            guard
                executionSucceeded(element.execution) != nil,
                isNonNegativeIntegerQuantity(element.networkFee),
                let timestamp = element.timestamp,
                timestamp >= 0,
                element.address == expectedAddress ||
                    element.dataFrom == expectedAddress ||
                    element.dataTo == expectedAddress,
                let canonicalIdentifier = canonicalHistoryIdentifier(
                    element.id
                ),
                historyIdentifiers.insert(canonicalIdentifier).inserted,
                let height = element.blockHeight,
                height >= 0,
                height <= finalizedCheckpoint,
                let rawHash = element.blockHash,
                let blockHash = normalizedBlockHash(rawHash)
            else {
                throw PIIndexerError.invalidChainIdentity
            }
            if let existing = expectedHashesByHeight[height] {
                guard existing == blockHash else {
                    throw PIIndexerError.invalidChainIdentity
                }
            } else {
                expectedHashesByHeight[height] = blockHash
            }
        }

        let checkpoints = expectedHashesByHeight.sorted {
            $0.key < $1.key
        }
        for start in stride(
            from: 0,
            to: checkpoints.count,
            by: maximumConcurrentRPCChecks
        ) {
            let end = min(
                start + maximumConcurrentRPCChecks,
                checkpoints.count
            )
            let batch = Array(checkpoints[start ..< end])
            try await withThrowingTaskGroup(of: Void.self) { group in
                for (height, expectedHash) in batch {
                    group.addTask {
                        guard
                            let actual = try await canonicalBlockHash(height),
                            Self.normalizedBlockHash(actual) ==
                                expectedHash
                        else {
                            throw PIIndexerError.invalidChainIdentity
                        }
                    }
                }
                try await group.waitForAll()
            }
        }
    }

    static func normalizedTransactionHash(
        _ value: String
    ) -> String? {
        normalizedHash(value, prefixRequired: false)
    }

    static func normalizedBlockHash(
        _ value: String
    ) -> String? {
        normalizedHash(value, prefixRequired: true)
    }

    static func executionSucceeded(_ value: PIJSONValue?) -> Bool? {
        guard
            let value,
            case let .object(object) = value,
            let rawSuccess = object["success"],
            case let .bool(success) = rawSuccess
        else {
            return nil
        }
        return success
    }

    static func isNonNegativeIntegerQuantity(_ value: PIQuantity?) -> Bool {
        guard let value else {
            return false
        }
        return value.rawValue.range(
            of: #"^(?:0|[1-9][0-9]*)$"#,
            options: .regularExpression
        ) != nil
    }

    /// General PI history includes bounded synthetic identifiers for indexed
    /// events which do not have their own extrinsic hash (for example an
    /// incoming bridge mint). Pending reconciliation uses the stricter
    /// `normalizedTransactionHash` path instead.
    static func isValidHistoryIdentifier(_ value: String) -> Bool {
        canonicalHistoryIdentifier(value) != nil
    }

    /// Canonicalizes genuine transaction hashes for duplicate/repeated-page
    /// checks while preserving PI's bounded synthetic event identifiers.
    static func canonicalHistoryIdentifier(_ value: String) -> String? {
        guard
            !value.isEmpty,
            value == value.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            value.utf8.count <= 512,
            !value.unicodeScalars.contains(where: {
                CharacterSet.controlCharacters.contains($0)
            })
        else {
            return nil
        }
        let hashPayload = value.hasPrefix("0x") || value.hasPrefix("0X")
            ? value.dropFirst(2)
            : value[...]
        if
            hashPayload.count == 64,
            hashPayload.unicodeScalars.allSatisfy({
                (48 ... 57).contains($0.value) ||
                    (65 ... 70).contains($0.value) ||
                    (97 ... 102).contains($0.value)
            })
        {
            // Hash-shaped identifiers are never reinterpreted as synthetic
            // IDs. In particular, the all-zero transaction sentinel remains
            // invalid for both general history and pending reconciliation.
            return normalizedTransactionHash(value)
        }
        return value
    }

    private static func normalizedHash(
        _ value: String,
        prefixRequired: Bool
    ) -> String? {
        guard value == value.trimmingCharacters(in: .whitespacesAndNewlines)
        else {
            return nil
        }
        let payload: Substring
        if value.hasPrefix("0x") || value.hasPrefix("0X") {
            payload = value.dropFirst(2)
        } else {
            guard !prefixRequired else {
                return nil
            }
            payload = value[...]
        }
        guard
            payload.count == 64,
            payload.unicodeScalars.allSatisfy({
                (48 ... 57).contains($0.value) ||
                    (65 ... 70).contains($0.value) ||
                    (97 ... 102).contains($0.value)
            }),
            payload.contains(where: { $0 != "0" })
        else {
            return nil
        }
        return "0x\(payload.lowercased())"
    }
}

enum PIHistoryPageValidator {
    static func validate(
        _ response: PIConnection<PIHistoryElement>,
        hasPriorPage: Bool,
        pageSize: Int
    ) throws -> [PIHistoryElement] {
        let values = response.values
        guard
            (1 ... 100).contains(pageSize),
            response.totalCount >= 0,
            values.count <= pageSize,
            (response.nodes != nil) != (response.edges != nil),
            response.pageInfo.hasPreviousPage == hasPriorPage,
            response.pageInfo.hasNextPage
                ? (!values.isEmpty && values.count < response.totalCount)
                : (hasPriorPage || values.count == response.totalCount)
        else {
            throw PIIndexerError.invalidResponse
        }
        let identifiers = values.compactMap {
            PIHistoryCheckpointValidator.canonicalHistoryIdentifier($0.id)
        }
        guard
            identifiers.count == values.count,
            Set(identifiers).count == values.count
        else {
            throw PIIndexerError.invalidResponse
        }
        return values
    }
}

/// Stores only history pages that already passed live PI identity, finalized
/// checkpoint, and canonical SORA2 RPC hash validation. Raw GraphQL cache
/// entries are never promoted to this cache until those checks complete.
actor PIValidatedHistoryCache {
    static let shared = PIValidatedHistoryCache()

    struct Entry: Codable, Equatable {
        let schemaVersion: Int
        let savedAt: Date
        let address: String
        let count: Int
        let page: Int
        let finalizedCheckpoint: Int
        let indexedCheckpointHash: String?
        let endCursor: String?
        let endReached: Bool
        let elements: [PIHistoryElement]
    }

    private struct Envelope: Codable {
        let entry: Entry
        let digest: String
    }

    private struct CacheFile {
        let url: URL
        let size: Int
        let modifiedAt: Date
    }

    private static let schemaVersion = 1
    private static let maximumAge: TimeInterval = 24 * 60 * 60
    private static let maximumEntryBytes = 4 * 1_024 * 1_024
    private static let maximumTotalBytes = 32 * 1_024 * 1_024
    private static let maximumEntries = 64

    private let fileManager: FileManager
    private let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        baseURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        let base = baseURL ?? ((try? fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.temporaryDirectory)
        directory = base.appendingPathComponent(
            "PIValidatedHistoryV1",
            isDirectory: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder
        decoder = JSONDecoder()
        try? fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    func save(
        address: String,
        count: Int,
        page: Int,
        finalizedCheckpoint: Int,
        indexedCheckpointHash: String?,
        endCursor: String?,
        endReached: Bool,
        elements: [PIHistoryElement],
        savedAt: Date = Date()
    ) {
        guard isUsableDirectory() else {
            return
        }
        let entry = Entry(
            schemaVersion: Self.schemaVersion,
            savedAt: savedAt,
            address: address,
            count: count,
            page: page,
            finalizedCheckpoint: finalizedCheckpoint,
            indexedCheckpointHash: indexedCheckpointHash,
            endCursor: endCursor,
            endReached: endReached,
            elements: elements
        )
        guard
            Self.isStructurallyValid(
                entry,
                address: address,
                count: count,
                page: page,
                now: savedAt
            ),
            let entryData = try? encoder.encode(entry)
        else {
            return
        }
        let envelope = Envelope(
            entry: entry,
            digest: Self.digest(entryData)
        )
        guard
            let data = try? encoder.encode(envelope),
            data.count <= Self.maximumEntryBytes,
            isSafeDestination(
                url(address: address, count: count, page: page)
            )
        else {
            return
        }
        do {
            try data.write(
                to: url(address: address, count: count, page: page),
                options: [
                    .atomic,
                    .completeFileProtectionUntilFirstUserAuthentication,
                ]
            )
            prune()
        } catch {
            // Cache failure never changes the qualified live history result.
        }
    }

    func load(
        address: String,
        count: Int,
        page: Int,
        now: Date = Date()
    ) -> Entry? {
        let fileURL = url(address: address, count: count, page: page)
        guard isUsableDirectory() else {
            return nil
        }
        guard
            let values = try? fileURL.resourceValues(forKeys: [
                .fileSizeKey,
                .isRegularFileKey,
                .isSymbolicLinkKey,
            ]),
            values.isRegularFile == true,
            values.isSymbolicLink != true,
            let fileSize = values.fileSize,
            fileSize >= 0,
            fileSize <= Self.maximumEntryBytes,
            let data = try? Data(contentsOf: fileURL),
            data.count <= Self.maximumEntryBytes,
            let envelope = try? decoder.decode(
                Envelope.self,
                from: data
            ),
            let entryData = try? encoder.encode(envelope.entry),
            Self.digest(entryData) == envelope.digest,
            Self.isStructurallyValid(
                envelope.entry,
                address: address,
                count: count,
                page: page,
                now: now
            )
        else {
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
        return envelope.entry
    }

    private func url(
        address: String,
        count: Int,
        page: Int
    ) -> URL {
        let key = "\(address.utf8.count):\(address)|\(count)|\(page)"
        let filename = Self.digest(Data(key.utf8)) + ".json"
        return directory.appendingPathComponent(filename)
    }

    private func isUsableDirectory() -> Bool {
        guard
            let values = try? directory.resourceValues(forKeys: [
                .isDirectoryKey,
                .isSymbolicLinkKey,
            ])
        else {
            return false
        }
        return values.isDirectory == true && values.isSymbolicLink != true
    }

    private func isSafeDestination(_ destination: URL) -> Bool {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [
                .isRegularFileKey,
                .isSymbolicLinkKey,
            ],
            options: []
        ) else {
            return false
        }
        guard let existing = entries.first(where: {
            $0.lastPathComponent == destination.lastPathComponent
        }) else {
            return true
        }
        guard let values = try? existing.resourceValues(forKeys: [
            .isRegularFileKey,
            .isSymbolicLinkKey,
        ]) else {
            return false
        }
        return values.isRegularFile == true && values.isSymbolicLink != true
    }

    private func prune() {
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .contentModificationDateKey,
        ]
        let files = ((try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        )) ?? []).compactMap { url -> CacheFile? in
            guard
                let values = try? url.resourceValues(forKeys: keys),
                values.isRegularFile == true,
                values.isSymbolicLink != true,
                let size = values.fileSize,
                size >= 0
            else {
                return nil
            }
            return CacheFile(
                url: url,
                size: size,
                modifiedAt: values.contentModificationDate ??
                    .distantPast
            )
        }.sorted { $0.modifiedAt < $1.modifiedAt }

        var remainingCount = files.count
        var remainingBytes = files.reduce(0) { partial, file in
            let (sum, overflow) =
                partial.addingReportingOverflow(file.size)
            return overflow ? Int.max : sum
        }
        for file in files where
            remainingCount > Self.maximumEntries ||
            remainingBytes > Self.maximumTotalBytes
        {
            do {
                try fileManager.removeItem(at: file.url)
                remainingCount -= 1
                remainingBytes =
                    remainingBytes == Int.max
                    ? Int.max
                    : max(0, remainingBytes - file.size)
            } catch {
                // Keep accounting unchanged when removal failed.
            }
        }
    }

    private static func isStructurallyValid(
        _ entry: Entry,
        address: String,
        count: Int,
        page: Int,
        now: Date
    ) -> Bool {
        let age = now.timeIntervalSince(entry.savedAt)
        guard
            entry.schemaVersion == schemaVersion,
            entry.address == address,
            entry.count == count,
            entry.page == page,
            (1 ... 100).contains(count),
            (1 ... 20).contains(page),
            entry.finalizedCheckpoint > 0,
            age >= 0,
            age <= maximumAge,
            entry.elements.count <= count,
            (entry.endCursor?.utf8.count ?? 0) <= 4_096,
            entry.endCursor == nil ||
                !(entry.endCursor?.isEmpty ?? true),
            entry.endReached ||
                (!entry.elements.isEmpty && entry.endCursor != nil)
        else {
            return false
        }

        if let checkpointHash = entry.indexedCheckpointHash,
           PIHistoryCheckpointValidator.normalizedBlockHash(
               checkpointHash
           ) == nil {
            return false
        }

        var hashesByHeight: [Int: String] = [:]
        var historyIdentifiers = Set<String>()
        for element in entry.elements {
            guard
                PIHistoryCheckpointValidator.executionSucceeded(
                    element.execution
                ) != nil,
                PIHistoryCheckpointValidator.isNonNegativeIntegerQuantity(
                    element.networkFee
                ),
                let timestamp = element.timestamp,
                timestamp >= 0,
                element.address == address ||
                    element.dataFrom == address ||
                    element.dataTo == address,
                let canonicalIdentifier = PIHistoryCheckpointValidator
                    .canonicalHistoryIdentifier(
                    element.id
                ),
                historyIdentifiers.insert(canonicalIdentifier).inserted,
                let height = element.blockHeight,
                height >= 0,
                height <= entry.finalizedCheckpoint,
                let blockHash = element.blockHash.flatMap(
                    PIHistoryCheckpointValidator
                        .normalizedBlockHash
                )
            else {
                return false
            }
            if let existing = hashesByHeight[height],
               existing != blockHash {
                return false
            }
            hashesByHeight[height] = blockHash
        }
        if
            let checkpointHash = entry.indexedCheckpointHash.flatMap(
                PIHistoryCheckpointValidator.normalizedBlockHash
            ),
            let historyHash =
                hashesByHeight[entry.finalizedCheckpoint],
            historyHash != checkpointHash
        {
            return false
        }
        return true
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

private enum PISoraHistoryBlockResolver {
    static func canonicalBlockHash(
        at height: Int
    ) async throws -> String? {
        guard
            height >= 0,
            let engine = ChainRegistryFacade.sharedRegistry
                .getConnection(for: Chain.sora.genesisHash())
        else {
            throw PIIndexerError.invalidChainIdentity
        }
        return try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<String?, Swift.Error>) in
            do {
                _ = try engine.callMethod(
                    RPCMethod.getBlockHash,
                    params: [height]
                ) { (result: Result<String?, Swift.Error>) in
                    continuation.resume(with: result)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

public final class SubqueryHistoryOperation<ResultType>:
    PIAsyncOperation<ResultType>,
    @unchecked Sendable
{
    private let address: String
    private let count: Int
    private let page: Int
    private let client: PIIndexerClient
    private let filter: ((TxHistoryItem) -> KotlinBoolean)?
    private let canonicalBlockHash: PIHistoryBlockHashResolver

    public convenience init(
        address: String,
        count: Int,
        page: Int,
        filter: ((TxHistoryItem) -> KotlinBoolean)? = nil
    ) {
        self.init(
            address: address,
            count: count,
            page: page,
            filter: filter,
            client: PIIndexerClient(),
            canonicalBlockHash:
                PISoraHistoryBlockResolver.canonicalBlockHash
        )
    }

    init(
        address: String,
        count: Int,
        page: Int,
        filter: ((TxHistoryItem) -> KotlinBoolean)?,
        client: PIIndexerClient,
        canonicalBlockHash: @escaping PIHistoryBlockHashResolver
    ) {
        self.address = address
        self.count = count
        self.page = page
        self.filter = filter
        self.client = client
        self.canonicalBlockHash = canonicalBlockHash

        super.init()
    }

    override public func execute() async throws -> ResultType {
        guard
            (1 ... 100).contains(count),
            (1 ... 20).contains(page)
        else {
            throw PIIndexerError.paginationLimit
        }
        do {
            let qualified = try await client.qualifiedHistoryPage(
                address: address,
                first: count,
                page: page
            )
            guard
                let qualification = qualified.qualification,
                qualification.source == .live
            else {
                throw PIIndexerError.missingChainIdentityCapability
            }
            let health = qualification.health
            let response = qualified.value
            try Task.checkCancellation()
            let values = try PIHistoryPageValidator.validate(
                response,
                hasPriorPage: page > 1,
                pageSize: count
            )
            guard
                let finalizedCheckpoint = health.finalizedCheckpoint
            else {
                throw PIIndexerError.invalidResponse
            }
            try await PIHistoryCheckpointValidator.validate(
                values,
                expectedAddress: address,
                finalizedCheckpoint: finalizedCheckpoint,
                indexedCheckpointHash: health.latestIndexedBlockHash,
                canonicalBlockHash: canonicalBlockHash
            )
            try Task.checkCancellation()
            await PIValidatedHistoryCache.shared.save(
                address: address,
                count: count,
                page: page,
                finalizedCheckpoint: finalizedCheckpoint,
                indexedCheckpointHash:
                    health.latestIndexedBlockHash,
                endCursor: response.pageInfo.endCursor,
                endReached: !response.pageInfo.hasNextPage,
                elements: values
            )
            return try makeResult(
                values,
                endCursor: response.pageInfo.endCursor,
                endReached: !response.pageInfo.hasNextPage
            )
        } catch {
            guard
                Self.allowsValidatedOfflineFallback(error),
                let cached = await PIValidatedHistoryCache.shared.load(
                    address: address,
                    count: count,
                    page: page
                )
            else {
                throw error
            }
            try Task.checkCancellation()
            return try makeResult(
                cached.elements,
                endCursor: cached.endCursor,
                endReached: cached.endReached
            )
        }
    }

    private func makeResult(
        _ values: [PIHistoryElement],
        endCursor: String?,
        endReached: Bool
    ) throws -> ResultType {
        let mapped = try values
            .map(Self.makeLegacyItem)
            .filter { item in
                filter?(item).boolValue ?? true
            }
        let legacy = TxHistoryResult<TxHistoryItem>(
            endCursor: endCursor,
            endReached: endReached,
            page: Int64(page),
            items: mapped,
            errorMessage: nil
        )
        guard let typedResult = legacy as? ResultType else {
            throw PIIndexerError.invalidResponse
        }
        return typedResult
    }

    private static func allowsValidatedOfflineFallback(
        _ error: Swift.Error
    ) -> Bool {
        if let urlError = error as? URLError {
            return PIIndexerClient.allowsOfflineTransportFallback(
                urlError
            )
        }
        if let indexerError = error as? PIIndexerError,
           case let .httpStatus(code) = indexerError {
            return
                code == 408 ||
                code == 429 ||
                (500 ... 599).contains(code)
        }
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else {
            return false
        }
        let code = URLError.Code(rawValue: nsError.code)
        return PIIndexerClient.allowsOfflineTransportFallback(
            URLError(code)
        )
    }

    private static func makeLegacyItem(
        _ element: PIHistoryElement
    ) throws -> TxHistoryItem {
        guard
            let executionSuccess = PIHistoryCheckpointValidator
                .executionSucceeded(element.execution),
            PIHistoryCheckpointValidator.isNonNegativeIntegerQuantity(
                element.networkFee
            ),
            let networkFee = element.networkFee?.rawValue,
            let timestamp = element.timestamp,
            timestamp >= 0,
            let blockHash = element.blockHash.flatMap(
                PIHistoryCheckpointValidator.normalizedBlockHash
            )
        else {
            throw PIIndexerError.invalidResponse
        }
        let canonicalID = PIHistoryCheckpointValidator
            .normalizedTransactionHash(element.id) ?? element.id
        let data = parameters(from: element.data)
        let nested = element.calls?.nodes.map { call in
            TxHistoryItemNested(
                module: call.module ?? "",
                method: call.method ?? "",
                hash: canonicalID,
                data: parameters(from: call.data) ?? []
            )
        }

        return TxHistoryItem(
            id: canonicalID,
            blockHash: blockHash,
            module: element.module ?? "",
            method: element.method ?? "",
            timestamp: String(timestamp),
            networkFee: networkFee,
            success: executionSuccess,
            data: data,
            nestedData: nested
        )
    }

    private static func parameters(from value: PIJSONValue?) -> [TxHistoryItemParam]? {
        guard
            let value,
            case let .object(object) = value
        else {
            return nil
        }
        return object.keys.sorted().map { key in
            TxHistoryItemParam(
                paramName: key,
                paramValue: parameterString(object[key] ?? .null)
            )
        }
    }

    private static func parameterString(_ value: PIJSONValue) -> String {
        switch value {
        case .null:
            return ""
        case let .bool(value):
            return String(value)
        case let .string(value), let .number(value):
            return value
        case .array, .object:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            guard
                let data = try? encoder.encode(value),
                let string = String(data: data, encoding: .utf8)
            else {
                return ""
            }
            return string
        }
    }
}
