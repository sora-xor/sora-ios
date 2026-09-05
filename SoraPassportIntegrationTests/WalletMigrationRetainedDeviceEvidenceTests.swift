import CoreFoundation
import CryptoKit
import Darwin
import Foundation
import XCTest

/// Emits observed, non-authorizing evidence from a retained physical-device run.
///
/// The orchestration job owns the ledger writer. It must place canonical JSON at:
///
/// `Library/Application Support/SoraWalletMigrationEvidence/retained-device-observation-ledger-v3.json`
///
/// The directory must be owner-only and the ledger must use complete data
/// protection. This suite never reads an alternate path and never exports the
/// ledger itself, credentials, wallet/account identifiers, device identifiers,
/// secret material, signatures, or hashes of Keychain values.
final class WalletMigrationRetainedDeviceEvidenceTests: XCTestCase {
    private static let runBindingProducer =
        "WalletMigrationRetainedDeviceEvidenceTests/testEmitRetainedDeviceRunBinding()"
    private static let keychainProducer =
        "WalletMigrationRetainedDeviceEvidenceTests/testEmitRetainedKeychainCohortEvidence()"
    private static let deviceProducer =
        "WalletMigrationRetainedDeviceEvidenceTests/testEmitRetainedDeviceScenarioEvidence()"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testEmitRetainedDeviceRunBinding() throws {
        let context = try RetainedDeviceEvidenceContext.load()
        var record = context.hostBindingJSONObject
        record.merge([
            "schemaVersion": 3,
            "contractId": "sora-ios-wallet-migration-run-binding-v3",
            "platform": "ios",
            "runId": context.bindings.runId,
            "runChallengeSha256": context.bindings.runChallengeSha256,
            "sourceRevision": context.bindings.sourceRevision,
            "producerTestIdentifier": Self.runBindingProducer,
        ]) { _, _ in preconditionFailure("duplicate run-binding field") }

        try attachCanonicalJSON(record, named: "ios-migration-run-binding-v3.json")
    }

    func testEmitRetainedKeychainCohortEvidence() throws {
        let context = try RetainedDeviceEvidenceContext.load()
        let observations = try context.ledger.validatedKeychainObservations()
        var record = context.hostBindingJSONObject
        record.merge([
            "schemaVersion": 3,
            "contractId": "sora-ios-wallet-migration-keychain-observations-v3",
            "platform": "ios",
            "runId": context.bindings.runId,
            "runChallengeSha256": context.bindings.runChallengeSha256,
            "sourceRevision": context.bindings.sourceRevision,
            "producerTestIdentifier": Self.keychainProducer,
            "observations": observations.map(\.jsonObject),
        ]) { _, _ in preconditionFailure("duplicate Keychain evidence field") }

        try attachCanonicalJSON(
            record,
            named: "ios-migration-keychain-observations-v3.json"
        )
    }

    func testEmitRetainedDeviceScenarioEvidence() throws {
        let context = try RetainedDeviceEvidenceContext.load()
        let events = try context.ledger.validatedDeviceEvents()
        var record = context.hostBindingJSONObject
        record.merge([
            "schemaVersion": 3,
            "contractId": "sora-ios-wallet-migration-device-events-v3",
            "platform": "ios",
            "runId": context.bindings.runId,
            "runChallengeSha256": context.bindings.runChallengeSha256,
            "sourceRevision": context.bindings.sourceRevision,
            "producerTestIdentifier": Self.deviceProducer,
            "events": events.map(\.jsonObject),
        ]) { _, _ in preconditionFailure("duplicate device evidence field") }

        try attachCanonicalJSON(record, named: "ios-migration-device-events-v3.json")
    }

