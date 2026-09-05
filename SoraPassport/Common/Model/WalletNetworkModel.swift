// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import CommonCrypto
import CryptoKit
import Darwin
import Foundation
import IrohaCrypto
import RobinHood
import SoraKeystore
import SSFCrypto
import SSFUtils

/// Normalizes only Foundation's reviewed file-protection values. Callers must
/// treat missing, malformed, or future unknown metadata as a verification
/// failure instead of allowing two absent attributes to compare as equal.
enum FileProtectionMetadata {
    enum Failure: Error {
        case unavailable
    }

    private static let reviewedRawValues: Set<String> = [
        FileProtectionType.none.rawValue,
        FileProtectionType.complete.rawValue,
        FileProtectionType.completeUnlessOpen.rawValue,
        FileProtectionType.completeUntilFirstUserAuthentication.rawValue,
    ]

    #if targetEnvironment(simulator)
        /// CoreSimulator's host-backed filesystem does not expose
        /// `NSFileProtectionKey`, even after Foundation accepts the requested
        /// class. Keep a test-only inode xattr so simulator tests can exercise
        /// the same rename, hard-link, rollback, and mismatch state machine.
        /// Device builds never compile this fallback and still require the
        /// actual Foundation protection attribute.
        private static let simulatorAttributeName =
            "com.soramitsu.sora.simulator-file-protection"
        private static let maximumSimulatorAttributeBytes = 128
    #endif

    static func normalized(_ value: Any?) -> FileProtectionType? {
        let candidate: FileProtectionType
        if let typed = value as? FileProtectionType {
            candidate = typed
        } else if let rawValue = value as? String {
            candidate = FileProtectionType(rawValue: rawValue)
        } else {
            return nil
        }
        guard reviewedRawValues.contains(candidate.rawValue) else {
            return nil
        }
        return candidate
    }

    static func protectionClass(
        at url: URL,
        fileManager: FileManager
    ) throws -> FileProtectionType {
        let attributes = try fileManager.attributesOfItem(
            atPath: url.path
        )
        if let rawProtection = attributes[.protectionKey] {
            guard let protection = normalized(rawProtection) else {
                throw Failure.unavailable
            }
            return protection
        }
        #if targetEnvironment(simulator)
            return try simulatorProtectionClass(at: url)
        #else
            throw Failure.unavailable
        #endif
    }

    static func setProtectionClass(
        _ protection: FileProtectionType,
        at url: URL,
        fileManager: FileManager
    ) throws {
        guard reviewedRawValues.contains(protection.rawValue) else {
            throw Failure.unavailable
        }
        try fileManager.setAttributes(
            [.protectionKey: protection],
            ofItemAtPath: url.path
        )
        #if targetEnvironment(simulator)
            let encoded = Data(protection.rawValue.utf8)
            let result = encoded.withUnsafeBytes { bytes -> Int32 in
                guard let baseAddress = bytes.baseAddress else {
                    return -1
                }
                return simulatorAttributeName.withCString { name in
                    url.withUnsafeFileSystemRepresentation { path in
                        guard let path else {
                            return -1
                        }
                        return Darwin.setxattr(
                            path,
                            name,
                            baseAddress,
                            bytes.count,
                            0,
                            XATTR_NOFOLLOW
                        )
                    }
                }
            }
            guard result == 0 else {
                throw Failure.unavailable
            }
        #endif
    }

    #if targetEnvironment(simulator)
        private static func simulatorProtectionClass(
            at url: URL
        ) throws -> FileProtectionType {
            let byteCount = simulatorAttributeName.withCString { name in
                url.withUnsafeFileSystemRepresentation { path in
                    guard let path else {
                        return ssize_t(-1)
                    }
                    return Darwin.getxattr(
                        path,
                        name,
                        nil,
                        0,
                        0,
                        XATTR_NOFOLLOW
                    )
                }
            }
            guard
                byteCount > 0,
                byteCount <= maximumSimulatorAttributeBytes
            else {
                throw Failure.unavailable
            }
            var encoded = Data(count: byteCount)
            let actualCount = encoded.withUnsafeMutableBytes { bytes in
                simulatorAttributeName.withCString { name in
                    url.withUnsafeFileSystemRepresentation { path in
                        guard let path, let baseAddress = bytes.baseAddress else {
                            return ssize_t(-1)
                        }
                        return Darwin.getxattr(
                            path,
                            name,
                            baseAddress,
                            bytes.count,
                            0,
                            XATTR_NOFOLLOW
                        )
                    }
                }
            }
            guard
                actualCount == byteCount,
                let rawValue = String(data: encoded, encoding: .utf8),
                let protection = normalized(rawValue)
            else {
                throw Failure.unavailable
            }
            return protection
        }
    #endif
}

/// Admission for a terminal Core Data migration attempt. Durable publication
/// can intentionally retain a hidden old or failed-new inode when cleanup or
/// rollback cannot be proved. Such an entry is recovery evidence: it must make
/// the attempt unresolved, never be deleted automatically, and never be
/// ignored merely because the canonical journal decodes as `activated`.
enum WalletMigrationSafetyNamespaceAdmission {
    enum Failure: Error {
        case invalidAttemptNamespace
    }

    private static let expectedActivatedAttemptRootNames: Set<String> = [
        "account-manifest.json",
        "journal.json",
        "legacy-store",
        "settings-backup.plist",
        "staging",
    ]
    private static let expectedRegularFileNames: Set<String> = [
        "account-manifest.json",
        "journal.json",
        "settings-backup.plist",
    ]
    private static let expectedDirectoryNames: Set<String> = [
        "legacy-store",
        "staging",
    ]

    static func isExactActivatedAttemptRoot(
        at attemptURL: URL,
        fileManager: FileManager
    ) throws -> Bool {
        guard try entryKindNoFollow(at: attemptURL) == mode_t(S_IFDIR) else {
            return false
        }
        let entries = try fileManager.contentsOfDirectory(
            at: attemptURL,
            includingPropertiesForKeys: nil,
            options: []
        )
        guard
            entries.count == expectedActivatedAttemptRootNames.count,
            Set(entries.map(\.lastPathComponent)) ==
                expectedActivatedAttemptRootNames
        else {
            return false
        }
        for entry in entries {
            let name = entry.lastPathComponent
            let expectedKind: mode_t
            if expectedRegularFileNames.contains(name) {
                expectedKind = mode_t(S_IFREG)
            } else if expectedDirectoryNames.contains(name) {
                expectedKind = mode_t(S_IFDIR)
            } else {
                return false
            }
            guard try entryKindNoFollow(at: entry) == expectedKind else {
                return false
            }
        }
        return true
    }

    static func isRegularFileNoFollow(at url: URL) throws -> Bool {
        try entryKindNoFollow(at: url) == mode_t(S_IFREG)
    }

    private static func entryKindNoFollow(at url: URL) throws -> mode_t {
        var metadata = stat()
        let result = url.withUnsafeFileSystemRepresentation { path -> Int32 in
            guard let path else {
                return -1
            }
            return Darwin.lstat(path, &metadata)
        }
        guard result == 0 else {
            throw Failure.invalidAttemptNamespace
        }
        return metadata.st_mode & mode_t(S_IFMT)
    }
}

/// Crash-durable publication for small migration records and activation
/// pointers. The replacement is prepared in the target directory, synced,
/// renamed atomically, and followed by directory and bounded ancestor syncs.
/// Existing targets are
/// accepted only when they are regular files; their protection class and
/// POSIX permissions are carried onto the replacement.
enum DurableFileWriter {
    enum Failure: LocalizedError {
        case invalidTarget
        case fileSystemFailure

        var errorDescription: String? {
            switch self {
            case .invalidTarget:
                return "The durable wallet file target is invalid."
            case .fileSystemFailure:
                return "The durable wallet file could not be committed."
            }
        }
    }

    private struct FileIdentity: Equatable {
        let device: dev_t
        let inode: ino_t
    }

    private struct FileState: Equatable {
        let identity: FileIdentity
        let permissions: mode_t
    }

    static func write(
        _ data: Data,
        to targetURL: URL,
        fileManager: FileManager,
        protection: FileProtectionType,
        afterAtomicPublication: ((URL) throws -> Void)? = nil
    ) throws {
        let context = try openValidatedDirectory(
            containing: targetURL
        )
        defer { _ = Darwin.close(context.descriptor) }

        let originalState = try regularFileState(
            named: context.targetName,
            in: context.descriptor
        )
        let originalProtection: FileProtectionType?
        if let originalState {
            do {
                originalProtection = try FileProtectionMetadata
                    .protectionClass(
                        at: targetURL,
                        fileManager: fileManager
                    )
            } catch {
                throw Failure.invalidTarget
            }
            guard
                try regularFileState(
                    named: context.targetName,
                    in: context.descriptor
                ) == originalState
            else {
                throw Failure.invalidTarget
            }
            guard originalProtection != nil else {
                throw Failure.invalidTarget
            }
        } else {
            originalProtection = nil
        }

        let temporaryName = ".durable-\(UUID().uuidString).tmp"
        let rollbackName =
            ".durable-rollback-\(UUID().uuidString).anchor"
        let temporaryURL = context.directoryURL
            .appendingPathComponent(temporaryName)
        let rollbackURL = context.directoryURL
            .appendingPathComponent(rollbackName)
        let descriptor = Darwin.openat(
            context.descriptor,
            temporaryName,
            O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC,
            mode_t(0o600)
        )
        guard descriptor >= 0 else {
            throw Failure.fileSystemFailure
        }

        var temporaryIdentity: FileIdentity?
        var rollbackIdentity: FileIdentity?
        var wasRenamed = false
        defer {
            _ = Darwin.close(descriptor)
            if !wasRenamed, let temporaryIdentity {
                let retained = try? regularFileState(
                    named: temporaryName,
                    in: context.descriptor
                )
                if retained?.identity == temporaryIdentity {
                    let result = Darwin.unlinkat(
                        context.descriptor,
                        temporaryName,
                        0
                    )
                    if result == 0 {
                        _ = Darwin.fsync(context.descriptor)
                    }
                }
            }
        }

        let openedState = try regularDescriptorState(descriptor)
        temporaryIdentity = openedState.identity
        let permissions = originalState?.permissions ?? mode_t(0o600)
        guard Darwin.fchmod(descriptor, permissions) == 0 else {
            throw Failure.fileSystemFailure
        }
        let retainedProtection = originalProtection ?? protection
        do {
            try FileProtectionMetadata.setProtectionClass(
                retainedProtection,
                at: temporaryURL,
                fileManager: fileManager
            )
            guard
                try FileProtectionMetadata.protectionClass(
                    at: temporaryURL,
                    fileManager: fileManager
                ) == retainedProtection
            else {
                throw Failure.fileSystemFailure
            }
        } catch {
            throw Failure.fileSystemFailure
        }
        guard Darwin.fchmod(descriptor, permissions) == 0 else {
            throw Failure.fileSystemFailure
        }
        guard
            let stagedState = try regularFileState(
                named: temporaryName,
                in: context.descriptor
            ),
            stagedState.identity == temporaryIdentity,
            stagedState.permissions == permissions
        else {
            throw Failure.invalidTarget
        }

        try writeAll(data, to: descriptor)
        try synchronize(descriptor)

        guard try regularFileState(
            named: temporaryName,
            in: context.descriptor
        )?.identity == temporaryIdentity else {
            throw Failure.invalidTarget
        }
        let currentTargetState = try regularFileState(
            named: context.targetName,
            in: context.descriptor
        )
        guard currentTargetState == originalState else {
            throw Failure.invalidTarget
        }
        if originalState != nil {
            do {
                guard
                    try FileProtectionMetadata.protectionClass(
                        at: targetURL,
                        fileManager: fileManager
                    ) == retainedProtection
                else {
                    throw Failure.invalidTarget
                }
            } catch {
                throw Failure.invalidTarget
            }
        }

        // Keep the exact old inode under a random, exclusive hidden name until
        // the atomically published replacement has passed its final identity
        // and protection checks. A failed rollback deliberately leaves this
        // anchor untouched; it is recovery evidence, not an automatically
        // discoverable/exportable backup. Once linkat succeeds, no defer path
        // removes the anchor: a concurrent target change could make it the only
        // remaining name for the original inode. Only committed-success cleanup
        // or an identity-verified atomic rollback may consume it.
        if let originalState {
            guard
                Darwin.linkat(
                    context.descriptor,
                    context.targetName,
                    context.descriptor,
                    rollbackName,
                    0
                ) == 0
            else {
                throw Failure.fileSystemFailure
            }
            rollbackIdentity = originalState.identity
            do {
                guard
                    try regularFileState(
                        named: rollbackName,
                        in: context.descriptor
                    ) == originalState,
                    try FileProtectionMetadata.protectionClass(
                        at: rollbackURL,
                        fileManager: fileManager
                    ) == retainedProtection,
                    try regularFileState(
                        named: context.targetName,
                        in: context.descriptor
                    ) == originalState,
                    try FileProtectionMetadata.protectionClass(
                        at: targetURL,
                        fileManager: fileManager
                    ) == retainedProtection
                else {
                    throw Failure.invalidTarget
                }
                try synchronize(context.descriptor)
                try synchronizeAncestorDirectoryEntries(
                    from: context.descriptor,
                    maximumDepth: 4
                )
            } catch {
                throw Failure.invalidTarget
            }
        }
        do {
            if let originalState {
                // Exchange the prepared inode with the existing target instead
                // of overwriting a name after a racy identity precheck. The
                // displaced inode remains under the random temporary name and
                // must be the exact old inode already retained by rollbackName.
                // If another writer won the name, exchange it back and preserve
                // every name. Every throwing step after this exchange is also
                // enclosed by the publication recovery catch below.
                guard
                    let preparedIdentity = temporaryIdentity,
                    try regularFileState(
                        named: temporaryName,
                        in: context.descriptor
                    )?.identity == preparedIdentity,
                    try FileProtectionMetadata.protectionClass(
                        at: temporaryURL,
                        fileManager: fileManager
                    ) == retainedProtection
                else {
                    throw Failure.fileSystemFailure
                }
                guard
                    Darwin.renameatx_np(
                        context.descriptor,
                        temporaryName,
                        context.descriptor,
                        context.targetName,
                        UInt32(RENAME_SWAP)
                    ) == 0
                else {
                    throw Failure.fileSystemFailure
                }
                wasRenamed = true
                let displacedIdentity = try entryIdentity(
                    named: temporaryName,
                    in: context.descriptor
                )
                do {
                    guard
                        displacedIdentity == originalState.identity,
                        try regularFileState(
                            named: temporaryName,
                            in: context.descriptor
                        ) == originalState,
                        try FileProtectionMetadata.protectionClass(
                            at: temporaryURL,
                            fileManager: fileManager
                        ) == retainedProtection,
                        try regularFileState(
                            named: rollbackName,
                            in: context.descriptor
                        ) == originalState,
                        try FileProtectionMetadata.protectionClass(
                            at: rollbackURL,
                            fileManager: fileManager
                        ) == retainedProtection,
                        try regularFileState(
                            named: context.targetName,
                            in: context.descriptor
                        )?.identity == temporaryIdentity
                    else {
                        throw Failure.invalidTarget
                    }
                } catch {
                    if let displacedIdentity,
                       let temporaryIdentity
                    {
                        _ = reverseRejectedAtomicSwap(
                            displacedName: temporaryName,
                            displacedIdentity: displacedIdentity,
                            targetName: context.targetName,
                            publishedIdentity: temporaryIdentity,
                            context: context
                        )
                    }
                    // Never unlink either the displaced name or rollback anchor
                    // after a rejected exchange. They are the only bounded way
                    // to preserve both the concurrent target and the old wallet
                    // inode when reversal cannot be proved.
                    throw Failure.fileSystemFailure
                }
            } else {
                // A concurrently created target must never be overwritten when
                // the initial inventory observed no file.
                guard
                    let preparedIdentity = temporaryIdentity,
                    try regularFileState(
                        named: temporaryName,
                        in: context.descriptor
                    )?.identity == preparedIdentity,
                    try FileProtectionMetadata.protectionClass(
                        at: temporaryURL,
                        fileManager: fileManager
                    ) == retainedProtection
                else {
                    throw Failure.fileSystemFailure
                }
                guard
                    Darwin.renameatx_np(
                        context.descriptor,
                        temporaryName,
                        context.descriptor,
                        context.targetName,
                        UInt32(RENAME_EXCL)
                    ) == 0
                else {
                    throw Failure.fileSystemFailure
                }
                wasRenamed = true
            }
            try afterAtomicPublication?(targetURL)
            try synchronize(context.descriptor)
            try synchronizeAncestorDirectoryEntries(
                from: context.descriptor,
                maximumDepth: 4
            )
            guard try regularFileState(
                named: context.targetName,
                in: context.descriptor
            )?.identity == temporaryIdentity else {
                throw Failure.fileSystemFailure
            }
            guard
                try FileProtectionMetadata.protectionClass(
                    at: targetURL,
                    fileManager: fileManager
                ) == retainedProtection
            else {
                throw Failure.fileSystemFailure
            }
            if
                let originalState,
                let retainedRollbackIdentity = rollbackIdentity,
                let publishedIdentity = temporaryIdentity
            {
                // The new target is already identity/protection verified and
                // its publication is directory/ancestor synced. Anchor cleanup
                // is therefore non-failing: an exact old anchor is removed
                // best-effort, while any cleanup or sync failure leaves it in
                // place and must not turn a committed write into an ambiguous
                // thrown failure.
                let didRemoveDisplacedOriginal =
                    discardRollbackAnchorAfterCommit(
                        rollbackName: temporaryName,
                        rollbackURL: temporaryURL,
                        originalState: originalState,
                        rollbackIdentity: retainedRollbackIdentity,
                        publishedIdentity: publishedIdentity,
                        targetURL: targetURL,
                        retainedProtection: retainedProtection,
                        context: context,
                        fileManager: fileManager
                    )
                if didRemoveDisplacedOriginal {
                    let didRemoveRollback =
                        discardRollbackAnchorAfterCommit(
                            rollbackName: rollbackName,
                            rollbackURL: rollbackURL,
                            originalState: originalState,
                            rollbackIdentity: retainedRollbackIdentity,
                            publishedIdentity: publishedIdentity,
                            targetURL: targetURL,
                            retainedProtection: retainedProtection,
                            context: context,
                            fileManager: fileManager
                        )
                    if didRemoveRollback {
                        rollbackIdentity = nil
                    }
                }
            }
        } catch {
            if let originalState, rollbackIdentity != nil {
                do {
                    try restoreOriginalAfterFailedPublication(
                        rollbackName: rollbackName,
                        rollbackURL: rollbackURL,
                        originalState: originalState,
                        publishedIdentity: temporaryIdentity,
                        displacedOriginalName: temporaryName,
                        displacedOriginalURL: temporaryURL,
                        targetURL: targetURL,
                        retainedProtection: retainedProtection,
                        context: context,
                        fileManager: fileManager
                    )
                    rollbackIdentity = nil
                } catch {
                    // A failed rollback preserves at least one exact old-inode
                    // name: rollbackName before the exchange, the displaced
                    // original temporary name after publication, or the second
                    // safety anchor created by the rollback routine.
                }
            } else if originalState == nil {
                try? removeFailedNewPublication(
                    publishedIdentity: temporaryIdentity,
                    retainedProtection: retainedProtection,
                    context: context,
                    fileManager: fileManager
                )
            }
            if let publishedIdentity = temporaryIdentity {
                try? protectOrRemoveHiddenFailedPublication(
                    named: temporaryName,
                    at: temporaryURL,
                    publishedIdentity: publishedIdentity,
                    retainedProtection: retainedProtection,
                    context: context,
                    fileManager: fileManager
                )
                try? protectOrRemoveHiddenFailedPublication(
                    named: rollbackName,
                    at: rollbackURL,
                    publishedIdentity: publishedIdentity,
                    retainedProtection: retainedProtection,
                    context: context,
                    fileManager: fileManager
                )
            }
            throw Failure.fileSystemFailure
        }
    }

    private static func restoreOriginalAfterFailedPublication(
        rollbackName: String,
        rollbackURL: URL,
        originalState: FileState,
        publishedIdentity: FileIdentity?,
        displacedOriginalName: String,
        displacedOriginalURL: URL,
        targetURL: URL,
        retainedProtection: FileProtectionType,
        context: DirectoryContext,
        fileManager: FileManager
    ) throws {
        let safetyName =
            ".durable-rollback-\(UUID().uuidString).safety-anchor"
        let safetyURL = context.directoryURL
            .appendingPathComponent(safetyName)
        guard
            let publishedIdentity,
            try regularFileState(
                named: rollbackName,
                in: context.descriptor
            ) == originalState,
            try FileProtectionMetadata.protectionClass(
                at: rollbackURL,
                fileManager: fileManager
            ) == retainedProtection,
            try regularFileState(
                named: displacedOriginalName,
                in: context.descriptor
            ) == originalState,
            try FileProtectionMetadata.protectionClass(
                at: displacedOriginalURL,
                fileManager: fileManager
            ) == retainedProtection,
            try regularFileState(
                named: context.targetName,
                in: context.descriptor
            )?.identity == publishedIdentity
        else {
            throw Failure.fileSystemFailure
        }

        // The rollback exchange consumes rollbackName. First create a second
        // exclusive hard link to the exact old inode, then make both names and
        // their typed protection metadata durable. Any later error leaves the
        // old inode reachable through safetyName or displacedOriginalName.
        guard
            Darwin.linkat(
                context.descriptor,
                rollbackName,
                context.descriptor,
                safetyName,
                0
            ) == 0
        else {
            throw Failure.fileSystemFailure
        }
        do {
            guard
                try regularFileState(
                    named: rollbackName,
                    in: context.descriptor
                ) == originalState,
                try FileProtectionMetadata.protectionClass(
                    at: rollbackURL,
                    fileManager: fileManager
                ) == retainedProtection,
                try regularFileState(
                    named: safetyName,
                    in: context.descriptor
                ) == originalState,
                try FileProtectionMetadata.protectionClass(
                    at: safetyURL,
                    fileManager: fileManager
                ) == retainedProtection,
                try regularFileState(
                    named: displacedOriginalName,
                    in: context.descriptor
                ) == originalState,
                try FileProtectionMetadata.protectionClass(
                    at: displacedOriginalURL,
                    fileManager: fileManager
                ) == retainedProtection,
                try regularFileState(
                    named: context.targetName,
                    in: context.descriptor
                )?.identity == publishedIdentity
            else {
                throw Failure.fileSystemFailure
            }
            try synchronize(context.descriptor)
            try synchronizeAncestorDirectoryEntries(
                from: context.descriptor,
                maximumDepth: 4
            )
        } catch {
            throw Failure.fileSystemFailure
        }

        guard
            Darwin.renameatx_np(
                context.descriptor,
                rollbackName,
                context.descriptor,
                context.targetName,
                UInt32(RENAME_SWAP)
            ) == 0
        else {
            throw Failure.fileSystemFailure
        }
        let displacedIdentity = try entryIdentity(
            named: rollbackName,
            in: context.descriptor
        )
        guard displacedIdentity == publishedIdentity else {
            if let displacedIdentity {
                _ = reverseRejectedAtomicSwap(
                    displacedName: rollbackName,
                    displacedIdentity: displacedIdentity,
                    targetName: context.targetName,
                    publishedIdentity: originalState.identity,
                    context: context
                )
            }
            // Whether reversal succeeds or not, the concurrently displaced
            // inode remains named by rollbackName or targetName, and the old
            // wallet inode remains named by safetyName/displacedOriginalName.
            throw Failure.fileSystemFailure
        }

        guard
            try regularFileState(
                named: context.targetName,
                in: context.descriptor
            ) == originalState,
            try FileProtectionMetadata.protectionClass(
                at: targetURL,
                fileManager: fileManager
            ) == retainedProtection,
            try regularFileState(
                named: safetyName,
                in: context.descriptor
            ) == originalState,
            try FileProtectionMetadata.protectionClass(
                at: safetyURL,
                fileManager: fileManager
            ) == retainedProtection,
            try regularFileState(
                named: displacedOriginalName,
                in: context.descriptor
            ) == originalState,
            try FileProtectionMetadata.protectionClass(
                at: displacedOriginalURL,
                fileManager: fileManager
            ) == retainedProtection,
            try regularFileState(
                named: rollbackName,
                in: context.descriptor
            )?.identity == publishedIdentity
        else {
            throw Failure.fileSystemFailure
        }
        try synchronize(context.descriptor)
        try synchronizeAncestorDirectoryEntries(
            from: context.descriptor,
            maximumDepth: 4
        )
        guard
            try regularFileState(
                named: context.targetName,
                in: context.descriptor
            ) == originalState,
            try FileProtectionMetadata.protectionClass(
                at: targetURL,
                fileManager: fileManager
            ) == retainedProtection,
            try regularFileState(
                named: safetyName,
                in: context.descriptor
            ) == originalState,
            try FileProtectionMetadata.protectionClass(
                at: safetyURL,
                fileManager: fileManager
            ) == retainedProtection,
            try regularFileState(
                named: displacedOriginalName,
                in: context.descriptor
            ) == originalState,
            try regularFileState(
                named: rollbackName,
                in: context.descriptor
            )?.identity == publishedIdentity
        else {
            throw Failure.fileSystemFailure
        }

        try protectOrRemoveHiddenFailedPublication(
            named: rollbackName,
            at: rollbackURL,
            publishedIdentity: publishedIdentity,
            retainedProtection: retainedProtection,
            context: context,
            fileManager: fileManager
        )

        // Rollback is already identity/protection verified and synced. Every
        // following cleanup is exact-identity and non-throwing, so a redundant
        // hidden name is retained rather than turning restoration into an
        // ambiguous failure.
        // rollbackName now either names the exact failed-new inode with the
        // intended protection class durably re-established, or that inode was
        // removed and its absence was proved.
        let didRemoveDisplacedOriginal =
            discardRollbackAnchorAfterCommit(
                rollbackName: displacedOriginalName,
                rollbackURL: displacedOriginalURL,
                originalState: originalState,
                rollbackIdentity: originalState.identity,
                publishedIdentity: originalState.identity,
                targetURL: targetURL,
                retainedProtection: retainedProtection,
                context: context,
                fileManager: fileManager
            )
        if didRemoveDisplacedOriginal {
            _ = discardRollbackAnchorAfterCommit(
                rollbackName: safetyName,
                rollbackURL: safetyURL,
                originalState: originalState,
                rollbackIdentity: originalState.identity,
                publishedIdentity: originalState.identity,
                targetURL: targetURL,
                retainedProtection: retainedProtection,
                context: context,
                fileManager: fileManager
            )
        }
    }

    private static func reverseRejectedAtomicSwap(
        displacedName: String,
        displacedIdentity: FileIdentity,
        targetName: String,
        publishedIdentity: FileIdentity,
        context: DirectoryContext
    ) -> Bool {
        guard
            (try? entryIdentity(
                named: displacedName,
                in: context.descriptor
            )) == displacedIdentity,
            (try? entryIdentity(
                named: targetName,
                in: context.descriptor
            )) == publishedIdentity,
            Darwin.renameatx_np(
                context.descriptor,
                displacedName,
                context.descriptor,
                targetName,
                UInt32(RENAME_SWAP)
            ) == 0,
            (try? entryIdentity(
                named: displacedName,
                in: context.descriptor
            )) == publishedIdentity,
            (try? entryIdentity(
                named: targetName,
                in: context.descriptor
            )) == displacedIdentity
        else {
            return false
        }
        do {
            try synchronize(context.descriptor)
            try synchronizeAncestorDirectoryEntries(
                from: context.descriptor,
                maximumDepth: 4
            )
            guard
                try entryIdentity(
                    named: displacedName,
                    in: context.descriptor
                ) == publishedIdentity,
                try entryIdentity(
                    named: targetName,
                    in: context.descriptor
                ) == displacedIdentity
            else {
                return false
            }
            return true
        } catch {
            return false
        }
    }

    private static func discardRollbackAnchorAfterCommit(
        rollbackName: String,
        rollbackURL: URL,
        originalState: FileState,
        rollbackIdentity: FileIdentity,
        publishedIdentity: FileIdentity,
        targetURL: URL,
        retainedProtection: FileProtectionType,
        context: DirectoryContext,
        fileManager: FileManager
    ) -> Bool {
        guard
            rollbackIdentity == originalState.identity,
            (try? regularFileState(
                named: rollbackName,
                in: context.descriptor
            ))?.identity == rollbackIdentity,
            (try? FileProtectionMetadata.protectionClass(
                at: rollbackURL,
                fileManager: fileManager
            )) == retainedProtection,
            (try? regularFileState(
                named: context.targetName,
                in: context.descriptor
            ))?.identity == publishedIdentity,
            (try? FileProtectionMetadata.protectionClass(
                at: targetURL,
                fileManager: fileManager
            )) == retainedProtection,
            Darwin.unlinkat(
                context.descriptor,
                rollbackName,
                0
            ) == 0
        else {
            return false
        }
        // Durability of removing a redundant old-inode anchor is desirable,
        // but it is not part of the already committed replacement result.
        try? synchronize(context.descriptor)
        try? synchronizeAncestorDirectoryEntries(
            from: context.descriptor,
            maximumDepth: 4
        )
        return true
    }

    private static func protectOrRemoveHiddenFailedPublication(
        named name: String,
        at url: URL,
        publishedIdentity: FileIdentity,
        retainedProtection: FileProtectionType,
        context: DirectoryContext,
        fileManager: FileManager
    ) throws {
        guard let initialState = try regularFileState(
            named: name,
            in: context.descriptor
        ) else {
            return
        }
        guard initialState.identity == publishedIdentity else {
            throw Failure.fileSystemFailure
        }

        do {
            try FileProtectionMetadata.setProtectionClass(
                retainedProtection,
                at: url,
                fileManager: fileManager
            )
            guard
                try regularFileState(
                    named: name,
                    in: context.descriptor
                )?.identity == publishedIdentity,
                try FileProtectionMetadata.protectionClass(
                    at: url,
                    fileManager: fileManager
                ) == retainedProtection
            else {
                throw Failure.fileSystemFailure
            }

            let descriptor = Darwin.openat(
                context.descriptor,
                name,
                O_RDONLY | O_NOFOLLOW | O_CLOEXEC
            )
            guard descriptor >= 0 else {
                throw Failure.fileSystemFailure
            }
            defer { _ = Darwin.close(descriptor) }
            guard
                try regularDescriptorState(descriptor).identity ==
                    publishedIdentity
            else {
                throw Failure.fileSystemFailure
            }
            try synchronize(descriptor)
            guard
                try regularFileState(
                    named: name,
                    in: context.descriptor
                )?.identity == publishedIdentity,
                try FileProtectionMetadata.protectionClass(
                    at: url,
                    fileManager: fileManager
                ) == retainedProtection
            else {
                throw Failure.fileSystemFailure
            }
            try synchronize(context.descriptor)
            try synchronizeAncestorDirectoryEntries(
                from: context.descriptor,
                maximumDepth: 4
            )
            guard
                try regularFileState(
                    named: name,
                    in: context.descriptor
                )?.identity == publishedIdentity,
                try FileProtectionMetadata.protectionClass(
                    at: url,
                    fileManager: fileManager
                ) == retainedProtection
            else {
                throw Failure.fileSystemFailure
            }
        } catch {
            try removeHiddenFailedPublicationIfExact(
                named: name,
                publishedIdentity: publishedIdentity,
                context: context
            )
        }
    }

    private static func removeHiddenFailedPublicationIfExact(
        named name: String,
        publishedIdentity: FileIdentity,
        context: DirectoryContext
    ) throws {
        guard
            try regularFileState(
                named: name,
                in: context.descriptor
            )?.identity == publishedIdentity
        else {
            throw Failure.fileSystemFailure
        }
        let unlinkResult = Darwin.unlinkat(
            context.descriptor,
            name,
            0
        )
        if unlinkResult != 0 {
            guard
                try entryIdentity(
                    named: name,
                    in: context.descriptor
                ) == nil
            else {
                throw Failure.fileSystemFailure
            }
        }
        guard
            try entryIdentity(
                named: name,
                in: context.descriptor
            ) == nil
        else {
            throw Failure.fileSystemFailure
        }
        try synchronize(context.descriptor)
        try synchronizeAncestorDirectoryEntries(
            from: context.descriptor,
            maximumDepth: 4
        )
        guard
            try entryIdentity(
                named: name,
                in: context.descriptor
            ) == nil
        else {
            throw Failure.fileSystemFailure
        }
    }

    private static func removeFailedNewPublication(
        publishedIdentity: FileIdentity?,
        retainedProtection: FileProtectionType,
        context: DirectoryContext,
        fileManager: FileManager
    ) throws {
        let withdrawnName =
            ".durable-failed-\(UUID().uuidString).withdrawn"
        let withdrawnURL = context.directoryURL.appendingPathComponent(
            withdrawnName
        )
        guard
            let publishedIdentity,
            try entryIdentity(
                named: context.targetName,
                in: context.descriptor
            ) == publishedIdentity,
            try entryIdentity(
                named: withdrawnName,
                in: context.descriptor
            ) == nil,
            Darwin.renameatx_np(
                context.descriptor,
                context.targetName,
                context.descriptor,
                withdrawnName,
                UInt32(RENAME_EXCL)
            ) == 0
        else {
            throw Failure.fileSystemFailure
        }

        let withdrawnIdentity = try entryIdentity(
            named: withdrawnName,
            in: context.descriptor
        )
        guard withdrawnIdentity == publishedIdentity else {
            // The target changed between observation and withdrawal. Restore
            // that exact concurrent entry only when the target is still absent;
            // otherwise preserve both names and let recovery/support decide.
            if
                let withdrawnIdentity,
                try entryIdentity(
                    named: context.targetName,
                    in: context.descriptor
                ) == nil,
                Darwin.renameatx_np(
                    context.descriptor,
                    withdrawnName,
                    context.descriptor,
                    context.targetName,
                    UInt32(RENAME_EXCL)
                ) == 0
            {
                try? synchronize(context.descriptor)
                try? synchronizeAncestorDirectoryEntries(
                    from: context.descriptor,
                    maximumDepth: 4
                )
                guard
                    try entryIdentity(
                        named: context.targetName,
                        in: context.descriptor
                    ) == withdrawnIdentity,
                    try entryIdentity(
                        named: withdrawnName,
                        in: context.descriptor
                    ) == nil
                else {
                    throw Failure.fileSystemFailure
                }
            }
            throw Failure.fileSystemFailure
        }
        try protectOrRemoveHiddenFailedPublication(
            named: withdrawnName,
            at: withdrawnURL,
            publishedIdentity: publishedIdentity,
            retainedProtection: retainedProtection,
            context: context,
            fileManager: fileManager
        )
        guard
            try entryIdentity(
                named: context.targetName,
                in: context.descriptor
            ) != publishedIdentity
        else {
            throw Failure.fileSystemFailure
        }
        if let retainedState = try regularFileState(
            named: withdrawnName,
            in: context.descriptor
        ) {
            guard
                retainedState.identity == publishedIdentity,
                try FileProtectionMetadata.protectionClass(
                    at: withdrawnURL,
                    fileManager: fileManager
                ) == retainedProtection
            else {
                throw Failure.fileSystemFailure
            }
        }
    }

    /// Makes a newly copied immutable backup durable before a journal can
    /// advertise it. The copy remains unpublished on any failure, while the
    /// live legacy source is never removed or rewritten.
    static func synchronizeRegularFileAndContainingDirectory(
        at targetURL: URL
    ) throws {
        let context = try openValidatedDirectory(
            containing: targetURL
        )
        defer { _ = Darwin.close(context.descriptor) }
        guard
            let expectedState = try regularFileState(
                named: context.targetName,
                in: context.descriptor
            )
        else {
            throw Failure.invalidTarget
        }
        let descriptor = Darwin.openat(
            context.descriptor,
            context.targetName,
            O_RDONLY | O_NOFOLLOW | O_CLOEXEC
        )
        guard descriptor >= 0 else {
            throw Failure.fileSystemFailure
        }
        defer { _ = Darwin.close(descriptor) }
        guard
            try regularDescriptorState(descriptor).identity ==
                expectedState.identity
        else {
            throw Failure.invalidTarget
        }
        try synchronize(descriptor)
        guard
            try regularFileState(
                named: context.targetName,
                in: context.descriptor
            ) == expectedState
        else {
            throw Failure.invalidTarget
        }
        try synchronize(context.descriptor)
        try synchronizeAncestorDirectoryEntries(
            from: context.descriptor,
            maximumDepth: 4
        )
    }

    private struct DirectoryContext {
        let directoryURL: URL
        let targetName: String
        let descriptor: Int32
    }

    private static func openValidatedDirectory(
        containing targetURL: URL
    ) throws -> DirectoryContext {
        let directoryURL = targetURL.deletingLastPathComponent()
        let targetName = targetURL.lastPathComponent
        guard
            targetURL.isFileURL,
            !targetName.isEmpty,
            targetName != ".",
            targetName != "..",
            !targetName.contains("\0"),
            targetName.utf8.count <= 255,
            targetURL.standardizedFileURL
                .deletingLastPathComponent().path ==
                directoryURL.standardizedFileURL.path
        else {
            throw Failure.invalidTarget
        }
        let descriptor = Darwin.open(
            directoryURL.path,
            O_RDONLY | O_NOFOLLOW | O_CLOEXEC
        )
        guard descriptor >= 0 else {
            throw Failure.invalidTarget
        }
        do {
            var status = stat()
            guard
                Darwin.fstat(descriptor, &status) == 0,
                (status.st_mode & mode_t(S_IFMT)) == mode_t(S_IFDIR)
            else {
                throw Failure.invalidTarget
            }
            return DirectoryContext(
                directoryURL: directoryURL,
                targetName: targetName,
                descriptor: descriptor
            )
        } catch {
            _ = Darwin.close(descriptor)
            throw error
        }
    }