    private func attachCanonicalJSON(_ object: [String: Any], named name: String) throws {
        let data = try StrictMigrationJSON.canonicalData(for: object)
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

private struct RetainedDeviceEvidenceContext {
    let bindings: MigrationEvidenceBindings
    let installedHost: InstalledAppTreeBinding
    let ledger: RetainedDeviceObservationLedger

    var hostBindingJSONObject: [String: Any] {
        bindings.hostBindingJSONObject(installedHost: installedHost)
    }

    static func load() throws -> RetainedDeviceEvidenceContext {
        let bindings = try MigrationEvidenceBindings.loadFromFixedEnvironment()
        let installedHost = try ProductionEvidenceHost.verifyInstalledTree(bindings: bindings)
        let ledger = try RetainedDeviceObservationLedger.load(
            bindings: bindings,
            installedHost: installedHost
        )
        return RetainedDeviceEvidenceContext(
            bindings: bindings,
            installedHost: installedHost,
            ledger: ledger
        )
    }
}

private struct MigrationEvidenceBindings {
    static let runIdEnvironment = "SORA_MIGRATION_EVIDENCE_RUN_ID"
    static let challengeEnvironment = "SORA_MIGRATION_EVIDENCE_RUN_CHALLENGE_SHA256"
    static let sourceRevisionEnvironment = "SORA_MIGRATION_EVIDENCE_SOURCE_REVISION"
    static let productionIpaSha256Environment =
        "SORA_MIGRATION_EVIDENCE_PRODUCTION_IPA_SHA256"
    static let projectionReceiptSha256Environment =
        "SORA_MIGRATION_EVIDENCE_CANONICAL_PROJECTION_RECEIPT_SHA256"
    static let rawTreeSha256Environment =
        "SORA_MIGRATION_EVIDENCE_INSTALLED_APP_RAW_TREE_SHA256"
    static let rawTreeByteCountEnvironment =
        "SORA_MIGRATION_EVIDENCE_INSTALLED_APP_RAW_TREE_RECORD_BYTE_COUNT"
    static let productionCanonicalProjectionSha256Environment =
        "SORA_MIGRATION_EVIDENCE_PRODUCTION_CANONICAL_PROJECTION_SHA256"
    static let installedCanonicalProjectionSha256Environment =
        "SORA_MIGRATION_EVIDENCE_INSTALLED_CANONICAL_PROJECTION_SHA256"
    static let canonicalProjectorSourceSha256Environment =
        "SORA_MIGRATION_EVIDENCE_CANONICAL_PROJECTOR_SOURCE_SHA256"
    static let executableSha256Environment =
        "SORA_MIGRATION_EVIDENCE_INSTALLED_EXECUTABLE_SHA256"
    static let executableByteCountEnvironment =
        "SORA_MIGRATION_EVIDENCE_INSTALLED_EXECUTABLE_BYTE_COUNT"
    static let ledgerSha256Environment = "SORA_MIGRATION_EVIDENCE_LEDGER_SHA256"

    let runId: String
    let runChallengeSha256: String
    let sourceRevision: String
    let productionIpaSha256: String
    let projectionReceiptSha256: String
    let rawTreeSha256: String
    let rawTreeRecordByteCount: Int64
    let productionCanonicalProjectionSha256: String
    let installedCanonicalProjectionSha256: String
    let canonicalProjectorSourceSha256: String
    let executableSha256: String
    let executableByteCount: Int64
    let ledgerSha256: String

    static func loadFromFixedEnvironment() throws -> MigrationEvidenceBindings {
        let environment = ProcessInfo.processInfo.environment
        let runId = try required(environment, key: runIdEnvironment, maximumLength: 36)
        let challenge = try required(environment, key: challengeEnvironment, maximumLength: 64)
        let sourceRevision = try required(
            environment,
            key: sourceRevisionEnvironment,
            maximumLength: 40
        )
        let productionIpaSha256 = try required(
            environment,
            key: productionIpaSha256Environment,
            maximumLength: 64
        )
        let projectionReceiptSha256 = try required(
            environment,
            key: projectionReceiptSha256Environment,
            maximumLength: 64
        )
        let rawTreeSha256 = try required(
            environment,
            key: rawTreeSha256Environment,
            maximumLength: 64
        )
        let rawTreeRecordByteCount = try requiredPositiveInt(
            environment,
            key: rawTreeByteCountEnvironment
        )
        let productionCanonicalProjectionSha256 = try required(
            environment,
            key: productionCanonicalProjectionSha256Environment,
            maximumLength: 64
        )
        let installedCanonicalProjectionSha256 = try required(
            environment,
            key: installedCanonicalProjectionSha256Environment,
            maximumLength: 64
        )
        let canonicalProjectorSourceSha256 = try required(
            environment,
            key: canonicalProjectorSourceSha256Environment,
            maximumLength: 64
        )
        let executableSha256 = try required(
            environment,
            key: executableSha256Environment,
            maximumLength: 64
        )
        let executableByteCount = try requiredPositiveInt(
            environment,
            key: executableByteCountEnvironment
        )
        let ledgerSha256 = try required(
            environment,
            key: ledgerSha256Environment,
            maximumLength: 64
        )

        guard
            let uuid = UUID(uuidString: runId),
            runId != "00000000-0000-0000-0000-000000000000",
            uuid.uuidString.lowercased() == runId
        else {
            throw MigrationEvidenceError("the fixed run ID is not a canonical nonzero UUID")
        }
        guard MigrationEvidenceValidation.isLowercaseHex(sourceRevision, count: 40) else {
            throw MigrationEvidenceError("the fixed source revision is not a nonzero lowercase revision")
        }
        for (value, label) in [
            (challenge, "run challenge"),
            (productionIpaSha256, "production IPA"),
            (projectionReceiptSha256, "canonical projection receipt"),
            (rawTreeSha256, "installed clone raw tree"),
            (productionCanonicalProjectionSha256, "production canonical projection"),
            (installedCanonicalProjectionSha256, "installed canonical projection"),
            (canonicalProjectorSourceSha256, "canonical projector source"),
            (executableSha256, "executable"),
            (ledgerSha256, "ledger"),
        ] where !MigrationEvidenceValidation.isLowercaseHex(value, count: 64) {
            throw MigrationEvidenceError("the fixed \(label) binding is not a nonzero lowercase SHA-256")
        }

        guard productionCanonicalProjectionSha256 == installedCanonicalProjectionSha256 else {
            throw MigrationEvidenceError("the fixed production and installed projections differ")
        }

        return MigrationEvidenceBindings(
            runId: runId,
            runChallengeSha256: challenge,
            sourceRevision: sourceRevision,
            productionIpaSha256: productionIpaSha256,
            projectionReceiptSha256: projectionReceiptSha256,
            rawTreeSha256: rawTreeSha256,
            rawTreeRecordByteCount: rawTreeRecordByteCount,
            productionCanonicalProjectionSha256: productionCanonicalProjectionSha256,
            installedCanonicalProjectionSha256: installedCanonicalProjectionSha256,
            canonicalProjectorSourceSha256: canonicalProjectorSourceSha256,
            executableSha256: executableSha256,
            executableByteCount: executableByteCount,
            ledgerSha256: ledgerSha256
        )
    }

    func hostBindingJSONObject(installedHost: InstalledAppTreeBinding) -> [String: Any] {
        [
            "productionIpaSha256": productionIpaSha256,
            "installedAppRawTreeSha256": installedHost.rawTreeSha256,
            "installedAppRawTreeRecordByteCount": installedHost.rawTreeRecordByteCount,
            "installedExecutableSha256": installedHost.executableSha256,
            "installedExecutableByteCount": installedHost.executableByteCount,
            "productionCanonicalProjectionSha256": productionCanonicalProjectionSha256,
            "installedCanonicalProjectionSha256": installedCanonicalProjectionSha256,
            "canonicalProjectionReceiptSha256": projectionReceiptSha256,
            "canonicalProjectorSourceSha256": canonicalProjectorSourceSha256,
            "installedAppLaunchVerified": true,
            "installedRawTreeRecomputed": true,
            "installedExecutableRecomputed": true,
            "canonicalProjectionReceiptVerified": true,
            "canonicalProjectorSourceVerified": true,
            "canonicalProjectionEqualToProduction": true,
        ]
    }

    private static func required(
        _ environment: [String: String],
        key: String,
        maximumLength: Int
    ) throws -> String {
        guard
            let value = environment[key],
            !value.isEmpty,
            value.utf8.count <= maximumLength,
            value == value.trimmingCharacters(in: .whitespacesAndNewlines)
        else {
            throw MigrationEvidenceError("the required fixed evidence environment is incomplete")
        }
        return value
    }

    private static func requiredPositiveInt(
        _ environment: [String: String],
        key: String
    ) throws -> Int64 {
        let value = try required(environment, key: key, maximumLength: 20)
        guard
            value.utf8.allSatisfy({ (48 ... 57).contains($0) }),
            !value.hasPrefix("0"),
            let integer = Int64(value),
            integer > 0,
            integer <= 8 * 1_024 * 1_024 * 1_024
        else {
            throw MigrationEvidenceError("the fixed evidence byte-count binding is invalid")
        }
        return integer
    }
}

private struct InstalledAppTreeBinding {
    let rawTreeSha256: String
    let rawTreeRecordByteCount: Int64
    let executableSha256: String
    let executableByteCount: Int64
}

private struct InstalledAppTreeEntry {
    let relativePath: String
    let executable: Bool
    let byteCount: Int64
    let sha256: Data
}

private enum ProductionEvidenceHost {
    private static let productionBundleIdentifier = "co.jp.soramitsu.sora"
    private static let rawTreePrefix = Data(
        "SORA-IOS-MIGRATION-RAW-APP-TREE-V1\0".utf8
    )
    private static let maximumFileBytes: Int64 = 2 * 1_024 * 1_024 * 1_024
    private static let maximumAppBytes: Int64 = 8 * 1_024 * 1_024 * 1_024
    private static let maximumFileCount = 100_000

    static func verifyInstalledTree(
        bindings: MigrationEvidenceBindings
    ) throws -> InstalledAppTreeBinding {
        #if targetEnvironment(simulator)
        throw MigrationEvidenceError("migration evidence cannot run on a simulator")
        #endif

        #if DEBUG
        throw MigrationEvidenceError("migration evidence requires the Release production host")
        #endif

        let environment = ProcessInfo.processInfo.environment
        guard
            environment["SIMULATOR_UDID"] == nil,
            environment["SIMULATOR_DEVICE_NAME"] == nil,
            Bundle.main.bundleIdentifier == productionBundleIdentifier,
            let executableName = Bundle.main.object(forInfoDictionaryKey: "CFBundleExecutable") as? String,
            !executableName.isEmpty,
            executableName.utf8.count <= 128,
            !executableName.contains("/"),
            let executableURL = Bundle.main.executableURL,
            executableURL.lastPathComponent == executableName,
            executableURL.deletingLastPathComponent().standardizedFileURL ==
                Bundle.main.bundleURL.standardizedFileURL
        else {
            throw MigrationEvidenceError("migration evidence is not hosted by the reviewed production app")
        }

        let entries = try inspectCompleteTree(at: Bundle.main.bundleURL)
        guard
            entries.count <= Int(UInt32.max),
            let executable = entries.first(where: { $0.relativePath == executableName }),
            executable.executable
        else {
            throw MigrationEvidenceError("the installed host lacks its one fixed executable")
        }
        var record = rawTreePrefix
        appendBigEndian(UInt32(entries.count), to: &record)
        for entry in entries {
            let path = Data(entry.relativePath.utf8)
            guard path.count <= Int(UInt32.max), entry.sha256.count == 32 else {
                throw MigrationEvidenceError("the installed host tree record exceeds its format bound")
            }
            appendBigEndian(UInt32(path.count), to: &record)
            record.append(path)
            record.append(entry.executable ? 0x45 : 0x4E)
            appendBigEndian(UInt64(entry.byteCount), to: &record)
            record.append(entry.sha256)
        }
        let treeSha256 = MigrationEvidenceValidation.sha256(record)
        let executableSha256 = MigrationEvidenceValidation.hex(executable.sha256)
        guard
            treeSha256 == bindings.rawTreeSha256,
            Int64(record.count) == bindings.rawTreeRecordByteCount,
            executableSha256 == bindings.executableSha256,
            executable.byteCount == bindings.executableByteCount
        else {
            throw MigrationEvidenceError(
                "the installed app differs from the fixed archive-derived clone binding"
            )
        }
        return InstalledAppTreeBinding(
            rawTreeSha256: treeSha256,
            rawTreeRecordByteCount: Int64(record.count),
            executableSha256: executableSha256,
            executableByteCount: executable.byteCount
        )
    }

    private static func inspectCompleteTree(at root: URL) throws -> [InstalledAppTreeEntry] {
        var rootBefore = stat()
        guard Darwin.lstat(root.path, &rootBefore) == 0 else {
            throw MigrationEvidenceError("the installed host root cannot be inspected")
        }
        try requireOwnedDirectory(rootBefore, label: "installed host root")

        var entries: [InstalledAppTreeEntry] = []
        var normalizedNodes = Set<String>()
        var inodeIdentities = Set<String>()
        inodeIdentities.insert(inodeIdentity(rootBefore))
        var totalBytes: Int64 = 0
        try walk(
            directory: root,
            expectedMetadata: rootBefore,
            relativePrefix: "",
            entries: &entries,
            normalizedNodes: &normalizedNodes,
            inodeIdentities: &inodeIdentities,
            totalBytes: &totalBytes
        )

        var rootAfter = stat()
        guard
            Darwin.lstat(root.path, &rootAfter) == 0,
            MigrationEvidenceValidation.sameStableFile(rootBefore, rootAfter),
            !entries.isEmpty
        else {
            throw MigrationEvidenceError("the installed host root changed during inventory")
        }
        return entries.sorted {
            $0.relativePath.utf8.lexicographicallyPrecedes($1.relativePath.utf8)
        }
    }

    private static func walk(
        directory: URL,
        expectedMetadata: stat,
        relativePrefix: String,
        entries: inout [InstalledAppTreeEntry],
        normalizedNodes: inout Set<String>,
        inodeIdentities: inout Set<String>,
        totalBytes: inout Int64
    ) throws {
        var directoryBefore = stat()
        guard
            Darwin.lstat(directory.path, &directoryBefore) == 0,
            MigrationEvidenceValidation.sameStableFile(expectedMetadata, directoryBefore)
        else {
            throw MigrationEvidenceError("the installed host directory cannot be inspected")
        }
        try requireOwnedDirectory(directoryBefore, label: "installed host directory")
        let children: [URL]
        do {
            children = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: []
            ).sorted { $0.lastPathComponent.utf8.lexicographicallyPrecedes($1.lastPathComponent.utf8) }
        } catch {
            throw MigrationEvidenceError("the installed host directory cannot be enumerated")
        }
        guard !children.isEmpty else {
            throw MigrationEvidenceError("the installed host contains an empty directory")
        }

        var descendantFiles = 0
        for child in children {
            let component = child.lastPathComponent
            guard
                child.deletingLastPathComponent().standardizedFileURL ==
                    directory.standardizedFileURL,
                isSafeComponent(component)
            else {
                throw MigrationEvidenceError("the installed host contains an unsafe path component")
            }
            let relative = relativePrefix.isEmpty ? component : "\(relativePrefix)/\(component)"
            let normalized = relative.precomposedStringWithCanonicalMapping.lowercased()
            guard normalizedNodes.insert(normalized).inserted else {
                throw MigrationEvidenceError("the installed host contains an NFC/casefold node collision")
            }

            var metadata = stat()
            guard Darwin.lstat(child.path, &metadata) == 0 else {
                throw MigrationEvidenceError("an installed host node cannot be inspected")
            }
            guard inodeIdentities.insert(inodeIdentity(metadata)).inserted else {
                throw MigrationEvidenceError("the installed host contains a hard link or directory alias")
            }
            let fileType = metadata.st_mode & mode_t(S_IFMT)
            if fileType == mode_t(S_IFDIR) {
                try requireOwnedDirectory(metadata, label: "installed host directory")
                let countBefore = entries.count
                try walk(
                    directory: child,
                    expectedMetadata: metadata,
                    relativePrefix: relative,
                    entries: &entries,
                    normalizedNodes: &normalizedNodes,
                    inodeIdentities: &inodeIdentities,
                    totalBytes: &totalBytes
                )
                let childFiles = entries.count - countBefore
                guard childFiles > 0 else {
                    throw MigrationEvidenceError("the installed host contains an empty semantic directory")
                }
                descendantFiles += childFiles
                continue
            }
            guard fileType == mode_t(S_IFREG), metadata.st_uid == geteuid() else {
                throw MigrationEvidenceError("the installed host contains a linked, special, or foreign node")
            }
            let file = try hashStableRegularFile(
                at: child,
                expectedPathMetadata: metadata,
                maximumBytes: maximumFileBytes,
                label: "installed host file"
            )
            guard totalBytes <= maximumAppBytes - file.byteCount else {
                throw MigrationEvidenceError("the installed host exceeds its total byte bound")
            }
            totalBytes += file.byteCount
            entries.append(
                InstalledAppTreeEntry(
                    relativePath: relative,
                    executable: (metadata.st_mode & mode_t(0o111)) != 0,
                    byteCount: file.byteCount,
                    sha256: file.sha256
                )
            )
            descendantFiles += 1
            guard entries.count <= maximumFileCount else {
                throw MigrationEvidenceError("the installed host exceeds its file-count bound")
            }
        }

        var directoryAfter = stat()
        guard
            descendantFiles > 0,
            Darwin.lstat(directory.path, &directoryAfter) == 0,
            MigrationEvidenceValidation.sameStableFile(directoryBefore, directoryAfter)
        else {
            throw MigrationEvidenceError("the installed host directory changed during inventory")
        }
    }

    private static func hashStableRegularFile(
        at url: URL,
        expectedPathMetadata: stat,
        maximumBytes: Int64,
        label: String
    ) throws -> (sha256: Data, byteCount: Int64) {
        let descriptor = Darwin.open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        guard descriptor >= 0 else {
            throw MigrationEvidenceError("the \(label) cannot be opened without following links")
        }
        defer { Darwin.close(descriptor) }

        var before = stat()
        guard Darwin.fstat(descriptor, &before) == 0 else {
            throw MigrationEvidenceError("the \(label) metadata cannot be read")
        }
        try MigrationEvidenceValidation.requireUniqueBoundedRegularFile(
            before,
            maximumBytes: maximumBytes,
            label: label
        )
        guard
            before.st_uid == geteuid(),
            MigrationEvidenceValidation.sameStableFile(expectedPathMetadata, before)
        else {
            throw MigrationEvidenceError("the \(label) changed during anchored open")
        }

        var hasher = SHA256()
        var bytesRead: Int64 = 0
        var buffer = [UInt8](repeating: 0, count: 256 * 1024)
        while true {
            let count: Int = try buffer.withUnsafeMutableBytes { rawBuffer in
                while true {
                    let result = Darwin.read(descriptor, rawBuffer.baseAddress, rawBuffer.count)
                    if result < 0, errno == EINTR {
                        continue
                    }
                    guard result >= 0 else {
                        throw MigrationEvidenceError("the \(label) cannot be read")
                    }
                    return result
                }
            }
            if count == 0 {
                break
            }
            bytesRead += Int64(count)
            guard bytesRead <= maximumBytes else {
                throw MigrationEvidenceError("the \(label) exceeds its byte bound")
            }
            hasher.update(data: Data(buffer[0 ..< count]))
        }

        var after = stat()
        var namedAfter = stat()
        guard
            Darwin.fstat(descriptor, &after) == 0,
            Darwin.lstat(url.path, &namedAfter) == 0
        else {
            throw MigrationEvidenceError("the \(label) metadata cannot be re-read")
        }
        guard
            bytesRead == before.st_size,
            MigrationEvidenceValidation.sameStableFile(before, after),
            MigrationEvidenceValidation.sameStableFile(before, namedAfter)
        else {
            throw MigrationEvidenceError("the \(label) changed while it was being hashed")
        }
        return (Data(hasher.finalize()), bytesRead)
    }

    private static func requireOwnedDirectory(_ metadata: stat, label: String) throws {
        guard
            (metadata.st_mode & mode_t(S_IFMT)) == mode_t(S_IFDIR),
            metadata.st_uid == geteuid()
        else {
            throw MigrationEvidenceError("the \(label) is not one owned directory")
        }
    }

    private static func inodeIdentity(_ metadata: stat) -> String {
        "\(metadata.st_dev):\(metadata.st_ino)"
    }

    private static func isSafeComponent(_ value: String) -> Bool {
        let bytes = Array(value.utf8)
        guard !bytes.isEmpty, bytes.count <= 256 else { return false }
        func isAlphanumericOrUnderscore(_ byte: UInt8) -> Bool {
            (48 ... 57).contains(byte) || (65 ... 90).contains(byte) ||
                (97 ... 122).contains(byte) || byte == 95
        }
        guard isAlphanumericOrUnderscore(bytes[0]) else { return false }
        return bytes.dropFirst().allSatisfy { byte in
            isAlphanumericOrUnderscore(byte) || [46, 43, 64, 45].contains(byte)
        }
    }

    private static func appendBigEndian<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var encoded = value.bigEndian
        withUnsafeBytes(of: &encoded) { data.append(contentsOf: $0) }
    }
}