    private static func regularFileState(
        named name: String,
        in directoryDescriptor: Int32
    ) throws -> FileState? {
        var status = stat()
        guard
            Darwin.fstatat(
                directoryDescriptor,
                name,
                &status,
                AT_SYMLINK_NOFOLLOW
            ) == 0
        else {
            if errno == ENOENT {
                return nil
            }
            throw Failure.fileSystemFailure
        }
        guard
            (status.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG)
        else {
            throw Failure.invalidTarget
        }
        return FileState(
            identity: FileIdentity(
                device: status.st_dev,
                inode: status.st_ino
            ),
            permissions: status.st_mode & mode_t(0o7777)
        )
    }

    /// Returns an identity without following the final component. This is used
    /// only to reverse an atomic exchange: even if a concurrent writer placed a
    /// non-regular entry, the displaced entry can be preserved and exchanged
    /// back instead of being overwritten or unlinked.
    private static func entryIdentity(
        named name: String,
        in directoryDescriptor: Int32
    ) throws -> FileIdentity? {
        var status = stat()
        guard
            Darwin.fstatat(
                directoryDescriptor,
                name,
                &status,
                AT_SYMLINK_NOFOLLOW
            ) == 0
        else {
            if errno == ENOENT {
                return nil
            }
            throw Failure.fileSystemFailure
        }
        return FileIdentity(
            device: status.st_dev,
            inode: status.st_ino
        )
    }

    private static func regularDescriptorState(
        _ descriptor: Int32
    ) throws -> FileState {
        var status = stat()
        guard
            Darwin.fstat(descriptor, &status) == 0,
            (status.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG)
        else {
            throw Failure.invalidTarget
        }
        return FileState(
            identity: FileIdentity(
                device: status.st_dev,
                inode: status.st_ino
            ),
            permissions: status.st_mode & mode_t(0o7777)
        )
    }

    private static func writeAll(
        _ data: Data,
        to descriptor: Int32
    ) throws {
        try data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            guard let baseAddress = bytes.baseAddress else {
                return
            }
            var offset = 0
            while offset < bytes.count {
                let written = Darwin.write(
                    descriptor,
                    baseAddress.advanced(by: offset),
                    bytes.count - offset
                )
                if written < 0, errno == EINTR {
                    continue
                }
                guard written > 0 else {
                    throw Failure.fileSystemFailure
                }
                offset += written
            }
        }
    }

    private static func synchronize(_ descriptor: Int32) throws {
        while Darwin.fsync(descriptor) != 0 {
            guard errno == EINTR else {
                throw Failure.fileSystemFailure
            }
        }
    }

    /// A file's directory sync does not make a newly-created directory entry
    /// durable in its own parent. Synchronize through the app container's
    /// bounded namespace (for example Library/Application Support/SORA/
    /// WalletNetworks) before advertising a successful commit.
    private static func synchronizeAncestorDirectoryEntries(
        from directoryDescriptor: Int32,
        maximumDepth: Int
    ) throws {
        guard maximumDepth >= 0 else {
            throw Failure.invalidTarget
        }
        var currentDescriptor = Darwin.dup(directoryDescriptor)
        guard currentDescriptor >= 0 else {
            throw Failure.fileSystemFailure
        }
        defer { _ = Darwin.close(currentDescriptor) }

        for _ in 0 ..< maximumDepth {
            let parentDescriptor = Darwin.openat(
                currentDescriptor,
                "..",
                O_RDONLY | O_NOFOLLOW | O_CLOEXEC
            )
            guard parentDescriptor >= 0 else {
                throw Failure.fileSystemFailure
            }
            do {
                var status = stat()
                guard
                    Darwin.fstat(parentDescriptor, &status) == 0,
                    (status.st_mode & mode_t(S_IFMT)) == mode_t(S_IFDIR)
                else {
                    throw Failure.invalidTarget
                }
                try synchronize(parentDescriptor)
            } catch {
                _ = Darwin.close(parentDescriptor)
                throw error
            }
            _ = Darwin.close(currentDescriptor)
            currentDescriptor = parentDescriptor
        }
    }
}

enum NetworkId: String, Codable, CaseIterable, Sendable {
    case sora2
    case minamoto
    case taira
}

enum WalletSecretSource: String, Codable {
    case mnemonicEntropy
    case legacyMnemonicEntropy
    case rawSeed
    case legacySecret
    case watchOnly
}

enum WalletMnemonicWordPolicy {
    static let userImportWordCounts: Set<Int> = [12, 24]
    static let retainedSoraWordCounts: Set<Int> = [12, 15, 18, 21, 24]

    static func isUserImportWordCount(_ count: Int) -> Bool {
        userImportWordCounts.contains(count)
    }

    static func retainedSecretSource(
        forWordCount count: Int
    ) -> WalletSecretSource? {
        switch count {
        case 12, 24:
            return .mnemonicEntropy
        case 15, 18, 21:
            // Released importers accepted every valid BIP39 phrase length.
            // Preserve those SORA2 identities even when their phrase length
            // is outside the Nexus derivation contract.
            return .legacyMnemonicEntropy
        default:
            return nil
        }
    }
}

struct WalletIdentity: Codable, Equatable, Swift.Identifiable {
    /// The existing SORA2 address is a stable local identifier. It is never
    /// sent as migration telemetry.
    let id: String
    let displayName: String
    let existingSoraAddress: String
    let secretSource: WalletSecretSource
}

struct NetworkAccount: Codable, Equatable, Swift.Identifiable, Sendable {
    var id: String { "\(walletId):\(networkId.rawValue)" }

    let walletId: String
    let networkId: NetworkId
    let derivationVersion: Int
    let publicKey: Data
    let address: String
}

struct WalletNetworkSnapshot: Codable, Equatable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let selectedWalletId: String?
    let wallets: [WalletIdentity]
    let accounts: [NetworkAccount]
    let createdAt: Date
}

enum WalletAccountCommitStage: String, Codable {
    case prepared
    case secretsPersisted
    case coreDataCommitted
    case networkModelActivated
    case activated
}

struct WalletAccountCommitJournal: Codable, Equatable {
    let id: UUID
    let walletId: String
    let expectedExistingWalletIds: [String]
    var stage: WalletAccountCommitStage
    let createdAt: Date
    var updatedAt: Date
}

/// Non-secret interruption journal for new/imported wallets. An unfinished
/// record forces recovery; it is never interpreted as permission to delete
/// Keychain or Core Data material.
final class WalletAccountCommitJournalStore {
    private static let lock = NSLock()
    private static let retainedActivatedJournals = 8
    private static let maximumJournalFiles = 16
    private static let maximumJournalBytes = 64 * 1_024
    private static let maximumJournalNamespaceBytes =
        maximumJournalFiles * maximumJournalBytes
    private static let maximumWalletsPerJournal = 4_096

    private let directoryURL: URL
    private let fileManager: FileManager
    private let recoveryGate: WalletRecoveryCapabilityGate
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        fileManager: FileManager = .default,
        baseURL: URL? = nil,
        recoveryGate: WalletRecoveryCapabilityGate = .shared
    ) throws {
        self.fileManager = fileManager
        self.recoveryGate = recoveryGate
        let base: URL
        if let baseURL {
            base = baseURL
        } else {
            base = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        }
        directoryURL = base
            .appendingPathComponent("SORA", isDirectory: true)
            .appendingPathComponent(
                "WalletAccountCommits",
                isDirectory: true
            )
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        try validateDirectory()
    }

    func begin(
        walletId: String,
        existingWalletIds: [String]
    ) throws -> WalletAccountCommitJournal {
        try recoveryGate
            .requireAuthorizedLifecycleContinuation()
        Self.lock.lock()
        defer { Self.lock.unlock() }
        let existingJournals = try loadUnlocked()
        guard
            existingJournals.count < Self.maximumJournalFiles,
            existingJournals.allSatisfy({
                $0.stage == .activated
            })
        else {
            throw WalletNetworkMigrationError
                .snapshotVerificationFailed
        }
        let now = Date()
        let journal = WalletAccountCommitJournal(
            id: UUID(),
            walletId: walletId,
            expectedExistingWalletIds: existingWalletIds.sorted(),
            stage: .prepared,
            createdAt: now,
            updatedAt: now
        )
        guard
            !fileManager.fileExists(
                atPath: journalURL(journal.id).path
            )
        else {
            throw WalletNetworkMigrationError
                .snapshotVerificationFailed
        }
        try writeUnlocked(journal)
        return journal
    }

    func advance(
        _ journal: WalletAccountCommitJournal,
        to stage: WalletAccountCommitStage
    ) throws -> WalletAccountCommitJournal {
        try recoveryGate
            .requireAuthorizedLifecycleContinuation()
        Self.lock.lock()
        defer { Self.lock.unlock() }
        do {
            let journals = try loadUnlocked()
            guard
                let current = journals.first(where: {
                    $0.id == journal.id
                }),
                Self.journalsMatch(current, journal),
                Self.canAdvance(from: current.stage, to: stage)
            else {
                throw WalletNetworkMigrationError
                    .snapshotVerificationFailed
            }
            var next = current
            next.stage = stage
            next.updatedAt = Date()
            if stage == .activated {
                // Cleanup completed evidence before the terminal transition.
                // If cleanup fails, this journal remains unresolved. Any
                // terminal error is also latched because an atomic replace
                // may have succeeded before its verification read failed.
                try pruneActivatedUnlocked(
                    retaining: Self.retainedActivatedJournals - 1
                )
            }
            try writeUnlocked(next)
            if stage == .activated {
                let verified = try loadUnlocked()
                guard
                    verified.count <= Self.retainedActivatedJournals,
                    verified.allSatisfy({ $0.stage == .activated }),
                    verified.contains(where: {
                        Self.journalsMatch($0, next)
                    })
                else {
                    throw WalletNetworkMigrationError
                        .snapshotVerificationFailed
                }
            }
            return next
        } catch {
            if stage == .activated {
                recoveryGate
                    .latchRecoveryAfterAmbiguousWalletCommit()
            }
            throw error
        }
    }

    func unresolved() throws -> [WalletAccountCommitJournal] {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        return try loadUnlocked().filter { $0.stage != .activated }
    }

    private func loadUnlocked() throws -> [WalletAccountCommitJournal] {
        try validateDirectory()
        let journalURLs: [URL]
        do {
            journalURLs = try fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [
                    .fileSizeKey,
                    .isRegularFileKey,
                    .isSymbolicLinkKey,
                ],
                options: []
            )
        } catch {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }
        guard journalURLs.count <= Self.maximumJournalFiles else {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }
        var remainingBytes = Self.maximumJournalNamespaceBytes
        for url in journalURLs {
            let values: URLResourceValues
            do {
                values = try url.resourceValues(
                    forKeys: [
                        .fileSizeKey,
                        .isRegularFileKey,
                        .isSymbolicLinkKey,
                    ]
                )
            } catch {
                throw WalletNetworkMigrationError
                    .snapshotVerificationFailed
            }
            guard
                Self.canonicalJournalID(
                    from: url.lastPathComponent
                ) != nil,
                values.isRegularFile == true,
                values.isSymbolicLink != true,
                let fileSize = values.fileSize,
                fileSize > 0,
                fileSize <= Self.maximumJournalBytes,
                fileSize <= remainingBytes
            else {
                throw WalletNetworkMigrationError
                    .snapshotVerificationFailed
            }
            remainingBytes -= fileSize
        }
        let journals = try journalURLs.map { url in
            guard let journal = try loadJournalUnlocked(at: url) else {
                throw WalletNetworkMigrationError
                    .snapshotVerificationFailed
            }
            guard
                url.lastPathComponent ==
                    journalURL(journal.id).lastPathComponent
            else {
                throw WalletNetworkMigrationError
                    .snapshotVerificationFailed
            }
            return journal
        }
        guard Set(journals.map(\.id)).count == journals.count else {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }
        return journals
    }

    private func validateDirectory() throws {
        let values: URLResourceValues
        do {
            values = try directoryURL.resourceValues(
                forKeys: [
                    .isDirectoryKey,
                    .isSymbolicLinkKey,
                ]
            )
        } catch {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }
        guard
            values.isDirectory == true,
            values.isSymbolicLink != true
        else {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }
    }

    private static func canonicalJournalID(
        from fileName: String
    ) -> UUID? {
        let prefix = "wallet-account-"
        let suffix = ".json"
        guard
            fileName.hasPrefix(prefix),
            fileName.hasSuffix(suffix),
            fileName.count > prefix.count + suffix.count
        else {
            return nil
        }
        let value = String(
            fileName
                .dropFirst(prefix.count)
                .dropLast(suffix.count)
        )
        guard
            let id = UUID(uuidString: value),
            fileName == "\(prefix)\(id.uuidString)\(suffix)"
        else {
            return nil
        }
        return id
    }

    private func loadJournalUnlocked(
        at url: URL
    ) throws -> WalletAccountCommitJournal? {
        do {
            let values = try url.resourceValues(
                forKeys: [
                    .fileSizeKey,
                    .isRegularFileKey,
                    .isSymbolicLinkKey,
                ]
            )
            guard
                values.isRegularFile == true,
                values.isSymbolicLink != true,
                let fileSize = values.fileSize,
                fileSize > 0,
                fileSize <= Self.maximumJournalBytes
            else {
                throw WalletNetworkMigrationError
                    .snapshotVerificationFailed
            }
            let data = try Data(contentsOf: url)
            guard data.count == fileSize else {
                throw WalletNetworkMigrationError
                    .snapshotVerificationFailed
            }
            let journal = try decoder.decode(
                WalletAccountCommitJournal.self,
                from: data
            )
            try validate(journal)
            return journal
        } catch {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }
    }

    private func writeUnlocked(
        _ journal: WalletAccountCommitJournal
    ) throws {
        try validate(journal)
        let data = try encoder.encode(journal)
        guard data.count <= Self.maximumJournalBytes else {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }
        try DurableFileWriter.write(
            data,
            to: journalURL(journal.id),
            fileManager: fileManager,
            protection: .completeUntilFirstUserAuthentication
        )
        guard
            let stored = try loadJournalUnlocked(
                at: journalURL(journal.id)
            ),
            Self.journalsMatch(stored, journal)
        else {
            throw WalletNetworkMigrationError
                .snapshotVerificationFailed
        }
    }

    private func journalURL(_ id: UUID) -> URL {
        directoryURL.appendingPathComponent(
            "wallet-account-\(id.uuidString).json"
        )
    }

    private func validate(
        _ journal: WalletAccountCommitJournal
    ) throws {
        let expectedWalletIds = journal.expectedExistingWalletIds
        guard
            !journal.walletId.isEmpty,
            journal.walletId.utf8.count <= 512,
            expectedWalletIds.count <= Self.maximumWalletsPerJournal,
            Set(expectedWalletIds).count == expectedWalletIds.count,
            expectedWalletIds == expectedWalletIds.sorted(),
            !expectedWalletIds.contains(journal.walletId),
            expectedWalletIds.allSatisfy({
                !$0.isEmpty && $0.utf8.count <= 512
            }),
            journal.createdAt.timeIntervalSince1970.isFinite,
            journal.updatedAt.timeIntervalSince1970.isFinite,
            journal.updatedAt >= journal.createdAt
        else {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }
    }

    private func pruneActivatedUnlocked(
        retaining maximumCount: Int
    ) throws {
        guard maximumCount >= 0 else {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }
        let activated = try loadUnlocked()
            .filter { $0.stage == .activated }
            .sorted { $0.updatedAt > $1.updatedAt }
        for journal in activated.dropFirst(
            maximumCount
        ) {
            try fileManager.removeItem(at: journalURL(journal.id))
        }
    }

    private static func canAdvance(
        from current: WalletAccountCommitStage,
        to next: WalletAccountCommitStage
    ) -> Bool {
        let order: [WalletAccountCommitStage] = [
            .prepared,
            .secretsPersisted,
            .coreDataCommitted,
            .networkModelActivated,
            .activated,
        ]
        guard
            let currentIndex = order.firstIndex(of: current),
            let nextIndex = order.firstIndex(of: next)
        else {
            return false
        }
        return nextIndex == currentIndex + 1
    }

    private static func journalsMatch(
        _ lhs: WalletAccountCommitJournal,
        _ rhs: WalletAccountCommitJournal
    ) -> Bool {
        lhs.id == rhs.id &&
            lhs.walletId == rhs.walletId &&
            lhs.expectedExistingWalletIds ==
                rhs.expectedExistingWalletIds &&
            lhs.stage == rhs.stage &&
            Int64(lhs.createdAt.timeIntervalSince1970) ==
                Int64(rhs.createdAt.timeIntervalSince1970) &&
            Int64(lhs.updatedAt.timeIntervalSince1970) ==
                Int64(rhs.updatedAt.timeIntervalSince1970)
    }
}

/// Legacy deployment-manifest projection retained for migration decoding and
/// focused compatibility tests. The first-release runtime contract below is
/// fixed independently of these bundle fields.
struct TairaDeploymentBinding: Equatable {
    static let canonicalChainId = UUID(
        uuidString: "fc56984b-2be7-431d-840e-21514d1883f0"
    )!
    static let canonicalToriiBaseURL = URL(
        string: "https://taira.sora.org"
    )!
    static let canonicalPublicMcpEndpoint = URL(
        string: "https://taira.sora.org/v1/mcp"
    )!
    static let canonicalExplorerBaseURL = URL(
        string: "https://taira.sora.org"
    )!
    static let knownChainIds: Set<UUID> = [canonicalChainId]

    let manifestSha256: String
    let manifestSequenceNumber: UInt64
    let admissionSha256: String
    let currentChainId: UUID
    let retiredChainId: UUID
    let currentGenesisHash: String
    let retiredGenesisHash: String
    let currentDeploymentEpoch: UInt64
    let retiredDeploymentEpoch: UInt64
    let canonicalToriiBaseURL: URL
    let publicMcpEndpoint: URL
    let explorerBaseURL: URL

    static func admitted(
        infoDictionary: [String: Any]?
    ) -> TairaDeploymentBinding? {
        guard let values = infoDictionary else {
            return nil
        }
        func exactString(_ key: String) -> String? {
            guard
                let value = values[key] as? String,
                !value.isEmpty,
                value.utf8.count <= 2_048,
                value.unicodeScalars.allSatisfy({
                    $0.value >= 0x20 && !((0x7F ... 0x9F).contains($0.value))
                })
            else {
                return nil
            }
            return value
        }
        func digest(_ key: String) -> String? {
            guard
                let value = exactString(key),
                value != String(repeating: "0", count: 64),
                value.range(
                    of: "^[0-9a-f]{64}$",
                    options: .regularExpression
                ) != nil
            else {
                return nil
            }
            return value
        }
        func epoch(_ key: String) -> UInt64? {
            guard
                let value = exactString(key),
                value.range(
                    of: "^[1-9][0-9]{0,18}$",
                    options: .regularExpression
                ) != nil,
                let parsed = UInt64(value),
                parsed > 0,
                parsed <= 9_007_199_254_740_991
            else {
                return nil
            }
            return parsed
        }
        guard
            exactString("SoraTairaDeploymentAdmissionContractId") ==
                "sora-ios-taira-deployment-admission-v2",
            exactString("SoraTairaPendingRowPolicy") ==
                "schema-77:preserve-exact-uuid:quarantine-recovery-only:no-reinterpretation",
            let manifestSha256 = digest(
                "SoraTairaDeploymentManifestSha256"
            ),
            let manifestSequenceNumber = epoch(
                "SoraTairaDeploymentManifestSequenceNumber"
            ),
            let admissionSha256 = digest(
                "SoraTairaDeploymentAdmissionSha256"
            ),
            manifestSha256 != admissionSha256,
            let currentChainText = exactString(
                "SoraTairaCurrentChainId"
            ),
            let retiredChainText = exactString(
                "SoraTairaRetiredChainId"
            ),
            let currentChainId = UUID(uuidString: currentChainText),
            let retiredChainId = UUID(uuidString: retiredChainText),
            currentChainText == currentChainText.lowercased(),
            retiredChainText == retiredChainText.lowercased(),
            currentChainId == canonicalChainId,
            currentChainId != retiredChainId,
            let currentGenesisHash = digest(
                "SoraTairaCurrentGenesisHash"
            ),
            let retiredGenesisHash = digest(
                "SoraTairaRetiredGenesisHash"
            ),
            currentGenesisHash != retiredGenesisHash,
            let currentDeploymentEpoch = epoch(
                "SoraTairaCurrentDeploymentEpoch"
            ),
            let retiredDeploymentEpoch = epoch(
                "SoraTairaRetiredDeploymentEpoch"
            ),
            currentDeploymentEpoch > retiredDeploymentEpoch,
            let baseText = exactString(
                "SoraTairaCanonicalToriiBaseUrl"
            ),
            let endpointText = exactString(
                "SoraTairaPublicMcpEndpoint"
            ),
            baseText == Self.canonicalToriiBaseURL.absoluteString,
            endpointText == Self.canonicalPublicMcpEndpoint.absoluteString,
            let explorerText = exactString(
                "SoraTairaExplorerBaseUrl"
            ),
            explorerText == Self.canonicalExplorerBaseURL.absoluteString,
            canonicalPublicOrigin(explorerText) != nil
        else {
            return nil
        }
        return TairaDeploymentBinding(
            manifestSha256: manifestSha256,
            manifestSequenceNumber: manifestSequenceNumber,
            admissionSha256: admissionSha256,
            currentChainId: currentChainId,
            retiredChainId: retiredChainId,
            currentGenesisHash: currentGenesisHash,
            retiredGenesisHash: retiredGenesisHash,
            currentDeploymentEpoch: currentDeploymentEpoch,
            retiredDeploymentEpoch: retiredDeploymentEpoch,
            canonicalToriiBaseURL: Self.canonicalToriiBaseURL,
            publicMcpEndpoint: Self.canonicalPublicMcpEndpoint,
            explorerBaseURL: Self.canonicalExplorerBaseURL
        )
    }

    static var admittedFromBundle: TairaDeploymentBinding? {
        admitted(infoDictionary: Bundle.main.infoDictionary)
    }

    func authorizesTransport(to url: URL) -> Bool {
        guard
            let requested = URLComponents(
                url: url,
                resolvingAgainstBaseURL: false
            ),
            let admitted = URLComponents(
                url: Self.canonicalToriiBaseURL,
                resolvingAgainstBaseURL: false
            ),
            requested.scheme == "https",
            requested.user == nil,
            requested.password == nil,
            requested.host?.lowercased() == admitted.host?.lowercased(),
            requested.port == nil,
            requested.fragment == nil,
            url.path.hasPrefix("/")
        else {
            return false
        }
        if url.path.hasSuffix("/v1/mcp") {
            return url == Self.canonicalPublicMcpEndpoint
        }
        return true
    }

    private static func canonicalPublicOrigin(_ value: String) -> URL? {
        guard
            value.utf8.count <= 512,
            let components = URLComponents(string: value),
            components.scheme == "https",
            components.user == nil,
            components.password == nil,
            components.query == nil,
            components.fragment == nil,
            components.path.isEmpty,
            let host = components.host,
            host == host.lowercased(),
            host.contains("."),
            host.range(
                of: "^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z](?:[a-z0-9-]{0,61}[a-z0-9])?$",
                options: .regularExpression
            ) != nil,
            components.port == nil,
            let url = components.url,
            url.absoluteString == value
        else {
            return nil
        }
        return url
    }
}

struct NexusDerivationProfile: Equatable {
    let networkId: NetworkId
    let derivationPath: String
    let i105Discriminant: Int

    static let minamoto = NexusDerivationProfile(
        networkId: .minamoto,
        derivationPath: "m/44'/617'/0'/0'",
        i105Discriminant: 753
    )

    static let taira = NexusDerivationProfile(
        networkId: .taira,
        derivationPath: "m/44'/617'/1'/0'",
        i105Discriminant: 369
    )

    static func persisted(networkId: NetworkId) -> NexusDerivationProfile? {
        switch networkId {
        case .sora2:
            return nil
        case .minamoto:
            return .minamoto
        case .taira:
            return .taira
        }
    }
}

/// Runtime topology policy. The first Taira release is part of the canonical
/// product topology and no longer depends on an operator-selected bundle epoch.
/// The injectable binding remains only for focused migration compatibility tests.
struct NexusNetworkAdmissionPolicy: Equatable {
    let tairaDeployment: TairaDeploymentBinding?
    private let admitsCanonicalTaira: Bool

    init(tairaDeployment: TairaDeploymentBinding?) {
        self.tairaDeployment = tairaDeployment
        admitsCanonicalTaira = tairaDeployment != nil
    }

    private init(admitsCanonicalTaira: Bool) {
        tairaDeployment = nil
        self.admitsCanonicalTaira = admitsCanonicalTaira
    }

    static var current: NexusNetworkAdmissionPolicy {
        NexusNetworkAdmissionPolicy(admitsCanonicalTaira: true)
    }

    var admittedDerivationProfiles: [NexusDerivationProfile] {
        [.minamoto] + (admitsCanonicalTaira ? [.taira] : [])
    }

    var admittedWalletNetworkIds: Set<NetworkId> {
        Set([NetworkId.sora2]).union(
            admittedDerivationProfiles.map(\.networkId)
        )
    }

    var isTairaAdmitted: Bool {
        admitsCanonicalTaira
    }

    static func persistedMnemonicNetworkIdsAreValid(
        _ networkIds: Set<NetworkId>
    ) -> Bool {
        let required: Set<NetworkId> = [.sora2, .minamoto]
        return networkIds == required ||
            networkIds == required.union([.taira])
    }
}

struct NexusNetworkConfiguration: Codable, Equatable {
    let networkId: NetworkId
    let displayName: String
    let chainId: UUID
    let i105Discriminant: Int
    let toriiURL: URL
    let explorerURL: URL
    let derivationPath: String
    let isTestnet: Bool

    var derivationProfile: NexusDerivationProfile {
        NexusDerivationProfile(
            networkId: networkId,
            derivationPath: derivationPath,
            i105Discriminant: i105Discriminant
        )
    }

    static let minamoto = NexusNetworkConfiguration(
        networkId: .minamoto,
        displayName: "Minamoto",
        chainId: UUID(uuidString: "00000000-0000-0000-0000-000000000753")!,
        i105Discriminant: NexusDerivationProfile.minamoto.i105Discriminant,
        toriiURL: URL(string: "https://minamoto.sora.org")!,
        explorerURL: URL(string: "https://minamoto-explorer.sora.org")!,
        derivationPath: NexusDerivationProfile.minamoto.derivationPath,
        isTestnet: false
    )

    private static let canonicalTaira = NexusNetworkConfiguration(
        networkId: .taira,
        displayName: "Taira Testnet",
        chainId: TairaDeploymentBinding.canonicalChainId,
        i105Discriminant: NexusDerivationProfile.taira.i105Discriminant,
        toriiURL: TairaDeploymentBinding.canonicalToriiBaseURL,
        explorerURL: TairaDeploymentBinding.canonicalExplorerBaseURL,
        derivationPath: NexusDerivationProfile.taira.derivationPath,
        isTestnet: true
    )

    static var taira: NexusNetworkConfiguration? { canonicalTaira }

    static var admittedWalletNetworkIds: Set<NetworkId> {
        NexusNetworkAdmissionPolicy.current.admittedWalletNetworkIds
    }

    static func admittedWalletNetworkIds(
        deployment: TairaDeploymentBinding?
    ) -> Set<NetworkId> {
        NexusNetworkAdmissionPolicy(
            tairaDeployment: deployment
        ).admittedWalletNetworkIds
    }

    static func taira(
        deployment: TairaDeploymentBinding
    ) -> NexusNetworkConfiguration {
        precondition(
            deployment.currentChainId == TairaDeploymentBinding.canonicalChainId &&
                deployment.canonicalToriiBaseURL ==
                    TairaDeploymentBinding.canonicalToriiBaseURL &&
                deployment.publicMcpEndpoint ==
                    TairaDeploymentBinding.canonicalPublicMcpEndpoint,
            "TAIRA_FIRST_RELEASE_CONTRACT_MISMATCH"
        )
        return canonicalTaira
    }

    static func configuration(for networkId: NetworkId) -> NexusNetworkConfiguration? {
        switch networkId {
        case .sora2:
            return nil
        case .minamoto:
            return .minamoto
        case .taira:
            return taira
        }
    }

    var satisfiesCurrentTairaContract: Bool {
        switch networkId {
        case .taira:
            return chainId == TairaDeploymentBinding.canonicalChainId &&
                toriiURL == TairaDeploymentBinding.canonicalToriiBaseURL &&
                explorerURL ==
                    TairaDeploymentBinding.canonicalExplorerBaseURL &&
                derivationPath == NexusDerivationProfile.taira.derivationPath &&
                i105Discriminant ==
                    NexusDerivationProfile.taira.i105Discriminant &&
                isTestnet
        case .minamoto:
            return self == .minamoto
        case .sora2:
            return false
        }
    }

    static func transportIsAdmitted(for url: URL) -> Bool {
        if let minamotoOrigin = URLComponents(
            url: minamoto.toriiURL,
            resolvingAgainstBaseURL: false
        ),
           let requested = URLComponents(
               url: url,
               resolvingAgainstBaseURL: false
           ),
           requested.scheme == "https",
           requested.host?.lowercased() == minamotoOrigin.host?.lowercased(),
           (requested.port ?? 443) == (minamotoOrigin.port ?? 443),
           requested.user == nil,
           requested.password == nil,
           requested.fragment == nil {
            return true
        }
        guard
            let tairaOrigin = URLComponents(
                url: TairaDeploymentBinding.canonicalToriiBaseURL,
                resolvingAgainstBaseURL: false
            ),
            let requested = URLComponents(
                url: url,
                resolvingAgainstBaseURL: false
            )
        else {
            return false
        }
        return requested.scheme == "https" &&
            requested.host?.lowercased() == tairaOrigin.host?.lowercased() &&
            requested.port == nil &&
            requested.user == nil &&
            requested.password == nil &&
            requested.fragment == nil
    }

    func validate(address: String) throws {
        _ = try IrohaAddressCodec.parse(
            address,
            expectedDiscriminant: i105Discriminant
        )
    }
}

enum WalletNetworkMigrationError: LocalizedError {
    case invalidMnemonic
    case invalidDerivationPath
    case nonHardenedDerivationComponent
    case invalidDerivationIndex
    case keyDerivationFailed
    case invalidPrivateKey
    case snapshotVerificationFailed
    case missingSnapshot
    case missingSelectedWallet
    case explicitRemovalTargetMissing(String)
    case explicitRemovalInventoryMismatch
    case explicitRemovalSelectionMismatch
    case lifecycleMutationBusy
    case walletRecoveryRequired
    case legacyIdentityMismatch(String)

    var errorDescription: String? {
        switch self {
        case .invalidMnemonic:
            return "The encrypted recovery phrase could not be reconstructed."
        case .invalidDerivationPath:
            return "An unsupported Nexus derivation path was requested."
        case .nonHardenedDerivationComponent:
            return "Nexus derivation accepts hardened components only."
        case .invalidDerivationIndex:
            return "A Nexus derivation index is invalid."
        case .keyDerivationFailed:
            return "The Nexus key derivation failed."
        case .invalidPrivateKey:
            return "The derived Nexus private key is invalid."
        case .snapshotVerificationFailed:
            return "The staged wallet network model did not verify."
        case .missingSnapshot:
            return "The active wallet network model is unavailable."
        case .missingSelectedWallet:
            return "Existing wallet accounts were found, but the selected wallet setting is unavailable."
        case .explicitRemovalTargetMissing:
            return "The confirmed wallet is not present in the active wallet network model."
        case .explicitRemovalInventoryMismatch:
            return "The wallet database and active wallet network model do not contain the same accounts."
        case .explicitRemovalSelectionMismatch:
            return "The selected wallet changed before the confirmed wallet removal could be committed."
        case .lifecycleMutationBusy:
            return "Another wallet lifecycle operation is still being committed."
        case .walletRecoveryRequired:
            return "Wallet signing and account changes are unavailable until the preserved wallet state has been recovered."
        case .legacyIdentityMismatch:
            return "A legacy SORA2 wallet identity did not match its encrypted signing material."
        }
    }
}

struct WalletRecoveryVerifiedSourceFile: Equatable {
    let url: URL
    let fileName: String
    let byteCount: Int
    let sha256: String
}

struct WalletRecoveryVerifiedMigrationBackup: Equatable {
    let migrationID: UUID
    let updatedAt: Date
    let settingsFile: WalletRecoveryVerifiedSourceFile
    let databaseFiles: [WalletRecoveryVerifiedSourceFile]
}

/// A bounded, read-only probe used before any signing or wallet mutation can
/// begin. The full storage migrator performs deeper Core Data verification at
/// startup; this probe also protects background and deep-link entry points
/// that might otherwise race startup routing.
enum WalletRecoveryMigrationJournalProbe {
    private final class VerificationBudget {
        private var remainingBytes: Int

        init(maximumBytes: Int) {
            remainingBytes = maximumBytes
        }

        func consume(_ byteCount: Int) -> Bool {
            guard
                byteCount > 0,
                byteCount <= remainingBytes
            else {
                return false
            }
            remainingBytes -= byteCount
            return true
        }
    }

    private struct ArtifactRecord: Decodable {
        let fileName: String
        let byteCount: Int
        let sha256: String
    }

    private struct Journal: Decodable {
        let migrationID: UUID
        let sourceVersion: String
        let destinationVersion: String
        let state: String
        let updatedAt: Date
        let failureReason: String?
        let safetyArtifacts: [ArtifactRecord]?
    }

    private static let maximumAttempts = 16
    private static let maximumNamespaceEntries = 64
    private static let maximumJournalBytes = 64 * 1_024
    private static let maximumManifestBytes = 4 * 1_024 * 1_024
    private static let maximumSettingsBytes = 16 * 1_024 * 1_024
    private static let maximumBackupManifestBytes = 64 * 1_024
    private static let maximumRetainedDatabaseFileBytes =
        512 * 1_024 * 1_024
    private static let maximumRetainedNamespaceBytes =
        2 * 1_024 * 1_024 * 1_024

    /// Returns only an independently re-hashed legacy-store snapshot. A
    /// pre-activation or failed migration may still contain the best recovery
    /// copy once every recorded artifact verifies; staging is never returned.
    /// A newest candidate whose artifacts no longer verify is corruption
    /// rather than permission to fall back silently.
    static func newestVerifiedLegacyStoreBackup(
        storeURL: URL,
        fileManager: FileManager = .default
    ) throws -> WalletRecoveryVerifiedMigrationBackup? {
        let safetyDirectory = storeURL
            .deletingLastPathComponent()
            .appendingPathComponent(
                "WalletMigrationSafety",
                isDirectory: true
            )
        guard fileManager.fileExists(atPath: safetyDirectory.path) else {
            return nil
        }

        let directoryValues = try safetyDirectory.resourceValues(
            forKeys: [
                .isDirectoryKey,
                .isSymbolicLinkKey,
            ]
        )
        guard
            directoryValues.isDirectory == true,
            directoryValues.isSymbolicLink != true
        else {
            throw WalletNetworkMigrationError.walletRecoveryRequired
        }

        let entries = try fileManager.contentsOfDirectory(
            at: safetyDirectory,
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .isSymbolicLinkKey,
            ],
            options: []
        )
        guard
            entries.count <= maximumNamespaceEntries,
            entries.count <= maximumAttempts
        else {
            throw WalletNetworkMigrationError.walletRecoveryRequired
        }

        let verificationBudget = VerificationBudget(
            maximumBytes: maximumRetainedNamespaceBytes
        )
        var candidates: [(attempt: URL, journal: Journal)] = []
        for attempt in entries {
            let values = try attempt.resourceValues(
                forKeys: [
                    .isDirectoryKey,
                    .isSymbolicLinkKey,
                ]
            )
            guard
                values.isDirectory == true,
                values.isSymbolicLink != true,
                UUID(uuidString: attempt.lastPathComponent) != nil
            else {
                throw WalletNetworkMigrationError.walletRecoveryRequired
            }

            let journal: Journal = try decode(
                Journal.self,
                at: attempt.appendingPathComponent("journal.json"),
                maximumBytes: maximumJournalBytes,
                verificationBudget: verificationBudget
            )
            guard
                journal.migrationID.uuidString ==
                    attempt.lastPathComponent,
                UserStorageVersion(rawValue: journal.sourceVersion) != nil,
                UserStorageVersion(
                    rawValue: journal.destinationVersion
                ) != nil,
                journal.updatedAt.timeIntervalSince1970.isFinite
            else {
                throw WalletNetworkMigrationError.walletRecoveryRequired
            }
            switch journal.state {
            case "inventoryVerified", "stagingVerified":
                guard journal.failureReason == nil else {
                    throw WalletNetworkMigrationError
                        .walletRecoveryRequired
                }
            case "activated":
                guard journal.failureReason == nil else {
                    throw WalletNetworkMigrationError
                        .walletRecoveryRequired
                }
            case "failed":
                guard journal.failureReason?.isEmpty == false else {
                    throw WalletNetworkMigrationError
                        .walletRecoveryRequired
                }
            default:
                throw WalletNetworkMigrationError.walletRecoveryRequired
            }
            if journal.safetyArtifacts != nil {
                candidates.append((attempt, journal))
            }
        }