private struct RetainedDeviceObservationLedger {
    private static let directoryName = "SoraWalletMigrationEvidence"
    private static let fileName = "retained-device-observation-ledger-v3.json"
    private static let maximumLedgerBytes: Int64 = 1_048_576

    let root: [String: Any]

    static func load(
        bindings: MigrationEvidenceBindings,
        installedHost: InstalledAppTreeBinding
    ) throws -> RetainedDeviceObservationLedger {
        let manager = FileManager.default
        guard let applicationSupport = manager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first?.standardizedFileURL else {
            throw MigrationEvidenceError("the fixed Application Support root is unavailable")
        }
        let ledgerDirectory = applicationSupport
            .appendingPathComponent(directoryName, isDirectory: true)
            .standardizedFileURL
        let ledgerURL = ledgerDirectory
            .appendingPathComponent(fileName, isDirectory: false)
            .standardizedFileURL
        guard
            ledgerDirectory.deletingLastPathComponent() == applicationSupport,
            ledgerURL.deletingLastPathComponent() == ledgerDirectory
        else {
            throw MigrationEvidenceError("the fixed observation-ledger path is not anchored")
        }

        try MigrationEvidenceFileReader.requireDirectory(
            at: applicationSupport,
            ownerOnly: false,
            label: "Application Support root"
        )
        try MigrationEvidenceFileReader.requireDirectory(
            at: ledgerDirectory,
            ownerOnly: true,
            label: "observation-ledger directory"
        )
        var ledgerDirectoryBefore = stat()
        guard
            Darwin.lstat(ledgerDirectory.path, &ledgerDirectoryBefore) == 0,
            try exactLedgerInventory(at: ledgerDirectory)
        else {
            throw MigrationEvidenceError(
                "the observation-ledger directory contains a stale or unreviewed entry"
            )
        }
        let data = try MigrationEvidenceFileReader.readProtectedRegularFile(
            at: ledgerURL,
            maximumBytes: maximumLedgerBytes
        )
        var ledgerDirectoryAfter = stat()
        guard
            Darwin.lstat(ledgerDirectory.path, &ledgerDirectoryAfter) == 0,
            MigrationEvidenceValidation.sameStableFile(
                ledgerDirectoryBefore,
                ledgerDirectoryAfter
            ),
            try exactLedgerInventory(at: ledgerDirectory)
        else {
            throw MigrationEvidenceError(
                "the observation-ledger directory changed during protected read"
            )
        }
        guard MigrationEvidenceValidation.sha256(data) == bindings.ledgerSha256 else {
            throw MigrationEvidenceError("the protected observation ledger differs from its fixed binding")
        }

        let root = try StrictMigrationJSON.object(fromCanonicalData: data)
        try StrictMigrationJSON.requireExactKeys(
            root,
            [
                "schemaVersion",
                "contractId",
                "platform",
                "status",
                "releaseAuthorized",
                "runId",
                "runChallengeSha256",
                "sourceRevision",
                "productionIpaSha256",
                "installedAppRawTreeSha256",
                "installedAppRawTreeRecordByteCount",
                "installedExecutableSha256",
                "installedExecutableByteCount",
                "productionCanonicalProjectionSha256",
                "installedCanonicalProjectionSha256",
                "canonicalProjectionReceiptSha256",
                "canonicalProjectorSourceSha256",
                "installedAppLaunchVerified",
                "installedRawTreeRecomputed",
                "installedExecutableRecomputed",
                "canonicalProjectionReceiptVerified",
                "canonicalProjectorSourceVerified",
                "canonicalProjectionEqualToProduction",
                "keychainObservations",
                "deviceEvents",
            ],
            label: "observation ledger"
        )
        let expectedHostBinding = bindings.hostBindingJSONObject(installedHost: installedHost)
        guard
            try StrictMigrationJSON.integer(root["schemaVersion"], label: "ledger schema") == 3,
            try StrictMigrationJSON.string(root["contractId"], label: "ledger contract") ==
                "sora-ios-wallet-migration-observation-ledger-v3",
            try StrictMigrationJSON.string(root["platform"], label: "ledger platform") == "ios",
            try StrictMigrationJSON.string(root["status"], label: "ledger status") == "observed",
            try StrictMigrationJSON.boolean(
                root["releaseAuthorized"],
                label: "ledger release authorization"
            ) == false,
            try StrictMigrationJSON.string(root["runId"], label: "ledger run ID") == bindings.runId,
            try StrictMigrationJSON.string(
                root["runChallengeSha256"],
                label: "ledger run challenge"
            ) == bindings.runChallengeSha256,
            try StrictMigrationJSON.string(
                root["sourceRevision"],
                label: "ledger source revision"
            ) == bindings.sourceRevision,
            try hostBindingMatches(root, expected: expectedHostBinding)
        else {
            throw MigrationEvidenceError("the observation ledger differs from the fixed run bindings")
        }

        return RetainedDeviceObservationLedger(root: root)
    }

    private static func exactLedgerInventory(at directory: URL) throws -> Bool {
        let children: [URL]
        do {
            children = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: []
            )
        } catch {
            throw MigrationEvidenceError("the observation-ledger directory cannot be enumerated")
        }
        return children.count == 1 &&
            children[0].lastPathComponent == fileName &&
            children[0].deletingLastPathComponent().standardizedFileURL ==
                directory.standardizedFileURL
    }

    private static func hostBindingMatches(
        _ root: [String: Any],
        expected: [String: Any]
    ) throws -> Bool {
        for (key, expectedValue) in expected {
            if let string = expectedValue as? String {
                guard try StrictMigrationJSON.string(root[key], label: "ledger \(key)") == string else {
                    return false
                }
            } else if let boolean = expectedValue as? Bool {
                guard try StrictMigrationJSON.boolean(root[key], label: "ledger \(key)") == boolean else {
                    return false
                }
            } else if let integer = expectedValue as? Int64 {
                guard try StrictMigrationJSON.integer(root[key], label: "ledger \(key)") == integer else {
                    return false
                }
            } else {
                throw MigrationEvidenceError("the internal ledger binding has an unsupported value")
            }
        }
        return true
    }

    func validatedKeychainObservations() throws -> [ValidatedKeychainObservation] {
        let values = try StrictMigrationJSON.array(
            root["keychainObservations"],
            label: "Keychain observations"
        )
        guard values.count == KeychainCohort.allCases.count else {
            throw MigrationEvidenceError("the observation ledger omits a required Keychain cohort")
        }

        var seen = Set<KeychainCohort>()
        var observations: [ValidatedKeychainObservation] = []
        for (index, value) in values.enumerated() {
            let label = "Keychain observation \(index)"
            let object = try StrictMigrationJSON.dictionary(value, label: label)
            try StrictMigrationJSON.requireExactKeys(
                object,
                [
                    "cohortId",
                    "outcome",
                    "identifierSetUnchanged",
                    "valuesByteForByteUnchanged",
                    "accessibilityUnchanged",
                    "credentialRewriteObserved",
                    "signingProbePassed",
                    "recoveryRouteEntered",
                ],
                label: label
            )
            guard
                let cohort = KeychainCohort(
                    rawValue: try StrictMigrationJSON.string(
                        object["cohortId"],
                        label: "\(label) cohort"
                    )
                ),
                seen.insert(cohort).inserted,
                let outcome = KeychainOutcome(
                    rawValue: try StrictMigrationJSON.string(
                        object["outcome"],
                        label: "\(label) outcome"
                    )
                ),
                outcome == cohort.expectedOutcome
            else {
                throw MigrationEvidenceError("\(label) has an unreviewed or duplicate enum value")
            }

            let identifierSetUnchanged = try StrictMigrationJSON.boolean(
                object["identifierSetUnchanged"],
                label: "\(label) identifier parity"
            )
            let valuesByteForByteUnchanged = try StrictMigrationJSON.boolean(
                object["valuesByteForByteUnchanged"],
                label: "\(label) byte parity"
            )
            let accessibilityUnchanged = try StrictMigrationJSON.boolean(
                object["accessibilityUnchanged"],
                label: "\(label) accessibility parity"
            )
            let credentialRewriteObserved = try StrictMigrationJSON.boolean(
                object["credentialRewriteObserved"],
                label: "\(label) rewrite observation"
            )
            let signingProbePassed = try StrictMigrationJSON.boolean(
                object["signingProbePassed"],
                label: "\(label) signing probe"
            )
            let recoveryRouteEntered = try StrictMigrationJSON.boolean(
                object["recoveryRouteEntered"],
                label: "\(label) recovery route"
            )

            guard
                identifierSetUnchanged,
                valuesByteForByteUnchanged,
                accessibilityUnchanged,
                !credentialRewriteObserved,
                signingProbePassed == (outcome == .success),
                recoveryRouteEntered == (outcome == .recovery)
            else {
                throw MigrationEvidenceError("\(label) does not prove the reviewed fail-closed outcome")
            }
            observations.append(
                ValidatedKeychainObservation(
                    cohort: cohort,
                    outcome: outcome,
                    identifierSetUnchanged: identifierSetUnchanged,
                    valuesByteForByteUnchanged: valuesByteForByteUnchanged,
                    accessibilityUnchanged: accessibilityUnchanged,
                    credentialRewriteObserved: credentialRewriteObserved,
                    signingProbePassed: signingProbePassed,
                    recoveryRouteEntered: recoveryRouteEntered
                )
            )
        }
        guard seen == Set(KeychainCohort.allCases) else {
            throw MigrationEvidenceError("the observation ledger omits a required Keychain cohort")
        }
        return observations.sorted { $0.cohort.rawValue < $1.cohort.rawValue }
    }

    func validatedDeviceEvents() throws -> [ValidatedDeviceEvent] {
        let values = try StrictMigrationJSON.array(root["deviceEvents"], label: "device events")
        guard values.count == DeviceScenario.allCases.count else {
            throw MigrationEvidenceError("the observation ledger omits a required device scenario")
        }

        let now = Int64(Date().timeIntervalSince1970.rounded(.down))
        let earliestReviewedTimestamp: Int64 = 1_577_836_800
        let maximumScenarioDuration: Int64 = 2_592_000
        var seen = Set<DeviceScenario>()
        var events: [ValidatedDeviceEvent] = []
        for (index, value) in values.enumerated() {
            let label = "device event \(index)"
            let object = try StrictMigrationJSON.dictionary(value, label: label)
            try StrictMigrationJSON.requireExactKeys(
                object,
                [
                    "scenario",
                    "outcome",
                    "startedAtEpochSeconds",
                    "finishedAtEpochSeconds",
                    "assertions",
                ],
                label: label
            )
            guard
                let scenario = DeviceScenario(
                    rawValue: try StrictMigrationJSON.string(
                        object["scenario"],
                        label: "\(label) scenario"
                    )
                ),
                seen.insert(scenario).inserted,
                try StrictMigrationJSON.string(object["outcome"], label: "\(label) outcome") ==
                    "passed"
            else {
                throw MigrationEvidenceError("\(label) has an unreviewed, duplicate, or failed enum value")
            }

            let started = try StrictMigrationJSON.integer(
                object["startedAtEpochSeconds"],
                label: "\(label) start timestamp"
            )
            let finished = try StrictMigrationJSON.integer(
                object["finishedAtEpochSeconds"],
                label: "\(label) finish timestamp"
            )
            guard
                started >= earliestReviewedTimestamp,
                finished >= started,
                finished - started <= maximumScenarioDuration,
                finished <= now + 300
            else {
                throw MigrationEvidenceError("\(label) contains an invalid or implausible timestamp")
            }

            let assertionValues = try StrictMigrationJSON.array(
                object["assertions"],
                label: "\(label) assertions"
            )
            let assertions = try assertionValues.enumerated().map { assertionIndex, raw in
                try StrictMigrationJSON.string(
                    raw,
                    label: "\(label) assertion \(assertionIndex)"
                )
            }
            guard
                assertions.count == scenario.expectedAssertions.count,
                Set(assertions).count == assertions.count,
                Set(assertions) == scenario.expectedAssertions
            else {
                throw MigrationEvidenceError("\(label) does not contain the exact reviewed assertions")
            }
            events.append(
                ValidatedDeviceEvent(
                    scenario: scenario,
                    startedAtEpochSeconds: started,
                    finishedAtEpochSeconds: finished,
                    assertions: assertions.sorted()
                )
            )
        }
        guard seen == Set(DeviceScenario.allCases) else {
            throw MigrationEvidenceError("the observation ledger omits a required device scenario")
        }
        return events.sorted { $0.scenario.rawValue < $1.scenario.rawValue }
    }
}