        let newest = candidates.sorted { lhs, rhs in
            if lhs.journal.updatedAt != rhs.journal.updatedAt {
                return lhs.journal.updatedAt > rhs.journal.updatedAt
            }
            return lhs.attempt.lastPathComponent >
                rhs.attempt.lastPathComponent
        }.first
        guard let newest else {
            return nil
        }
        guard
            let verified = try verifiedSafetyBackupAttempt(
                newest.attempt,
                storeURL: storeURL,
                journal: newest.journal,
                fileManager: fileManager,
                requiresActivatedState: false,
                verificationBudget: verificationBudget
            )
        else {
            // Never conceal a tampered newest verified backup by exporting an
            // older snapshot or by switching to the live store.
            throw WalletNetworkMigrationError.walletRecoveryRequired
        }
        return verified
    }

    static func hasUnresolvedMigration(
        storeURL: URL,
        fileManager: FileManager = .default
    ) -> Bool {
        let safetyDirectory = storeURL
            .deletingLastPathComponent()
            .appendingPathComponent(
                "WalletMigrationSafety",
                isDirectory: true
            )
        guard fileManager.fileExists(atPath: safetyDirectory.path) else {
            return false
        }

        do {
            let directoryValues = try safetyDirectory.resourceValues(
                forKeys: [
                    .isDirectoryKey,
                    .isSymbolicLinkKey,
                ]
            )
            guard
                directoryValues.isDirectory == true,
                directoryValues.isSymbolicLink != true
            else {
                return true
            }

            let entries = try fileManager.contentsOfDirectory(
                at: safetyDirectory,
                includingPropertiesForKeys: [
                    .isDirectoryKey,
                    .isSymbolicLinkKey,
                ],
                options: []
            )
            guard entries.count <= maximumNamespaceEntries else {
                return true
            }

            var attempts: [URL] = []
            for entry in entries {
                let values = try entry.resourceValues(
                    forKeys: [
                        .isDirectoryKey,
                        .isSymbolicLinkKey,
                    ]
                )
                guard values.isSymbolicLink != true else {
                    return true
                }
                guard
                    values.isDirectory == true,
                    UUID(uuidString: entry.lastPathComponent) != nil
                else {
                    // Hidden files, regular files, and non-attempt
                    // directories are all unexpected in this private
                    // namespace and therefore fail closed.
                    return true
                }
                attempts.append(entry)
            }
            guard attempts.count <= maximumAttempts else {
                return true
            }

            let verificationBudget = VerificationBudget(
                maximumBytes: maximumRetainedNamespaceBytes
            )
            return try attempts.contains { attempt in
                try !isVerifiedActivatedAttempt(
                    attempt,
                    storeURL: storeURL,
                    fileManager: fileManager,
                    verificationBudget: verificationBudget
                )
            }
        } catch {
            // An unreadable recovery namespace is never evidence that signing
            // or wallet mutation is safe.
            return true
        }
    }

    private static func isVerifiedActivatedAttempt(
        _ attempt: URL,
        storeURL: URL,
        fileManager: FileManager,
        verificationBudget: VerificationBudget
    ) throws -> Bool {
        guard
            try WalletMigrationSafetyNamespaceAdmission
                .isExactActivatedAttemptRoot(
                    at: attempt,
                    fileManager: fileManager
                )
        else {
            return false
        }
        let journalURL = attempt.appendingPathComponent("journal.json")
        let journal: Journal = try decode(
            Journal.self,
            at: journalURL,
            maximumBytes: maximumJournalBytes,
            verificationBudget: verificationBudget
        )
        return try verifiedSafetyBackupAttempt(
            attempt,
            storeURL: storeURL,
            journal: journal,
            fileManager: fileManager,
            requiresActivatedState: true,
            verificationBudget: verificationBudget
        ) != nil
    }

    private static func verifiedSafetyBackupAttempt(
        _ attempt: URL,
        storeURL: URL,
        journal: Journal,
        fileManager: FileManager = .default,
        requiresActivatedState: Bool,
        verificationBudget: VerificationBudget
    ) throws -> WalletRecoveryVerifiedMigrationBackup? {
        guard
            journal.migrationID.uuidString == attempt.lastPathComponent,
            UserStorageVersion(rawValue: journal.sourceVersion) != nil,
            UserStorageVersion(rawValue: journal.destinationVersion) != nil,
            journal.updatedAt.timeIntervalSince1970.isFinite,
            let artifacts = journal.safetyArtifacts,
            artifacts.count == 3,
            Set(artifacts.map(\.fileName)).count == artifacts.count
        else {
            return nil
        }
        if requiresActivatedState {
            guard
                journal.state == "activated",
                journal.failureReason == nil
            else {
                return nil
            }
        }

        let legacyDirectory = attempt.appendingPathComponent(
            "legacy-store",
            isDirectory: true
        )
        let legacyValues = try legacyDirectory.resourceValues(
            forKeys: [
                .isDirectoryKey,
                .isSymbolicLinkKey,
            ]
        )
        guard
            legacyValues.isDirectory == true,
            legacyValues.isSymbolicLink != true
        else {
            return nil
        }

        let expectedArtifacts: [String: (URL, Int)] = [
            "account-manifest.json": (
                attempt.appendingPathComponent(
                    "account-manifest.json"
                ),
                maximumManifestBytes
            ),
            "settings-backup.plist": (
                attempt.appendingPathComponent(
                    "settings-backup.plist"
                ),
                maximumSettingsBytes
            ),
            "backup-manifest.json": (
                legacyDirectory.appendingPathComponent(
                    "backup-manifest.json"
                ),
                maximumBackupManifestBytes
            ),
        ]
        guard Set(artifacts.map(\.fileName)) == Set(expectedArtifacts.keys) else {
            return nil
        }
        for artifact in artifacts {
            guard
                let expected = expectedArtifacts[artifact.fileName],
                try record(
                    artifact,
                    matches: expected.0,
                    maximumBytes: expected.1,
                    verificationBudget: verificationBudget
                )
            else {
                return nil
            }
        }

        let backupManifestURL = legacyDirectory.appendingPathComponent(
            "backup-manifest.json"
        )
        let backupRecords: [ArtifactRecord] = try decode(
            [ArtifactRecord].self,
            at: backupManifestURL,
            maximumBytes: maximumBackupManifestBytes,
            verificationBudget: verificationBudget
        )
        let databaseName = storeURL.lastPathComponent
        let allowedDatabaseFiles = Set([
            databaseName,
            "\(databaseName)-wal",
            "\(databaseName)-shm",
        ])
        guard
            (1 ... 3).contains(backupRecords.count),
            Set(backupRecords.map(\.fileName)).count ==
                backupRecords.count,
            Set(backupRecords.map(\.fileName))
                .isSubset(of: allowedDatabaseFiles),
            backupRecords.contains(where: {
                $0.fileName == databaseName
            })
        else {
            return nil
        }
        for record in backupRecords {
            guard
                try self.record(
                    record,
                    matches: legacyDirectory.appendingPathComponent(
                        record.fileName
                    ),
                    maximumBytes:
                        maximumRetainedDatabaseFileBytes,
                    verificationBudget: verificationBudget
                )
            else {
                return nil
            }
        }

        let expectedLegacyEntries = Set(
            backupRecords.map(\.fileName)
        ).union(["backup-manifest.json"])
        let legacyEntries = try fileManager.contentsOfDirectory(
            at: legacyDirectory,
            includingPropertiesForKeys: [
                .isRegularFileKey,
                .isSymbolicLinkKey,
            ],
            options: []
        )
        let retainedLegacyEntryNames = Set(
            legacyEntries.map(\.lastPathComponent)
        )
        let excludedRecoveryEvidence = retainedLegacyEntryNames.subtracting(
            expectedLegacyEntries
        )
        guard
            expectedLegacyEntries.isSubset(of: allowedDatabaseFiles.union([
                "backup-manifest.json",
            ])),
            expectedLegacyEntries.isSubset(of: retainedLegacyEntryNames),
            legacyEntries.count <= expectedLegacyEntries.count + 16
        else {
            return nil
        }
        if requiresActivatedState {
            guard excludedRecoveryEvidence.isEmpty else {
                return nil
            }
        } else {
            // Recovery export may use only the independently hashed canonical
            // backup files while leaving bounded DurableFileWriter evidence
            // untouched and excluded. Arbitrary unexpected entries still fail.
            guard excludedRecoveryEvidence.allSatisfy({
                $0.hasPrefix(".durable-")
            }) else {
                return nil
            }
        }
        for entry in legacyEntries {
            guard try WalletMigrationSafetyNamespaceAdmission
                .isRegularFileNoFollow(at: entry)
            else {
                return nil
            }
        }

        guard let settingsArtifact = artifacts.first(where: {
            $0.fileName == "settings-backup.plist"
        }) else {
            return nil
        }
        let settingsURL = attempt.appendingPathComponent(
            "settings-backup.plist"
        )
        let databaseFiles = backupRecords
            .sorted { $0.fileName < $1.fileName }
            .map {
                WalletRecoveryVerifiedSourceFile(
                    url: legacyDirectory.appendingPathComponent(
                        $0.fileName
                    ),
                    fileName: $0.fileName,
                    byteCount: $0.byteCount,
                    sha256: $0.sha256
                )
            }
        return WalletRecoveryVerifiedMigrationBackup(
            migrationID: journal.migrationID,
            updatedAt: journal.updatedAt,
            settingsFile: WalletRecoveryVerifiedSourceFile(
                url: settingsURL,
                fileName: settingsArtifact.fileName,
                byteCount: settingsArtifact.byteCount,
                sha256: settingsArtifact.sha256
            ),
            databaseFiles: databaseFiles
        )
    }

    private static func record(
        _ record: ArtifactRecord,
        matches url: URL,
        maximumBytes: Int,
        verificationBudget: VerificationBudget
    ) throws -> Bool {
        guard
            record.fileName ==
                (record.fileName as NSString).lastPathComponent,
            record.byteCount > 0,
            record.byteCount <= maximumBytes,
            verificationBudget.consume(record.byteCount),
            isLowercaseSHA256(record.sha256)
        else {
            return false
        }
        let values = try url.resourceValues(
            forKeys: [
                .fileSizeKey,
                .isRegularFileKey,
                .isSymbolicLinkKey,
            ]
        )
        guard
            values.isRegularFile == true,
            values.isSymbolicLink != true,
            values.fileSize == record.byteCount
        else {
            return false
        }
        return try sha256File(
            at: url,
            expectedByteCount: record.byteCount
        ) == record.sha256
    }

    private static func decode<T: Decodable>(
        _ type: T.Type,
        at url: URL,
        maximumBytes: Int,
        verificationBudget: VerificationBudget
    ) throws -> T {
        let values = try url.resourceValues(
            forKeys: [
                .fileSizeKey,
                .isRegularFileKey,
                .isSymbolicLinkKey,
            ]
        )
        guard
            values.isRegularFile == true,
            values.isSymbolicLink != true,
            let byteCount = values.fileSize,
            byteCount > 0,
            byteCount <= maximumBytes,
            verificationBudget.consume(byteCount)
        else {
            throw WalletNetworkMigrationError.walletRecoveryRequired
        }
        let data = try Data(contentsOf: url)
        guard
            data.count == byteCount,
            data.count <= maximumBytes
        else {
            throw WalletNetworkMigrationError.walletRecoveryRequired
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }

    private static func sha256File(
        at url: URL,
        expectedByteCount: Int
    ) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        var consumedBytes = 0
        while true {
            let data = try handle.read(upToCount: 1_048_576) ?? Data()
            guard !data.isEmpty else {
                break
            }
            consumedBytes += data.count
            guard consumedBytes <= expectedByteCount else {
                throw WalletNetworkMigrationError
                    .walletRecoveryRequired
            }
            hasher.update(data: data)
        }
        guard consumedBytes == expectedByteCount else {
            throw WalletNetworkMigrationError.walletRecoveryRequired
        }
        return Data(hasher.finalize())
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func isLowercaseSHA256(_ value: String) -> Bool {
        value.count == 64 &&
            value.unicodeScalars.allSatisfy {
                (48 ... 57).contains($0.value) ||
                    (97 ... 102).contains($0.value)
            }
    }
}

/// Process-wide capability boundary for signing and wallet lifecycle writes.
/// It never clears recovery state and never mutates wallet material. Any
/// unreadable or unfinished journal latches the existing recovery route.
final class WalletRecoveryCapabilityGate: @unchecked Sendable {
    static let shared = WalletRecoveryCapabilityGate(
        settings: SettingsManager.shared,
        unresolvedMigrationJournal: {
            WalletRecoveryMigrationJournalProbe
                .hasUnresolvedMigration(
                    storeURL: UserStorageParams.storageURL
                )
        },
        unresolvedWalletCommitJournal: {
            try !WalletAccountCommitJournalStore()
                .unresolved()
                .isEmpty
        }
    )

    private let settings: SettingsManagerProtocol
    private let unresolvedMigrationJournal: () -> Bool
    private let unresolvedWalletCommitJournal: () throws -> Bool
    private let stateLock = NSLock()
    private var didVerifyMigrationNamespace = false

    init(
        settings: SettingsManagerProtocol,
        unresolvedMigrationJournal: @escaping () -> Bool,
        unresolvedWalletCommitJournal: @escaping () throws -> Bool
    ) {
        self.settings = settings
        self.unresolvedMigrationJournal = unresolvedMigrationJournal
        self.unresolvedWalletCommitJournal =
            unresolvedWalletCommitJournal
    }

    func requireMutableWalletAccess() throws {
        try requireAuthorizedLifecycleContinuation()

        stateLock.lock()
        let shouldVerifyMigration = !didVerifyMigrationNamespace
        stateLock.unlock()
        if shouldVerifyMigration {
            guard !unresolvedMigrationJournal() else {
                throw latchRecovery(
                    "An unfinished or unverifiable wallet database migration blocks signing and wallet changes."
                )
            }
            stateLock.lock()
            didVerifyMigrationNamespace = true
            stateLock.unlock()
        }

        let hasUnresolvedCommit: Bool
        do {
            hasUnresolvedCommit =
                try unresolvedWalletCommitJournal()
        } catch {
            throw latchRecovery(
                "The wallet account commit journal could not be verified. Existing wallet material was preserved."
            )
        }
        guard !hasUnresolvedCommit else {
            throw latchRecovery(
                "An unfinished wallet account commit blocks signing and wallet changes. Existing wallet material was preserved."
            )
        }

        // Close the race with another integrity check latching recovery while
        // the bounded journal probes above were running.
        try requireAuthorizedLifecycleContinuation()
    }

    /// Recheck used only after a lifecycle lease was fully recovery-gated
    /// before the operation began. It intentionally ignores that operation's
    /// own expected in-flight commit journal, but a sticky recovery marker
    /// still aborts the next write phase.
    func requireAuthorizedLifecycleContinuation() throws {
        guard !settings.walletMigrationRecoveryRequired else {
            throw WalletNetworkMigrationError.walletRecoveryRequired
        }
    }

    /// A terminal journal write may have reached durable storage even when
    /// its verification read reports an error. Latch recovery immediately;
    /// a later successful read is not proof that the multi-store commit was
    /// observed as successful by its caller.
    func latchRecoveryAfterAmbiguousWalletCommit() {
        _ = latchRecovery(
            "A terminal wallet account commit could not be verified. Existing wallet material was preserved."
        )
    }

    private func latchRecovery(
        _ reason: String
    ) -> WalletNetworkMigrationError {
        settings.walletMigrationRecoveryRequired = true
        if settings.walletMigrationRecoveryReason?.isEmpty != false {
            settings.walletMigrationRecoveryReason = reason
        }
        return .walletRecoveryRequired
    }
}

/// A process-wide lease spanning wallet lifecycle changes across Keychain,
/// Core Data, selected-account settings, and the copy-on-write network model.
/// Unlike an NSLock, a lease can safely be released by an asynchronous
/// completion running on a different thread.
final class WalletLifecycleLease: @unchecked Sendable {
    fileprivate let token: UUID
    private weak var coordinator: WalletLifecycleCoordinator?
    private let stateLock = NSLock()
    private var isReleased = false
    private var releaseRequested = false
    private var borrowCount = 0

    fileprivate init(
        token: UUID,
        coordinator: WalletLifecycleCoordinator
    ) {
        self.token = token
        self.coordinator = coordinator
    }

    func release() {
        stateLock.lock()
        guard !isReleased, !releaseRequested else {
            stateLock.unlock()
            return
        }
        if borrowCount > 0 {
            releaseRequested = true
            stateLock.unlock()
            return
        }
        isReleased = true
        let retainedCoordinator = coordinator
        stateLock.unlock()
        retainedCoordinator?.release(token: token)
    }

    fileprivate func withBorrow<T>(
        _ body: () throws -> T
    ) throws -> T {
        stateLock.lock()
        guard !isReleased, !releaseRequested else {
            stateLock.unlock()
            throw WalletNetworkMigrationError.lifecycleMutationBusy
        }
        borrowCount += 1
        stateLock.unlock()
        defer { finishBorrow() }
        return try body()
    }

    private func finishBorrow() {
        var retainedCoordinator: WalletLifecycleCoordinator?
        stateLock.lock()
        borrowCount -= 1
        if borrowCount == 0, releaseRequested, !isReleased {
            isReleased = true
            retainedCoordinator = coordinator
        }
        stateLock.unlock()
        retainedCoordinator?.release(token: token)
    }

    deinit {
        release()
    }
}

final class WalletLifecycleCoordinator: @unchecked Sendable {
    private final class SyncWaiter {
        let semaphore = DispatchSemaphore(value: 0)
        var lease: WalletLifecycleLease?
    }

    private enum Waiter {
        case synchronous(SyncWaiter)
        case asynchronous(
            CheckedContinuation<WalletLifecycleLease, Never>
        )
    }

    static let shared = WalletLifecycleCoordinator()

    private let recoveryGate: WalletRecoveryCapabilityGate
    private let stateLock = NSLock()
    private var activeToken: UUID?
    private var waiters: [Waiter] = []
    private let acquisitionQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "co.jp.soramitsu.sora.wallet-lifecycle-acquisition"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()

    init(
        recoveryGate: WalletRecoveryCapabilityGate = .shared
    ) {
        self.recoveryGate = recoveryGate
    }

    /// Raw blocking acquisition is private to lifecycle coordination. Public
    /// signing and mutation entry points must pass the recovery capability
    /// gate before obtaining or using a lease.
    func acquire() -> WalletLifecycleLease {
        let waiter = SyncWaiter()
        stateLock.lock()
        if activeToken == nil, waiters.isEmpty {
            let token = UUID()
            activeToken = token
            stateLock.unlock()
            return WalletLifecycleLease(token: token, coordinator: self)
        }
        waiters.append(.synchronous(waiter))
        stateLock.unlock()
        waiter.semaphore.wait()
        return waiter.lease!
    }

    func tryAcquire() -> WalletLifecycleLease? {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard activeToken == nil, waiters.isEmpty else {
            return nil
        }
        let token = UUID()
        activeToken = token
        return WalletLifecycleLease(token: token, coordinator: self)
    }

    func tryAcquireForMutableWalletAccess() throws
        -> WalletLifecycleLease?
    {
        try recoveryGate
            .requireAuthorizedLifecycleContinuation()
        guard let lease = tryAcquire() else {
            return nil
        }
        do {
            try recoveryGate
                .requireMutableWalletAccess()
            return lease
        } catch {
            lease.release()
            throw error
        }
    }

    /// Swift-concurrency callers must not block a cooperative executor while
    /// an account import, selection, or explicit removal owns the lease.
    func acquireAsync() async -> WalletLifecycleLease {
        await withCheckedContinuation { continuation in
            stateLock.lock()
            guard activeToken != nil || !waiters.isEmpty else {
                let token = UUID()
                activeToken = token
                stateLock.unlock()
                continuation.resume(
                    returning: WalletLifecycleLease(
                        token: token,
                        coordinator: self
                    )
                )
                return
            }
            waiters.append(.asynchronous(continuation))
            stateLock.unlock()
        }
    }

    func acquireForMutableWalletAccessAsync() async throws
        -> WalletLifecycleLease
    {
        try recoveryGate
            .requireAuthorizedLifecycleContinuation()
        let lease = await acquireAsync()
        do {
            try Task.checkCancellation()
            try recoveryGate
                .requireMutableWalletAccess()
            return lease
        } catch {
            lease.release()
            throw error
        }
    }