private enum KeychainOutcome: String {
    case success
    case recovery
}

private enum KeychainCohort: String, CaseIterable {
    case mnemonic12 = "mnemonic-12"
    case mnemonic15Retained = "mnemonic-15-retained"
    case mnemonic18Retained = "mnemonic-18-retained"
    case mnemonic21Retained = "mnemonic-21-retained"
    case irohaV1PairedKeys = "iroha-v1-paired-keys"
    case mnemonic24 = "mnemonic-24"
    case rawSeed = "raw-seed"
    case legacySecret = "legacy-secret"
    case watchOnly = "watch-only"
    case missingSecret = "missing-secret"
    case corruptSecret = "corrupt-secret"

    var expectedOutcome: KeychainOutcome {
        switch self {
        case .missingSecret, .corruptSecret:
            return .recovery
        case .mnemonic12, .mnemonic15Retained, .mnemonic18Retained, .mnemonic21Retained,
             .irohaV1PairedKeys, .mnemonic24, .rawSeed, .legacySecret, .watchOnly:
            return .success
        }
    }
}

private struct ValidatedKeychainObservation {
    let cohort: KeychainCohort
    let outcome: KeychainOutcome
    let identifierSetUnchanged: Bool
    let valuesByteForByteUnchanged: Bool
    let accessibilityUnchanged: Bool
    let credentialRewriteObserved: Bool
    let signingProbePassed: Bool
    let recoveryRouteEntered: Bool