    func makeAcquireOperation(
        using suppliedLease: WalletLifecycleLease? = nil
    ) -> BaseOperation<WalletLifecycleLease> {
        if let suppliedLease {
            return ClosureOperation {
                try self.recoveryGate
                    .requireAuthorizedLifecycleContinuation()
                return try self.withExclusiveAccess(using: suppliedLease) {
                    suppliedLease
                }
            }
        }
        return WalletLifecycleAcquireOperation(coordinator: self)
    }

    /// Owned acquisition operations run on a dedicated serial queue. They
    /// therefore cannot occupy every worker needed by the current lease
    /// holder's dependent Core Data operations.
    func enqueueOwnedAcquireOperation(
        _ operation: BaseOperation<WalletLifecycleLease>
    ) {
        acquisitionQueue.addOperation(operation)
    }

    func withExclusiveAccess<T>(
        using suppliedLease: WalletLifecycleLease? = nil,
        _ body: () throws -> T
    ) throws -> T {
        let lease: WalletLifecycleLease
        let ownsLease: Bool
        if let suppliedLease {
            return try suppliedLease.withBorrow {
                guard isActive(suppliedLease) else {
                    throw WalletNetworkMigrationError.lifecycleMutationBusy
                }
                try recoveryGate
                    .requireAuthorizedLifecycleContinuation()
                return try body()
            }
        } else {
            try recoveryGate
                .requireAuthorizedLifecycleContinuation()
            lease = acquire()
            ownsLease = true
        }
        defer {
            if ownsLease {
                lease.release()
            }
        }
        try recoveryGate
            .requireMutableWalletAccess()
        return try body()
    }

    fileprivate func release(token: UUID) {
        var resumedWaiter: Waiter?
        var resumedLease: WalletLifecycleLease?
        stateLock.lock()
        guard activeToken == token else {
            stateLock.unlock()
            return
        }
        if waiters.isEmpty {
            activeToken = nil
        } else {
            let nextToken = UUID()
            activeToken = nextToken
            resumedWaiter = waiters.removeFirst()
            resumedLease = WalletLifecycleLease(
                token: nextToken,
                coordinator: self
            )
        }
        stateLock.unlock()
        guard let resumedWaiter, let resumedLease else {
            return
        }
        switch resumedWaiter {
        case let .synchronous(waiter):
            waiter.lease = resumedLease
            waiter.semaphore.signal()
        case let .asynchronous(continuation):
            continuation.resume(returning: resumedLease)
        }
    }

    private func isActive(_ lease: WalletLifecycleLease) -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return activeToken == lease.token
    }
}

private final class WalletLifecycleAcquireOperation:
    PIAsyncOperation<WalletLifecycleLease>,
    @unchecked Sendable
{
    private let coordinator: WalletLifecycleCoordinator

    init(coordinator: WalletLifecycleCoordinator) {
        self.coordinator = coordinator
    }

    override func execute() async throws -> WalletLifecycleLease {
        let lease =
            try await coordinator
                .acquireForMutableWalletAccessAsync()
        do {
            try Task.checkCancellation()
            return lease
        } catch {
            lease.release()
            throw error
        }
    }
}

struct NexusDerivedAccount: Equatable {
    let derivationPath: String
    var privateKey: Data
    var chainCode: Data
    let publicKey: Data
    let address: String
}

/// BIP-39 seed + SLIP-0010 Ed25519 derivation used by Minamoto and Taira.
/// Private keys are returned only to the immediate signing/migration caller
/// and are never persisted in the network model or logs.
enum NexusKeyDerivation {
    private static let ed25519SeedKey = Data("ed25519 seed".utf8)
    private static let hardenedOffset: UInt32 = 0x8000_0000
    private static let maxChildIndex: UInt32 = 0x7FFF_FFFF

    static func derive(
        mnemonic: String,
        passphrase: String = "",
        configuration: NexusNetworkConfiguration
    ) throws -> NexusDerivedAccount {
        try derive(
            mnemonic: mnemonic,
            passphrase: passphrase,
            profile: configuration.derivationProfile
        )
    }

    static func derive(
        mnemonic: String,
        passphrase: String = "",
        profile: NexusDerivationProfile
    ) throws -> NexusDerivedAccount {
        let words = mnemonic
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        guard WalletMnemonicWordPolicy.isUserImportWordCount(words.count) else {
            throw WalletNetworkMigrationError.invalidMnemonic
        }
        do {
            _ = try IRMnemonicCreator(language: .english)
                .mnemonic(fromList: words.joined(separator: " "))
        } catch {
            throw WalletNetworkMigrationError.invalidMnemonic
        }

        var normalizedMnemonic = words
            .joined(separator: " ")
            .decomposedStringWithCompatibilityMapping
        defer {
            normalizedMnemonic.removeAll(keepingCapacity: false)
        }
        var normalizedSalt = "mnemonic\(passphrase)"
            .decomposedStringWithCompatibilityMapping
        defer {
            normalizedSalt.removeAll(keepingCapacity: false)
        }
        var passwordData = Data(normalizedMnemonic.utf8)
        defer {
            passwordData.resetBytes(
                in: passwordData.startIndex ..< passwordData.endIndex
            )
        }
        var saltData = Data(normalizedSalt.utf8)
        defer {
            saltData.resetBytes(
                in: saltData.startIndex ..< saltData.endIndex
            )
        }
        var seed = try pbkdf2(
            password: passwordData,
            salt: saltData
        )
        defer {
            seed.resetBytes(in: seed.startIndex ..< seed.endIndex)
        }
        let components = try parse(profile.derivationPath)

        var digest = hmacSha512(key: ed25519SeedKey, data: seed)
        defer {
            digest.resetBytes(in: digest.startIndex ..< digest.endIndex)
        }
        var privateKey = Data(digest.prefix(32))
        var chainCode = Data(digest.suffix(32))
        defer {
            privateKey.resetBytes(
                in: privateKey.startIndex ..< privateKey.endIndex
            )
            chainCode.resetBytes(
                in: chainCode.startIndex ..< chainCode.endIndex
            )
        }
        for component in components {
            var payload = Data([0])
            defer {
                payload.resetBytes(
                    in: payload.startIndex ..< payload.endIndex
                )
            }
            payload.append(privateKey)
            var index = (component | hardenedOffset).bigEndian
            withUnsafeBytes(of: &index) { payload.append(contentsOf: $0) }
            let nextDigest = hmacSha512(
                key: chainCode,
                data: payload
            )
            digest.resetBytes(
                in: digest.startIndex ..< digest.endIndex
            )
            privateKey.resetBytes(
                in: privateKey.startIndex ..< privateKey.endIndex
            )
            chainCode.resetBytes(
                in: chainCode.startIndex ..< chainCode.endIndex
            )
            digest = nextDigest
            privateKey = Data(digest.prefix(32))
            chainCode = Data(digest.suffix(32))
        }

        guard let signingKey = try? Curve25519.Signing.PrivateKey(
            rawRepresentation: privateKey
        ) else {
            throw WalletNetworkMigrationError.invalidPrivateKey
        }
        let publicKey = signingKey.publicKey.rawRepresentation
        let publicKeyHex = publicKey.map { String(format: "%02x", $0) }.joined()
        let address = try IrohaAddressCodec.encode(
            publicKeyHex: publicKeyHex,
            chainDiscriminant: profile.i105Discriminant
        )

        return NexusDerivedAccount(
            derivationPath: profile.derivationPath,
            privateKey: privateKey,
            chainCode: chainCode,
            publicKey: publicKey,
            address: address
        )
    }

    private static func parse(_ path: String) throws -> [UInt32] {
        guard path.hasPrefix("m/") else {
            throw WalletNetworkMigrationError.invalidDerivationPath
        }
        return try path.dropFirst(2)
            .split(separator: "/", omittingEmptySubsequences: false)
            .map { part in
                guard part.hasSuffix("'") else {
                    throw WalletNetworkMigrationError.nonHardenedDerivationComponent
                }
                guard
                    let value = UInt32(part.dropLast()),
                    value <= maxChildIndex
                else {
                    throw WalletNetworkMigrationError.invalidDerivationIndex
                }
                return value
            }
    }

    private static func pbkdf2(password: Data, salt: Data) throws -> Data {
        var output = [UInt8](repeating: 0, count: 64)
        defer {
            for index in output.indices {
                output[index] = 0
            }
        }
        let status: Int32 = password.withUnsafeBytes { passwordBuffer in
            salt.withUnsafeBytes { saltBuffer in
                guard
                    let passwordBase = passwordBuffer.bindMemory(to: Int8.self).baseAddress,
                    let saltBase = saltBuffer.bindMemory(to: UInt8.self).baseAddress
                else {
                    return Int32(kCCParamError)
                }
                return CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordBase,
                    password.count,
                    saltBase,
                    salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA512),
                    2048,
                    &output,
                    output.count
                )
            }
        }
        guard status == kCCSuccess else {
            throw WalletNetworkMigrationError.keyDerivationFailed
        }
        return Data(output)
    }

    private static func hmacSha512(key: Data, data: Data) -> Data {
        var output = [UInt8](repeating: 0, count: Int(CC_SHA512_DIGEST_LENGTH))
        defer {
            for index in output.indices {
                output[index] = 0
            }
        }
        key.withUnsafeBytes { keyBuffer in
            data.withUnsafeBytes { dataBuffer in
                CCHmac(
                    CCHmacAlgorithm(kCCHmacAlgSHA512),
                    keyBuffer.baseAddress,
                    key.count,
                    dataBuffer.baseAddress,
                    data.count,
                    &output
                )
            }
        }
        return Data(output)
    }
}

/// Copy-on-write local store. Each snapshot remains immutable. Activation is
/// a small atomic pointer write performed only after decoding and equality
/// checks pass, so an interrupted upgrade continues to use the old snapshot.
final class WalletNetworkStore {
    private struct ActivePointer: Codable {
        let schemaVersion: Int
        let fileName: String
        let sha256: String
    }

    private struct NamespaceContents {
        let pointerURL: URL?
        let snapshotURLs: [URL]
    }

    private let directoryURL: URL
    private let fileManager: FileManager
    private let recoveryGate: WalletRecoveryCapabilityGate
    private let admissionPolicy: NexusNetworkAdmissionPolicy
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private static let retainedSnapshotCount = 8
    private static let maximumPointerBytes = 4 * 1_024
    private static let maximumSnapshotBytes = 4 * 1_024 * 1_024
    private static let maximumNamespaceEntries =
        retainedSnapshotCount + 2
    private static let maximumNamespaceBytes =
        maximumPointerBytes +
        ((retainedSnapshotCount + 1) * maximumSnapshotBytes)
    private static let maximumWalletCount = 4_096
    /// Store instances are short-lived throughout the app. The lock must be
    /// process-wide or two instances could race the active pointer.
    private static let lock = NSLock()

    init(
        fileManager: FileManager = .default,
        baseURL: URL? = nil,
        recoveryGate: WalletRecoveryCapabilityGate = .shared,
        admissionPolicy: NexusNetworkAdmissionPolicy = .current
    ) throws {
        self.fileManager = fileManager
        self.recoveryGate = recoveryGate
        self.admissionPolicy = admissionPolicy
        let applicationSupport: URL
        if let baseURL {
            applicationSupport = baseURL
        } else {
            applicationSupport = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        }
        directoryURL = applicationSupport
            .appendingPathComponent("SORA", isDirectory: true)
            .appendingPathComponent("WalletNetworks", isDirectory: true)
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        try validateDirectory()
    }

    func load() throws -> WalletNetworkSnapshot? {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        return try loadUnlocked()
    }

    func stageAndActivate(_ snapshot: WalletNetworkSnapshot) throws {
        try recoveryGate
            .requireAuthorizedLifecycleContinuation()
        Self.lock.lock()
        defer { Self.lock.unlock() }

        try validate(snapshot)
        let current = try loadUnlocked()
        try verifyTopologyAdmission(
            current: current,
            proposed: snapshot
        )
        if let current {
            try verifyMonotonicActivation(
                current: current,
                proposed: snapshot
            )
        }
        try stageAndActivateUnlocked(snapshot)
    }

    /// Changes only the selected wallet pointer after proving Core Data still
    /// describes the exact active identities. No secret material is read.
    func selectWallet(
        walletId: String,
        expectedAccounts: [AccountItem]
    ) throws {
        try recoveryGate
            .requireAuthorizedLifecycleContinuation()
        Self.lock.lock()
        defer { Self.lock.unlock() }

        guard let current = try loadUnlocked() else {
            throw WalletNetworkMigrationError.missingSnapshot
        }
        try verifyInventory(
            current,
            expectedAccounts: expectedAccounts
        )
        guard current.wallets.contains(where: { $0.id == walletId }) else {
            throw WalletNetworkMigrationError
                .explicitRemovalTargetMissing(walletId)
        }
        guard current.selectedWalletId != walletId else {
            return
        }
        let next = WalletNetworkSnapshot(
            schemaVersion: current.schemaVersion,
            selectedWalletId: walletId,
            wallets: current.wallets,
            accounts: current.accounts,
            createdAt: Date()
        )
        try stageAndActivateUnlocked(next)
    }

    /// Updates a user-visible name with immutable wallet/public-key checks.
    /// Asset preferences are intentionally absent from this snapshot.
    func updateWalletDisplayName(
        walletId: String,
        displayName: String,
        expectedAccounts: [AccountItem]
    ) throws {
        try recoveryGate
            .requireAuthorizedLifecycleContinuation()
        Self.lock.lock()
        defer { Self.lock.unlock() }

        guard let current = try loadUnlocked() else {
            throw WalletNetworkMigrationError.missingSnapshot
        }
        try verifyInventory(
            current,
            expectedAccounts: expectedAccounts
        )
        guard current.wallets.contains(where: { $0.id == walletId }) else {
            throw WalletNetworkMigrationError
                .explicitRemovalTargetMissing(walletId)
        }
        let wallets = current.wallets.map { wallet in
            guard wallet.id == walletId else {
                return wallet
            }
            return WalletIdentity(
                id: wallet.id,
                displayName: displayName,
                existingSoraAddress: wallet.existingSoraAddress,
                secretSource: wallet.secretSource
            )
        }
        guard wallets != current.wallets else {
            return
        }
        let next = WalletNetworkSnapshot(
            schemaVersion: current.schemaVersion,
            selectedWalletId: current.selectedWalletId,
            wallets: wallets,
            accounts: current.accounts,
            createdAt: Date()
        )
        try stageAndActivateUnlocked(next)
    }

    /// Upgrade code never calls this path. It exists solely for the existing
    /// user-confirmed account deletion flow, so migration can continue to
    /// treat every unexplained missing wallet as an integrity failure.
    @discardableResult
    func recordExplicitRemoval(
        walletId: String,
        expectedWalletIds: [String],
        selectedWalletId: String?
    ) throws -> WalletNetworkSnapshot {
        try recoveryGate
            .requireAuthorizedLifecycleContinuation()
        Self.lock.lock()
        defer { Self.lock.unlock() }

        guard let current = try loadUnlocked() else {
            throw WalletNetworkMigrationError.missingSnapshot
        }
        let currentWalletIds = current.wallets.map(\.id)
        guard
            !walletId.isEmpty,
            currentWalletIds.filter({ $0 == walletId }).count == 1,
            current.accounts.contains(where: { $0.walletId == walletId })
        else {
            throw WalletNetworkMigrationError
                .explicitRemovalTargetMissing(walletId)
        }
        guard
            Set(expectedWalletIds).count == expectedWalletIds.count,
            Set(expectedWalletIds) == Set(currentWalletIds)
        else {
            throw WalletNetworkMigrationError
                .explicitRemovalInventoryMismatch
        }
        guard
            let currentSelectedWalletId = current.selectedWalletId,
            currentSelectedWalletId == selectedWalletId,
            currentWalletIds.contains(currentSelectedWalletId)
        else {
            throw WalletNetworkMigrationError
                .explicitRemovalSelectionMismatch
        }

        let remainingWallets = current.wallets.filter { $0.id != walletId }
        let nextSelectedWalletId: String?
        if remainingWallets.isEmpty {
            nextSelectedWalletId = nil
        } else if currentSelectedWalletId == walletId {
            nextSelectedWalletId = remainingWallets[0].id
        } else {
            nextSelectedWalletId = currentSelectedWalletId
        }
        let next = WalletNetworkSnapshot(
            schemaVersion: current.schemaVersion,
            selectedWalletId: nextSelectedWalletId,
            wallets: remainingWallets,
            accounts: current.accounts.filter { $0.walletId != walletId },
            createdAt: Date()
        )
        try stageAndActivateUnlocked(next)
        guard
            let activated = try loadUnlocked(),
            try snapshotsMatch(activated, next)
        else {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }
        return activated
    }

    private func stageAndActivateUnlocked(_ snapshot: WalletNetworkSnapshot) throws {
        // Validate the complete private namespace before writing anything.
        // Existing orphaned or unexpected evidence must never be overwritten
        // and reinterpreted as a fresh wallet model.
        _ = try loadUnlocked()
        try validate(snapshot)

        let data = try encoder.encode(snapshot)
        guard data.count <= Self.maximumSnapshotBytes else {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }
        let digest = Self.sha256(data)
        let name = "wallet-network-\(UUID().uuidString).json"
        let snapshotURL = directoryURL.appendingPathComponent(name)
        guard !fileManager.fileExists(atPath: snapshotURL.path) else {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }
        try DurableFileWriter.write(
            data,
            to: snapshotURL,
            fileManager: fileManager,
            protection: .completeUntilFirstUserAuthentication
        )
        RetainedMigrationEvidenceHarness.shared.checkpoint(
            .afterNetworkStaging
        )

        let stagedData = try readBoundedData(
            at: snapshotURL,
            maximumBytes: Self.maximumSnapshotBytes
        )
        let stagedSnapshot: WalletNetworkSnapshot
        do {
            stagedSnapshot = try decoder.decode(
                WalletNetworkSnapshot.self,
                from: stagedData
            )
        } catch {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }
        guard
            try snapshotsMatch(stagedSnapshot, snapshot),
            Self.sha256(stagedData) == digest
        else {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }
        RetainedMigrationEvidenceHarness.shared.checkpoint(
            .beforeActivation
        )

        let pointer = ActivePointer(
            schemaVersion: WalletNetworkSnapshot.currentSchemaVersion,
            fileName: name,
            sha256: digest
        )
        let pointerData = try encoder.encode(pointer)
        guard pointerData.count <= Self.maximumPointerBytes else {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }
        let pointerURL = directoryURL.appendingPathComponent("active.json")
        let previousPointerData = fileManager.fileExists(atPath: pointerURL.path)
            ? try readBoundedData(
                at: pointerURL,
                maximumBytes: Self.maximumPointerBytes
            )
            : nil
        let previousPointer: ActivePointer?
        do {
            previousPointer = try previousPointerData.map {
                try decoder.decode(ActivePointer.self, from: $0)
            }
        } catch {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }
        try DurableFileWriter.write(
            pointerData,
            to: pointerURL,
            fileManager: fileManager,
            protection: .completeUntilFirstUserAuthentication
        )

        do {
            guard
                let activated = try loadUnlocked(
                    allowingTransitionalSnapshot: true
                ),
                try snapshotsMatch(activated, snapshot)
            else {
                throw WalletNetworkMigrationError.snapshotVerificationFailed
            }
        } catch {
            do {
                if let previousPointerData {
                    try DurableFileWriter.write(
                        previousPointerData,
                        to: pointerURL,
                        fileManager: fileManager,
                        protection:
                            .completeUntilFirstUserAuthentication
                    )
                } else if fileManager.fileExists(atPath: pointerURL.path) {
                    try fileManager.removeItem(at: pointerURL)
                }
            } catch {
                // Leave the invalid pointer in place so all later reads fail
                // closed rather than interpreting the store as a new wallet.
                throw WalletNetworkMigrationError.snapshotVerificationFailed
            }
            throw error
        }

        // Retain the active snapshot, its immediate predecessor, and the
        // newest recovery snapshots up to a fixed bound. A cleanup failure is
        // surfaced after activation so the caller enters sticky recovery
        // instead of pretending an only-partially-qualified commit succeeded.
        var protectedNames: Set<String> = [name]
        if let previousName = previousPointer?.fileName {
            protectedNames.insert(previousName)
        }
        try pruneSnapshotsUnlocked(
            protecting: protectedNames,
            maximumCount: Self.retainedSnapshotCount
        )
        guard
            let retained = try loadUnlocked(),
            try snapshotsMatch(retained, snapshot)
        else {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }
    }