    var jsonObject: [String: Any] {
        [
            "cohortId": cohort.rawValue,
            "outcome": outcome.rawValue,
            "identifierSetUnchanged": identifierSetUnchanged,
            "valuesByteForByteUnchanged": valuesByteForByteUnchanged,
            "accessibilityUnchanged": accessibilityUnchanged,
            "credentialRewriteObserved": credentialRewriteObserved,
            "signingProbePassed": signingProbePassed,
            "recoveryRouteEntered": recoveryRouteEntered,
        ]
    }
}

private enum DeviceScenario: String, CaseIterable {
    case reinstallUpgrade = "reinstall-upgrade"
    case rollback
    case lowStorage = "low-storage"
    case recoveryArchiveExport = "recovery-archive-export"
    case processDeathRestart = "process-death-restart"
    case interruptionBeforeSecretRetention = "interruption-before-secret-retention"
    case interruptionAfterSecretRetention = "interruption-after-secret-retention"
    case interruptionAfterCoreDataCommit = "interruption-after-core-data-commit"
    case interruptionAfterNetworkStaging = "interruption-after-network-staging"
    case interruptionBeforeActivation = "interruption-before-activation"

    var expectedAssertions: Set<String> {
        switch self {
        case .reinstallUpgrade:
            return [
                "account-count-preserved",
                "selected-wallet-preserved",
                "keychain-identity-preserved",
                "legacy-store-retained",
            ]
        case .rollback:
            return [
                "rollback-failed-closed",
                "live-store-preserved",
                "keychain-identity-preserved",
            ]
        case .lowStorage:
            return [
                "low-storage-failed-closed",
                "live-store-preserved",
                "recovery-evidence-retained",
            ]
        case .recoveryArchiveExport:
            return [
                "archive-complete",
                "archive-protection-complete",
                "live-store-preserved",
            ]
        case .processDeathRestart:
            return [
                "journal-resumed",
                "no-mutation-retry",
                "selected-wallet-preserved",
            ]
        case .interruptionBeforeSecretRetention:
            return ["recovery-required", "no-live-store-loss"]
        case .interruptionAfterSecretRetention:
            return ["recovery-required", "keychain-bytes-preserved"]
        case .interruptionAfterCoreDataCommit:
            return ["recovery-required", "core-data-commit-preserved"]
        case .interruptionAfterNetworkStaging:
            return ["recovery-required", "staged-network-not-activated"]
        case .interruptionBeforeActivation:
            return ["recovery-required", "active-snapshot-unchanged"]
        }
    }
}

private struct ValidatedDeviceEvent {
    let scenario: DeviceScenario
    let startedAtEpochSeconds: Int64
    let finishedAtEpochSeconds: Int64
    let assertions: [String]

    var jsonObject: [String: Any] {
        [
            "scenario": scenario.rawValue,
            "outcome": "passed",
            "startedAtEpochSeconds": startedAtEpochSeconds,
            "finishedAtEpochSeconds": finishedAtEpochSeconds,
            "assertions": assertions,
        ]
    }
}

private enum MigrationEvidenceFileReader {
    static func requireDirectory(at url: URL, ownerOnly: Bool, label: String) throws {
        var metadata = stat()
        guard Darwin.lstat(url.path, &metadata) == 0 else {
            throw MigrationEvidenceError("the fixed \(label) is unavailable")
        }
        guard
            (metadata.st_mode & mode_t(S_IFMT)) == mode_t(S_IFDIR),
            metadata.st_uid == geteuid(),
            !ownerOnly || (metadata.st_mode & mode_t(0o077)) == 0
        else {
            throw MigrationEvidenceError("the fixed \(label) is not an owned protected directory")
        }
    }

    static func readProtectedRegularFile(at url: URL, maximumBytes: Int64) throws -> Data {
        let descriptor = Darwin.open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        guard descriptor >= 0 else {
            throw MigrationEvidenceError("the protected observation ledger cannot be opened")
        }
        defer { Darwin.close(descriptor) }

        var before = stat()
        guard Darwin.fstat(descriptor, &before) == 0 else {
            throw MigrationEvidenceError("the protected observation-ledger metadata is unavailable")
        }
        try MigrationEvidenceValidation.requireUniqueBoundedRegularFile(
            before,
            maximumBytes: maximumBytes,
            label: "protected observation ledger"
        )
        guard before.st_uid == geteuid(), (before.st_mode & mode_t(0o077)) == 0 else {
            throw MigrationEvidenceError("the observation ledger is not an owner-only file")
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard
            let protection = attributes[.protectionKey] as? FileProtectionType,
            protection == .complete
        else {
            throw MigrationEvidenceError("the observation ledger lacks complete data protection")
        }

        var data = Data()
        data.reserveCapacity(Int(before.st_size))
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        while true {
            let count: Int = try buffer.withUnsafeMutableBytes { rawBuffer in
                while true {
                    let result = Darwin.read(descriptor, rawBuffer.baseAddress, rawBuffer.count)
                    if result < 0, errno == EINTR {
                        continue
                    }
                    guard result >= 0 else {
                        throw MigrationEvidenceError("the protected observation ledger cannot be read")
                    }
                    return result
                }
            }
            if count == 0 {
                break
            }
            data.append(contentsOf: buffer[0 ..< count])
            guard data.count <= maximumBytes else {
                throw MigrationEvidenceError("the protected observation ledger exceeds its byte bound")
            }
        }

        var afterDescriptor = stat()
        var afterPath = stat()
        guard
            Darwin.fstat(descriptor, &afterDescriptor) == 0,
            Darwin.lstat(url.path, &afterPath) == 0,
            data.count == Int(before.st_size),
            MigrationEvidenceValidation.sameStableFile(before, afterDescriptor),
            MigrationEvidenceValidation.sameStableFile(before, afterPath)
        else {
            throw MigrationEvidenceError("the observation ledger changed during protected read")
        }
        return data
    }
}

private enum StrictMigrationJSON {
    static func object(fromCanonicalData data: Data) throws -> [String: Any] {
        guard
            !data.isEmpty,
            data.last == 0x0A,
            !data.starts(with: [0xEF, 0xBB, 0xBF]),
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw MigrationEvidenceError("the observation ledger is not a canonical JSON object")
        }
        guard try canonicalData(for: object) == data else {
            throw MigrationEvidenceError("the observation ledger is not exact canonical JSON")
        }
        return object
    }