    private func pruneSnapshotsUnlocked(
        protecting protectedNames: Set<String>,
        maximumCount: Int
    ) throws {
        guard maximumCount >= protectedNames.count else {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }
        let namespace = try validatedNamespaceUnlocked()
        guard
            namespace.pointerURL != nil,
            namespace.snapshotURLs.count <=
                Self.retainedSnapshotCount + 1,
            protectedNames.isSubset(
                of: Set(
                    namespace.snapshotURLs.map(\.lastPathComponent)
                )
            )
        else {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }
        let candidates = namespace.snapshotURLs
        let datedCandidates = try candidates.map { url in
            let values = try url.resourceValues(
                forKeys: [
                    .contentModificationDateKey,
                    .isRegularFileKey,
                    .isSymbolicLinkKey,
                ]
            )
            guard
                values.isRegularFile == true,
                values.isSymbolicLink != true
            else {
                throw WalletNetworkMigrationError
                    .snapshotVerificationFailed
            }
            return (
                url: url,
                modifiedAt: values.contentModificationDate ??
                    Date.distantPast
            )
        }
        .sorted { lhs, rhs in
            if lhs.modifiedAt == rhs.modifiedAt {
                return lhs.url.lastPathComponent <
                    rhs.url.lastPathComponent
            }
            return lhs.modifiedAt > rhs.modifiedAt
        }

        var retainedNames = protectedNames
        for candidate in datedCandidates
        where retainedNames.count < maximumCount {
            retainedNames.insert(candidate.url.lastPathComponent)
        }
        for candidate in datedCandidates
        where !retainedNames.contains(candidate.url.lastPathComponent) {
            try fileManager.removeItem(at: candidate.url)
        }
    }

    private func verifyInventory(
        _ snapshot: WalletNetworkSnapshot,
        expectedAccounts: [AccountItem]
    ) throws {
        guard expectedAccounts.count <= Self.maximumWalletCount else {
            throw WalletNetworkMigrationError
                .explicitRemovalInventoryMismatch
        }
        let expectedByAddress = Dictionary(
            grouping: expectedAccounts,
            by: \.address
        )
        let storedWallets = Dictionary(
            grouping: snapshot.wallets,
            by: \.id
        )
        let storedSoraAccounts = Dictionary(
            grouping: snapshot.accounts.filter {
                $0.networkId == .sora2
            },
            by: \.walletId
        )
        guard
            expectedByAddress.count == expectedAccounts.count,
            expectedByAddress.values.allSatisfy({ $0.count == 1 }),
            storedWallets.count == snapshot.wallets.count,
            storedWallets.values.allSatisfy({ $0.count == 1 }),
            storedSoraAccounts.count == expectedAccounts.count,
            storedSoraAccounts.values.allSatisfy({ $0.count == 1 }),
            Set(expectedByAddress.keys) == Set(storedWallets.keys)
        else {
            throw WalletNetworkMigrationError
                .explicitRemovalInventoryMismatch
        }
        for account in expectedAccounts {
            guard
                let stored = storedSoraAccounts[account.address]?.first,
                stored.address == account.address,
                stored.publicKey == account.publicKeyData
            else {
                throw WalletNetworkMigrationError
                    .legacyIdentityMismatch(account.address)
            }
        }
    }

    /// Generic migration/account-add activation is append-only for durable
    /// wallet identities. Selection and new wallets may change, but an
    /// existing wallet, secret-source classification, SORA public key, or
    /// deterministic Nexus child can be removed or rewritten only through a
    /// separately verified explicit operation.
    private func verifyMonotonicActivation(
        current: WalletNetworkSnapshot,
        proposed: WalletNetworkSnapshot
    ) throws {
        let proposedWallets = Dictionary(
            grouping: proposed.wallets,
            by: \.id
        )
        let proposedAccounts = Dictionary(
            grouping: proposed.accounts,
            by: \.id
        )
        guard
            proposed.schemaVersion == current.schemaVersion,
            proposedWallets.values.allSatisfy({ $0.count == 1 }),
            proposedAccounts.values.allSatisfy({ $0.count == 1 }),
            current.wallets.allSatisfy({ wallet in
                proposedWallets[wallet.id]?.first == wallet
            }),
            current.accounts.allSatisfy({ account in
                proposedAccounts[account.id]?.first == account
            })
        else {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }
    }

    /// Historical deterministic children remain durable recovery evidence,
    /// while only the current protected bundle admission may add a child to a
    /// new or existing mnemonic wallet.
    private func verifyTopologyAdmission(
        current: WalletNetworkSnapshot?,
        proposed: WalletNetworkSnapshot
    ) throws {
        let currentWallets = Dictionary(
            grouping: current?.wallets ?? [],
            by: \.id
        )
        let currentAccounts = Dictionary(
            grouping: current?.accounts ?? [],
            by: \.walletId
        )
        let proposedAccounts = Dictionary(
            grouping: proposed.accounts,
            by: \.walletId
        )
        for wallet in proposed.wallets {
            let proposedNetworkIds = Set(
                (proposedAccounts[wallet.id] ?? []).map(\.networkId)
            )
            guard wallet.secretSource == .mnemonicEntropy else {
                guard proposedNetworkIds == [.sora2] else {
                    throw WalletNetworkMigrationError
                        .snapshotVerificationFailed
                }
                continue
            }
            let expectedNetworkIds: Set<NetworkId>
            if currentWallets[wallet.id]?.count == 1 {
                expectedNetworkIds = Set(
                    (currentAccounts[wallet.id] ?? []).map(\.networkId)
                ).union(admissionPolicy.admittedWalletNetworkIds)
            } else {
                expectedNetworkIds = admissionPolicy
                    .admittedWalletNetworkIds
            }
            guard proposedNetworkIds == expectedNetworkIds else {
                throw WalletNetworkMigrationError
                    .snapshotVerificationFailed
            }
        }
    }

    /// `.iso8601` normalizes sub-second precision. Compare the canonical
    /// encoded representation rather than an in-memory `Date` that may carry
    /// additional precision not present in the durable snapshot.
    private func snapshotsMatch(
        _ lhs: WalletNetworkSnapshot,
        _ rhs: WalletNetworkSnapshot
    ) throws -> Bool {
        let lhsData = try encoder.encode(lhs)
        let rhsData = try encoder.encode(rhs)
        return lhsData == rhsData
    }

    private func loadUnlocked(
        allowingTransitionalSnapshot: Bool = false
    ) throws -> WalletNetworkSnapshot? {
        let namespace = try validatedNamespaceUnlocked()
        guard let pointerURL = namespace.pointerURL else {
            // A new installation has an empty directory. Snapshot files
            // without an active pointer instead prove that activation was
            // interrupted or the pointer was lost; rebuilding over them would
            // silently reinterpret recovery evidence as a fresh namespace.
            guard namespace.snapshotURLs.isEmpty else {
                throw WalletNetworkMigrationError
                    .snapshotVerificationFailed
            }
            return nil
        }
        let maximumSnapshots = Self.retainedSnapshotCount +
            (allowingTransitionalSnapshot ? 1 : 0)
        guard namespace.snapshotURLs.count <= maximumSnapshots else {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }
        let pointer: ActivePointer
        do {
            pointer = try decoder.decode(
                ActivePointer.self,
                from: readBoundedData(
                    at: pointerURL,
                    maximumBytes: Self.maximumPointerBytes
                )
            )
        } catch {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }
        guard
            pointer.schemaVersion == WalletNetworkSnapshot.currentSchemaVersion,
            pointer.fileName == (pointer.fileName as NSString).lastPathComponent,
            Self.canonicalSnapshotID(from: pointer.fileName) != nil,
            namespace.snapshotURLs.contains(where: {
                $0.lastPathComponent == pointer.fileName
            }),
            pointer.sha256.count == 64,
            pointer.sha256.unicodeScalars.allSatisfy({
                (48 ... 57).contains($0.value) ||
                    (97 ... 102).contains($0.value)
            })
        else {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }
        let snapshotData = try readBoundedData(
            at: directoryURL.appendingPathComponent(pointer.fileName),
            maximumBytes: Self.maximumSnapshotBytes
        )
        guard Self.sha256(snapshotData) == pointer.sha256 else {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }
        let snapshot: WalletNetworkSnapshot
        do {
            snapshot = try decoder.decode(
                WalletNetworkSnapshot.self,
                from: snapshotData
            )
            try validate(snapshot)
        } catch {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }
        return snapshot
    }

    private func validateDirectory() throws {
        let values: URLResourceValues
        do {
            values = try directoryURL.resourceValues(
                forKeys: [
                    .isDirectoryKey,
                    .isSymbolicLinkKey,
                ]
            )
        } catch {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }
        guard
            values.isDirectory == true,
            values.isSymbolicLink != true
        else {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }
    }

    private func validatedNamespaceUnlocked() throws
        -> NamespaceContents
    {
        try validateDirectory()
        let entries: [URL]
        do {
            entries = try fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [
                    .fileSizeKey,
                    .isRegularFileKey,
                    .isSymbolicLinkKey,
                ],
                options: []
            )
        } catch {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }
        guard entries.count <= Self.maximumNamespaceEntries else {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }

        var pointerURL: URL?
        var snapshotURLs: [URL] = []
        var remainingBytes = Self.maximumNamespaceBytes
        for url in entries {
            let values: URLResourceValues
            do {
                values = try url.resourceValues(
                    forKeys: [
                        .fileSizeKey,
                        .isRegularFileKey,
                        .isSymbolicLinkKey,
                    ]
                )
            } catch {
                throw WalletNetworkMigrationError
                    .snapshotVerificationFailed
            }
            guard
                values.isRegularFile == true,
                values.isSymbolicLink != true,
                let fileSize = values.fileSize,
                fileSize > 0,
                fileSize <= remainingBytes
            else {
                throw WalletNetworkMigrationError
                    .snapshotVerificationFailed
            }

            let maximumFileBytes: Int
            if url.lastPathComponent == "active.json" {
                guard pointerURL == nil else {
                    throw WalletNetworkMigrationError
                        .snapshotVerificationFailed
                }
                pointerURL = url
                maximumFileBytes = Self.maximumPointerBytes
            } else {
                guard
                    Self.canonicalSnapshotID(
                        from: url.lastPathComponent
                    ) != nil
                else {
                    throw WalletNetworkMigrationError
                        .snapshotVerificationFailed
                }
                snapshotURLs.append(url)
                maximumFileBytes = Self.maximumSnapshotBytes
            }
            guard fileSize <= maximumFileBytes else {
                throw WalletNetworkMigrationError
                    .snapshotVerificationFailed
            }
            remainingBytes -= fileSize
        }
        for snapshotURL in snapshotURLs {
            do {
                let snapshot = try decoder.decode(
                    WalletNetworkSnapshot.self,
                    from: readBoundedData(
                        at: snapshotURL,
                        maximumBytes: Self.maximumSnapshotBytes
                    )
                )
                try validate(snapshot)
            } catch {
                throw WalletNetworkMigrationError
                    .snapshotVerificationFailed
            }
        }
        return NamespaceContents(
            pointerURL: pointerURL,
            snapshotURLs: snapshotURLs
        )
    }

    private static func canonicalSnapshotID(
        from fileName: String
    ) -> UUID? {
        let prefix = "wallet-network-"
        let suffix = ".json"
        guard
            fileName.hasPrefix(prefix),
            fileName.hasSuffix(suffix),
            fileName.count > prefix.count + suffix.count
        else {
            return nil
        }
        let value = String(
            fileName
                .dropFirst(prefix.count)
                .dropLast(suffix.count)
        )
        guard
            let id = UUID(uuidString: value),
            fileName == "\(prefix)\(id.uuidString)\(suffix)"
        else {
            return nil
        }
        return id
    }

    private func validate(_ snapshot: WalletNetworkSnapshot) throws {
        guard
            snapshot.schemaVersion ==
                WalletNetworkSnapshot.currentSchemaVersion,
            snapshot.wallets.count <= Self.maximumWalletCount,
            snapshot.accounts.count <= Self.maximumWalletCount * 3,
            snapshot.createdAt.timeIntervalSince1970.isFinite
        else {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }
        let wallets = Dictionary(grouping: snapshot.wallets, by: \.id)
        let accounts = Dictionary(grouping: snapshot.accounts, by: \.id)
        let accountsByWallet = Dictionary(
            grouping: snapshot.accounts,
            by: \.walletId
        )
        let hasValidSelection = snapshot.wallets.isEmpty
            ? snapshot.selectedWalletId == nil
            : snapshot.selectedWalletId.map({
                wallets[$0]?.count == 1
            }) == true
        guard
            wallets.count == snapshot.wallets.count,
            accounts.count == snapshot.accounts.count,
            snapshot.wallets.allSatisfy({
                !$0.id.isEmpty &&
                    $0.id.utf8.count <= 512 &&
                    $0.displayName.utf8.count <= 4_096 &&
                    $0.existingSoraAddress.utf8.count <= 512 &&
                    $0.existingSoraAddress == $0.id
            }),
            snapshot.accounts.allSatisfy({
                wallets[$0.walletId]?.count == 1 &&
                    !$0.address.isEmpty &&
                    $0.address.utf8.count <= 512 &&
                    !$0.publicKey.isEmpty &&
                    $0.publicKey.count <= 128 &&
                    (
                        ($0.networkId == .sora2 &&
                            $0.derivationVersion == 0) ||
                            ($0.networkId != .sora2 &&
                                $0.derivationVersion == 1)
                    )
            }),
            snapshot.wallets.allSatisfy({ wallet in
                let walletAccounts = accountsByWallet[wallet.id] ?? []
                let networkIds = Set(walletAccounts.map(\.networkId))
                let hasExpectedAccountCount =
                    walletAccounts.count == networkIds.count
                let hasExpectedNetworks =
                    wallet.secretSource == .mnemonicEntropy
                        ? NexusNetworkAdmissionPolicy
                            .persistedMnemonicNetworkIdsAreValid(networkIds)
                        : networkIds == [.sora2]
                let preservesSoraAddress = walletAccounts.contains(where: {
                    account in
                    account.networkId == .sora2 &&
                        account.address == wallet.existingSoraAddress
                })
                return hasExpectedAccountCount &&
                    hasExpectedNetworks &&
                    preservesSoraAddress
            }),
            hasValidSelection
        else {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }

        for account in snapshot.accounts where account.networkId != .sora2 {
            guard
                let profile = NexusDerivationProfile.persisted(
                    networkId: account.networkId
                ),
                let details = try? IrohaAddressCodec.parse(
                    account.address,
                    expectedDiscriminant: profile.i105Discriminant
                ),
                details.publicKeyHex == account.publicKey
                    .map({ String(format: "%02x", $0) })
                    .joined()
            else {
                throw WalletNetworkMigrationError.snapshotVerificationFailed
            }
        }
    }

    private func readBoundedData(
        at url: URL,
        maximumBytes: Int
    ) throws -> Data {
        do {
            let values = try url.resourceValues(
                forKeys: [
                    .fileSizeKey,
                    .isRegularFileKey,
                    .isSymbolicLinkKey,
                ]
            )
            guard
                values.isRegularFile == true,
                values.isSymbolicLink != true,
                let fileSize = values.fileSize,
                fileSize > 0,
                fileSize <= maximumBytes
            else {
                throw WalletNetworkMigrationError
                    .snapshotVerificationFailed
            }
            let data = try Data(contentsOf: url)
            guard data.count == fileSize else {
                throw WalletNetworkMigrationError
                    .snapshotVerificationFailed
            }
            return data
        } catch {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }
    }

    private static func sha256(_ data: Data) -> String {
        Data(SHA256.hash(data: data))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

/// Validates the installed SORA2 identity against its retained secret source.
/// Nexus migration separately admits only eligible 12- or 24-word master
/// phrases; retained 15/18/21-word, raw-seed, secret-only, and watch-only wallets stay SORA2-only.
enum LegacySoraIdentityValidator {
    static func validate(
        address: String,
        publicKey: Data,
        cryptoType: CryptoType,
        networkType: SNAddressType,
        derivationPath: String?,
        entropy: Data?,
        rawSeed: Data?,
        secret: Data?,
        recoveryGate: WalletRecoveryCapabilityGate
    ) throws {
        try recoveryGate
            .requireAuthorizedLifecycleContinuation()
        let publicAddress = try SS58AddressFactory().address(
            fromAccountId: publicKey,
            type: networkType
        )
        guard publicAddress == address else {
            throw WalletNetworkMigrationError.legacyIdentityMismatch(address)
        }
        if let secret, secret.isEmpty {
            throw WalletNetworkMigrationError.legacyIdentityMismatch(address)
        }

        let path = derivationPath ?? ""
        let junction = path.isEmpty
            ? nil
            : try SubstrateJunctionFactory().parse(path: path)
        let chaincodes = junction?.chaincodes ?? []

        var sourceSeed: Data?
        defer { wipeSensitive(&sourceSeed) }
        if let entropy {
            guard !entropy.isEmpty else {
                throw WalletNetworkMigrationError.legacyIdentityMismatch(address)
            }
            let mnemonic = try IRMnemonicCreator(language: .english)
                .mnemonic(fromEntropy: entropy)
            var phrase = mnemonic.toString()
            defer { phrase.removeAll(keepingCapacity: false) }
            let result = try SeedFactory().deriveSeed(
                from: phrase,
                password: junction?.password ?? ""
            )
            var mnemonicSeed = result.seed.miniSeed
            defer { wipeSensitive(&mnemonicSeed) }
            if let rawSeed {
                guard
                    !rawSeed.isEmpty,
                    rawSeed == mnemonicSeed
                else {
                    // Mnemonic-era accounts retain both entropy and the
                    // derived mini-seed. Verify both sources; never let one
                    // valid copy hide corruption in the other.
                    throw WalletNetworkMigrationError
                        .legacyIdentityMismatch(address)
                }
            }
            sourceSeed = mnemonicSeed
        } else if let rawSeed {
            guard !rawSeed.isEmpty else {
                throw WalletNetworkMigrationError.legacyIdentityMismatch(address)
            }
            sourceSeed = rawSeed
        }

        var resolvedSecret = secret
        defer { wipeSensitive(&resolvedSecret) }
        if let sourceSeed {
            let keypairFactory = keypairFactory(for: cryptoType)
            let keypair = try keypairFactory.createKeypairFromSeed(
                sourceSeed,
                chaincodeList: chaincodes
            )
            guard keypair.publicKey().rawData() == publicKey else {
                throw WalletNetworkMigrationError.legacyIdentityMismatch(address)
            }

            var expectedSecret: Data
            switch cryptoType {
            case .sr25519:
                expectedSecret = keypair.privateKey().rawData()
            case .ed25519:
                expectedSecret = try Ed25519KeypairFactory()
                    .deriveChildSeedFromParent(sourceSeed.miniSeed, chaincodeList: chaincodes)
            case .ecdsa:
                expectedSecret = try EcdsaKeypairFactory()
                    .deriveChildSeedFromParent(sourceSeed.miniSeed, chaincodeList: chaincodes)
            }
            defer { wipeSensitive(&expectedSecret) }
            if let secret, expectedSecret != secret {
                throw WalletNetworkMigrationError.legacyIdentityMismatch(address)
            }
            resolvedSecret = expectedSecret
        }

        // Explicit watch-only accounts have no source from which a signing
        // challenge can be produced. Their public key/address relation was
        // verified above.
        guard var signingSecret = resolvedSecret else {
            RetainedMigrationEvidenceHarness.shared.recordCredentialBehavior(
                signingExpected: false,
                signingSucceeded: false,
                behaviorPassed: true
            )
            return
        }
        defer { wipeSensitive(&signingSecret) }

        let challenge = Data("SORA wallet upgrade identity check v1".utf8)
        let verified: Bool
        switch cryptoType {
        case .sr25519:
            let privateKey = try SNPrivateKey(rawData: signingSecret)
            let signingPublicKey = try SNPublicKey(rawData: publicKey)
            let signature = try SNSigner(
                keypair: SNKeypair(
                    privateKey: privateKey,
                    publicKey: signingPublicKey
                )
            ).sign(challenge)
            verified = SNSignatureVerifier().verify(
                signature,
                forOriginalData: challenge,
                using: signingPublicKey
            )
        case .ed25519:
            let keypair = try Ed25519KeypairFactory().createKeypairFromSeed(
                signingSecret.miniSeed,
                chaincodeList: []
            )
            guard keypair.publicKey().rawData() == publicKey else {
                throw WalletNetworkMigrationError.legacyIdentityMismatch(address)
            }
            let signature = try Sora2Ed25519SeedSigner.sign(
                challenge,
                seed: signingSecret
            )
            verified = EDSignatureVerifier().verify(
                signature,
                forOriginalData: challenge,
                usingPublicKey: keypair.publicKey()
            )
        case .ecdsa:
            let keypair = try EcdsaKeypairFactory().createKeypairFromSeed(
                signingSecret.miniSeed,
                chaincodeList: []
            )
            guard keypair.publicKey().rawData() == publicKey else {
                throw WalletNetworkMigrationError.legacyIdentityMismatch(address)
            }
            let digest = try challenge.blake2b32()
            let signature = try SECSigner(privateKey: keypair.privateKey()).sign(digest)
            verified = SECSignatureVerifier().verify(
                signature,
                forOriginalData: digest,
                usingPublicKey: keypair.publicKey()
            )
        }

        guard verified else {
            throw WalletNetworkMigrationError.legacyIdentityMismatch(address)
        }
        RetainedMigrationEvidenceHarness.shared.recordCredentialBehavior(
            signingExpected: true,
            signingSucceeded: true,
            behaviorPassed: true
        )
    }

    private static func wipeSensitive(_ value: inout Data) {
        value.resetBytes(in: value.startIndex ..< value.endIndex)
    }

    private static func wipeSensitive(_ value: inout Data?) {
        if let count = value?.count {
            value?.resetBytes(in: 0 ..< count)
        }
        value = nil
    }

    private static func keypairFactory(
        for cryptoType: CryptoType
    ) -> KeypairFactoryProtocol {
        switch cryptoType {
        case .sr25519:
            return SR25519KeypairFactory()
        case .ed25519:
            return Ed25519KeypairFactory()
        case .ecdsa:
            return EcdsaKeypairFactory()
        }
    }
}

final class WalletNetworkModelMigrator {
    private let keystore: KeystoreProtocol
    private let store: WalletNetworkStore
    private let settings: SettingsManagerProtocol
    private let lifecycleCoordinator: WalletLifecycleCoordinator
    private let recoveryGate: WalletRecoveryCapabilityGate
    private let admissionPolicy: NexusNetworkAdmissionPolicy

    init(
        keystore: KeystoreProtocol,
        store: WalletNetworkStore,
        settings: SettingsManagerProtocol,
        lifecycleCoordinator: WalletLifecycleCoordinator = .shared,
        recoveryGate: WalletRecoveryCapabilityGate = .shared,
        admissionPolicy: NexusNetworkAdmissionPolicy = .current
    ) {
        self.keystore = keystore
        self.store = store
        self.settings = settings
        self.lifecycleCoordinator = lifecycleCoordinator
        self.recoveryGate = recoveryGate
        self.admissionPolicy = admissionPolicy
    }

    func migrate(
        accounts: [AccountItem],
        selectedAddress: String?,
        lifecycleLease: WalletLifecycleLease? = nil
    ) throws {
        try lifecycleCoordinator.withExclusiveAccess(
            using: lifecycleLease
        ) {
            try migrateLocked(
                accounts: accounts,
                selectedAddress: selectedAddress
            )
        }
    }

    private func migrateLocked(
        accounts: [AccountItem],
        selectedAddress: String?
    ) throws {
        let current = try store.load()
        if let current {
            guard
                current.schemaVersion ==
                    WalletNetworkSnapshot.currentSchemaVersion
            else {
                // A store written by an unknown/newer migration cannot be
                // safely normalized by rebuilding it from partial legacy
                // inputs.
                throw WalletNetworkMigrationError.snapshotVerificationFailed
            }
            try verifyExistingSnapshot(current, against: accounts)
        }

        let accountAddresses = Set(accounts.map(\.address))
        guard
            (accounts.isEmpty && selectedAddress == nil) ||
                selectedAddress.map(accountAddresses.contains) == true
        else {
            // A missing or stale selected-account preference is never
            // permission to activate an unselected snapshot and route the
            // user into new-wallet onboarding.
            throw WalletNetworkMigrationError.missingSelectedWallet
        }

        var identities: [WalletIdentity] = []
        var networkAccounts: [NetworkAccount] = []
        for account in accounts.sorted(by: { $0.order < $1.order }) {
            let scopedEntropyTag = KeystoreTag.entropyTagForAddress(
                account.address
            )
            var entropy: Data?
            if let current {
                // The migrator's injected store is the authority for this
                // lifecycle transaction. Never resolve a retained global
                // entropy record through a separately loaded default store.
                entropy = try keystore.fetchEntropyForAddress(
                    account.address,
                    activeSnapshot: current,
                    recoveryGate: recoveryGate
                )
            } else {
                // Before activation only an exact address-scoped record may be
                // read here. The guarded single-account block below owns the
                // one supported unsuffixed legacy resolution path.
                entropy = try keystore.loadIfKeyExists(scopedEntropyTag)
            }
            var rawSeed = try keystore.fetchSeedForAddress(account.address)
            var legacySecret = try keystore.fetchSecretKeyForAddress(
                account.address
            )
            let watchOnlyKey = "wallet.watchOnly.\(account.address)"
            guard
                !settings.allKeys().contains(watchOnlyKey) ||
                    settings.anyValue(for: watchOnlyKey) is Bool
            else {
                throw WalletNetworkMigrationError.legacyIdentityMismatch(
                    account.address
                )
            }
            let isExplicitWatchOnly =
                settings.bool(for: watchOnlyKey) == true
            if
                current == nil,
                accounts.count == 1,
                entropy == nil,
                rawSeed == nil,
                legacySecret == nil,
                !isExplicitWatchOnly
            {
                let identifiers = Set(try keystore.allKeyIdentifiers())
                let scopedSuffixes = [
                    "-secretKey",
                    "-entropy",
                    "-deriv",
                    "-seed",
                ]
                guard
                    identifiers.contains(
                        KeystoreTag.legacyEntropy.rawValue
                    ),
                    !identifiers.contains(where: { identifier in
                        scopedSuffixes.contains(where: {
                            identifier.hasSuffix($0)
                        })
                    }),
                    account.cryptoType == .sr25519,
                    account.networkType == SNAddressType(chain: .sora)
                else {
                    throw WalletNetworkMigrationError
                        .legacyIdentityMismatch(account.address)
                }
                // Migration-only read of the original tag. The activated
                // snapshot binds its owner; no address-scoped secret is made.
                entropy = try keystore.fetchKey(
                    for: KeystoreTag.legacyEntropy.rawValue
                )
                if let entropy {
                    try keystore.verifyLegacyIrohaKeyIfPresent(entropy: entropy)
                }
            }
            defer {
                Self.wipeSensitive(&entropy)
                Self.wipeSensitive(&rawSeed)
                Self.wipeSensitive(&legacySecret)
            }
            guard
                !isExplicitWatchOnly ||
                    (entropy == nil && rawSeed == nil && legacySecret == nil)
            else {
                // Preserve the explicit account type. Conflicting protected evidence must
                // enter recovery instead of silently enabling signing for a watch-only wallet.
                throw WalletNetworkMigrationError.legacyIdentityMismatch(
                    account.address
                )
            }
            guard
                entropy != nil ||
                    rawSeed != nil ||
                    legacySecret != nil ||
                    isExplicitWatchOnly
            else {
                // Missing or unreadable signing material must never be
                // reclassified as watch-only during an upgrade.
                throw WalletNetworkMigrationError.legacyIdentityMismatch(
                    account.address
                )
            }
            let retainedMnemonicSource: WalletSecretSource?
            if let entropy {
                let wordCount = try IRMnemonicCreator(language: .english)
                    .mnemonic(fromEntropy: entropy)
                    .allWords()
                    .count
                guard
                    let source = WalletMnemonicWordPolicy
                        .retainedSecretSource(forWordCount: wordCount)
                else {
                    throw WalletNetworkMigrationError.legacyIdentityMismatch(
                        account.address
                    )
                }
                retainedMnemonicSource = source
            } else {
                retainedMnemonicSource = nil
            }
            let source: WalletSecretSource = retainedMnemonicSource ?? (
                rawSeed != nil
                    ? .rawSeed
                    : (legacySecret != nil ? .legacySecret : .watchOnly)
            )
            let walletId = account.address

            try validateLegacyIdentity(
                account,
                entropy: entropy,
                rawSeed: rawSeed,
                secret: legacySecret
            )

            identities.append(
                WalletIdentity(
                    id: walletId,
                    displayName: account.username,
                    existingSoraAddress: account.address,
                    secretSource: source
                )
            )
            networkAccounts.append(
                NetworkAccount(
                    walletId: walletId,
                    networkId: .sora2,
                    derivationVersion: 0,
                    publicKey: account.publicKeyData,
                    address: account.address
                )
            )

            guard
                source == .mnemonicEntropy,
                var derivationEntropy = entropy
            else {
                continue
            }
            defer { Self.wipeSensitive(&derivationEntropy) }
            var phrase = try IRMnemonicCreator(language: .english)
                .mnemonic(fromEntropy: derivationEntropy)
                .toString()
            defer { phrase.removeAll(keepingCapacity: false) }
            var derivationProfiles = admissionPolicy
                .admittedDerivationProfiles
            if let current {
                let admittedNetworkIds = Set(
                    derivationProfiles.map(\.networkId)
                )
                let retainedNetworkIds = Set(
                    current.accounts.filter({
                        $0.walletId == walletId &&
                            $0.networkId != .sora2
                    }).map(\.networkId)
                )
                for networkId in retainedNetworkIds
                    .subtracting(admittedNetworkIds)
                    .sorted(by: { $0.rawValue < $1.rawValue }) {
                    guard
                        let profile = NexusDerivationProfile.persisted(
                            networkId: networkId
                        )
                    else {
                        throw WalletNetworkMigrationError
                            .snapshotVerificationFailed
                    }
                    derivationProfiles.append(profile)
                }
            }
            for profile in derivationProfiles {
                var child = try NexusKeyDerivation.derive(
                    mnemonic: phrase,
                    profile: profile
                )
                defer {
                    child.privateKey.resetBytes(
                        in: child.privateKey.startIndex ..<
                            child.privateKey.endIndex
                    )
                    child.chainCode.resetBytes(
                        in: child.chainCode.startIndex ..<
                            child.chainCode.endIndex
                    )
                }
                networkAccounts.append(
                    NetworkAccount(
                        walletId: walletId,
                        networkId: profile.networkId,
                        derivationVersion: 1,
                        publicKey: child.publicKey,
                        address: child.address
                    )
                )
            }
        }

        let snapshot = WalletNetworkSnapshot(
            schemaVersion: WalletNetworkSnapshot.currentSchemaVersion,
            selectedWalletId: selectedAddress,
            wallets: identities,
            accounts: networkAccounts,
            createdAt: Date()
        )
        try verifyLegacyAccounts(accounts, in: snapshot)
        if let current {
            try verifyExistingNexusChildren(
                current,
                against: snapshot
            )
        }

        if let current,
           current.schemaVersion == snapshot.schemaVersion,
           current.selectedWalletId == snapshot.selectedWalletId,
           current.wallets == snapshot.wallets,
           current.accounts == snapshot.accounts {
            settings.walletNetworkStoreVersion = WalletNetworkSnapshot.currentSchemaVersion
            return
        }

        try store.stageAndActivate(snapshot)
        settings.walletNetworkStoreVersion = WalletNetworkSnapshot.currentSchemaVersion
    }

    private static func wipeSensitive(_ value: inout Data?) {
        if let count = value?.count {
            value?.resetBytes(in: 0 ..< count)
        }
        value = nil
    }

    private static func wipeSensitive(_ value: inout Data) {
        value.resetBytes(in: value.startIndex ..< value.endIndex)
    }

    private func verifyLegacyAccounts(
        _ accounts: [AccountItem],
        in snapshot: WalletNetworkSnapshot
    ) throws {
        let soraAccounts = Dictionary(
            grouping: snapshot.accounts.filter {
                $0.networkId == .sora2
            },
            by: \.walletId
        )
        let legacyAccounts = Dictionary(
            grouping: accounts,
            by: \.address
        )
        guard
            soraAccounts.count == accounts.count,
            legacyAccounts.count == accounts.count,
            soraAccounts.values.allSatisfy({ $0.count == 1 }),
            legacyAccounts.values.allSatisfy({ $0.count == 1 })
        else {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }
        for account in accounts {
            guard
                let stored = soraAccounts[account.address]?.first,
                stored.address == account.address,
                stored.publicKey == account.publicKeyData
            else {
                throw WalletNetworkMigrationError.legacyIdentityMismatch(account.address)
            }
        }
    }

    private func verifyExistingSnapshot(
        _ snapshot: WalletNetworkSnapshot,
        against accounts: [AccountItem]
    ) throws {
        let currentByAddress = Dictionary(
            grouping: accounts,
            by: \.address
        )
        let storedSoraAccounts = Dictionary(
            grouping: snapshot.accounts.filter {
                $0.networkId == .sora2
            },
            by: \.walletId
        )
        guard
            currentByAddress.values.allSatisfy({ $0.count == 1 }),
            storedSoraAccounts.values.allSatisfy({ $0.count == 1 })
        else {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }
        for legacy in storedSoraAccounts.values.compactMap(\.first) {
            guard
                let current = currentByAddress[legacy.walletId]?.first,
                current.address == legacy.address,
                current.publicKeyData == legacy.publicKey
            else {
                // A previously inventoried account disappearing is never
                // silently accepted as an upgrade-side deletion.
                throw WalletNetworkMigrationError.legacyIdentityMismatch(legacy.address)
            }
        }
    }

    private func verifyExistingNexusChildren(
        _ current: WalletNetworkSnapshot,
        against expected: WalletNetworkSnapshot
    ) throws {
        let currentWallets = Dictionary(
            grouping: current.wallets,
            by: \.id
        )
        let currentAccounts = Dictionary(
            grouping: current.accounts,
            by: \.id
        )
        let expectedWallets = Dictionary(
            grouping: expected.wallets,
            by: \.id
        )
        let expectedAccounts = Dictionary(
            grouping: expected.accounts,
            by: \.id
        )
        guard
            currentWallets.values.allSatisfy({ $0.count == 1 }),
            currentAccounts.values.allSatisfy({ $0.count == 1 }),
            expectedWallets.values.allSatisfy({ $0.count == 1 }),
            expectedAccounts.values.allSatisfy({ $0.count == 1 })
        else {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }

        for wallet in current.wallets {
            guard
                let expectedWallet = expectedWallets[wallet.id]?.first,
                expectedWallet.secretSource == wallet.secretSource
            else {
                // The active snapshot is durable evidence of whether this
                // wallet is signing-capable and which retained source owns its
                // SORA2 identity. Missing Keychain material or a stale
                // watch-only marker is never authority to rewrite that source
                // classification during startup.
                throw WalletNetworkMigrationError.legacyIdentityMismatch(
                    wallet.existingSoraAddress
                )
            }

            let storedChildren = current.accounts.filter {
                $0.walletId == wallet.id && $0.networkId != .sora2
            }
            if wallet.secretSource != .mnemonicEntropy {
                guard storedChildren.isEmpty else {
                    throw WalletNetworkMigrationError.legacyIdentityMismatch(
                        wallet.existingSoraAddress
                    )
                }
                continue
            }

            let derivedChildren = expected.accounts.filter {
                $0.walletId == wallet.id && $0.networkId != .sora2
            }
            let storedChildNetworkIds = Set(
                storedChildren.map(\.networkId)
            )
            let expectedChildNetworkIds = storedChildNetworkIds.union(
                admissionPolicy.admittedDerivationProfiles
                    .map(\.networkId)
            )
            guard
                derivedChildren.count == expectedChildNetworkIds.count,
                Set(derivedChildren.map(\.networkId)) ==
                    expectedChildNetworkIds,
                storedChildren.allSatisfy({ child in
                    expectedAccounts[child.id]?.first == child
                })
            else {
                // Retained children must re-derive byte-for-byte. A newly
                // admitted child may be appended, but admission withdrawal is
                // never authority to delete historical recovery evidence.
                throw WalletNetworkMigrationError.legacyIdentityMismatch(
                    wallet.existingSoraAddress
                )
            }
        }
    }

    private func validateLegacyIdentity(
        _ account: AccountItem,
        entropy: Data?,
        rawSeed: Data?,
        secret: Data?
    ) throws {
        try LegacySoraIdentityValidator.validate(
            address: account.address,
            publicKey: account.publicKeyData,
            cryptoType: account.cryptoType,
            networkType: account.networkType,
            derivationPath: try keystore.fetchDeriviationForAddress(account.address),
            entropy: entropy,
            rawSeed: rawSeed,
            secret: secret,
            recoveryGate: recoveryGate
        )
    }
}