    static func canonicalData(for object: [String: Any]) throws -> Data {
        guard JSONSerialization.isValidJSONObject(object) else {
            throw MigrationEvidenceError("migration evidence cannot be represented as strict JSON")
        }
        var data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        data.append(0x0A)
        return data
    }

    static func requireExactKeys(
        _ object: [String: Any],
        _ expected: Set<String>,
        label: String
    ) throws {
        guard Set(object.keys) == expected else {
            throw MigrationEvidenceError("\(label) contains missing or unreviewed fields")
        }
    }

    static func dictionary(_ value: Any?, label: String) throws -> [String: Any] {
        guard let object = value as? [String: Any] else {
            throw MigrationEvidenceError("\(label) is not an exact JSON object")
        }
        return object
    }

    static func array(_ value: Any?, label: String) throws -> [Any] {
        guard let array = value as? [Any] else {
            throw MigrationEvidenceError("\(label) is not an exact JSON array")
        }
        return array
    }

    static func string(_ value: Any?, label: String) throws -> String {
        guard
            let string = value as? String,
            !string.isEmpty,
            string.utf8.count <= 256,
            string == string.trimmingCharacters(in: .whitespacesAndNewlines)
        else {
            throw MigrationEvidenceError("\(label) is not a bounded exact string")
        }
        return string
    }

    static func boolean(_ value: Any?, label: String) throws -> Bool {
        guard
            let number = value as? NSNumber,
            CFGetTypeID(number) == CFBooleanGetTypeID()
        else {
            throw MigrationEvidenceError("\(label) is not an exact JSON boolean")
        }
        return number.boolValue
    }

    static func integer(_ value: Any?, label: String) throws -> Int64 {
        guard
            let number = value as? NSNumber,
            CFGetTypeID(number) != CFBooleanGetTypeID(),
            !CFNumberIsFloatType(number),
            let integer = Int64(number.stringValue),
            number.stringValue == String(integer)
        else {
            throw MigrationEvidenceError("\(label) is not an exact bounded JSON integer")
        }
        return integer
    }
}

private enum MigrationEvidenceValidation {
    static func isLowercaseHex(_ value: String, count: Int) -> Bool {
        guard value.utf8.count == count, value != String(repeating: "0", count: count) else {
            return false
        }
        return value.utf8.allSatisfy { byte in
            (48 ... 57).contains(byte) || (97 ... 102).contains(byte)
        }
    }

    static func requireUniqueBoundedRegularFile(
        _ metadata: stat,
        maximumBytes: Int64,
        label: String
    ) throws {
        guard
            (metadata.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG),
            metadata.st_nlink == 1,
            metadata.st_size > 0,
            metadata.st_size <= maximumBytes
        else {
            throw MigrationEvidenceError("the \(label) is not a unique bounded regular file")
        }
    }

    static func sameStableFile(_ lhs: stat, _ rhs: stat) -> Bool {
        lhs.st_dev == rhs.st_dev &&
            lhs.st_ino == rhs.st_ino &&
            lhs.st_mode == rhs.st_mode &&
            lhs.st_nlink == rhs.st_nlink &&
            lhs.st_uid == rhs.st_uid &&
            lhs.st_size == rhs.st_size &&
            lhs.st_mtimespec.tv_sec == rhs.st_mtimespec.tv_sec &&
            lhs.st_mtimespec.tv_nsec == rhs.st_mtimespec.tv_nsec &&
            lhs.st_ctimespec.tv_sec == rhs.st_ctimespec.tv_sec &&
            lhs.st_ctimespec.tv_nsec == rhs.st_ctimespec.tv_nsec
    }

    static func sha256(_ data: Data) -> String {
        hex(Data(SHA256.hash(data: data)))
    }

    static func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}

private struct MigrationEvidenceError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
