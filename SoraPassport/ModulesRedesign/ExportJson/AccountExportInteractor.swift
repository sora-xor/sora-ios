// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import IrohaCrypto
import SSFUtils
import RobinHood
import SoraKeystore

final class AccountExportInteractor {
    weak var presenter: AccountExportInteractorOutputProtocol!

    private(set) var keystore: KeystoreProtocol
    private(set) var settings: SettingsManagerProtocol
    private let accounts: [AccountItem]
    private let fileStore: AccountExportFileStore

    init(
        keystore: KeystoreProtocol,
        settings: SettingsManagerProtocol,
        accounts: [AccountItem],
        fileStore: AccountExportFileStore = AccountExportFileStore()
    ) {
        self.keystore = keystore
        self.settings = settings
        self.accounts = accounts
        self.fileStore = fileStore
        // An export left by a share sheet that never finished (the app was
        // stopped while sharing) is removed when the export screen opens.
        fileStore.removeAll()
    }
}

extension AccountExportInteractor: AccountExportInteractorInputProtocol {

    func exportToFileWith(password: String) -> NSURL? {
        // A leaked JSON file can be guessed offline, so never encrypt one with
        // a password the creation policy refuses, whatever the screen allowed.
        guard BackupPasswordPolicy.violation(for: password) == nil, !accounts.isEmpty else { return nil }
        if accounts.count == 1 {
            return exportAccountToFile(account: accounts.first!, password: password)
        } else {
            return exportAccountsToFile(accounts: accounts, password: password)
        }
    }

    private func exportAccountToFile(account: AccountItem, password: String) -> NSURL? {
        do {
            _ = try keystore.fetchSecretKeyForAddress(account.address)
            let exportData: Data = try KeystoreExportWrapper(keystore: keystore).export(account: account, password: password)
            return try fileStore.write(exportData, name: "\(account.address).json") as NSURL
        } catch {
            // Keychain errors can contain an address-derived identifier.
            return nil
        }
    }

    private func exportAccountsToFile(accounts: [AccountItem], password: String) -> NSURL? {
        guard let account = accounts.first else { return nil }
        do {
            _ = try keystore.fetchSecretKeyForAddress(account.address)
            let exportData: Data = try KeystoreExportWrapper(keystore: keystore).export(accounts: accounts, password: password)
            let name = "batch_exported_account_\(Date().timeIntervalSince1970).json"
            return try fileStore.write(exportData, name: name) as NSURL
        } catch {
            // Keychain errors can contain an address-derived identifier.
            return nil
        }
    }
}

/// Keeps an encrypted JSON export only while the share sheet needs it: in a
/// folder of the app's temporary directory (never Documents), with complete
/// file protection and excluded from device backups. The wireframe removes
/// the file when sharing ends; one left because the app stopped while sharing
/// is removed before the next export and when the export screen opens.
struct AccountExportFileStore {
    enum Failure: Error {
        case invalidName
        case protectionNotApplied
    }

    static let directoryName = "AccountExport"

    let directory: URL
    private let fileManager: FileManager

    init(temporaryDirectory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        directory = (temporaryDirectory ?? fileManager.temporaryDirectory)
            .appendingPathComponent(Self.directoryName, isDirectory: true)
    }

    /// Replaces any earlier export with `data`, under the exact file name the
    /// user sees when sharing.
    func write(_ data: Data, name: String) throws -> URL {
        guard !name.isEmpty, name != ".", name != "..", !name.contains("/") else {
            throw Failure.invalidName
        }
        removeAll()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )
        try excludeFromBackup(directory)
        let url = directory.appendingPathComponent(name, isDirectory: false)
        do {
            try data.write(to: url, options: [.withoutOverwriting, .completeFileProtection])
            try FileProtectionMetadata.setProtectionClass(.complete, at: url, fileManager: fileManager)
            guard try FileProtectionMetadata.protectionClass(at: url, fileManager: fileManager) == .complete else {
                throw Failure.protectionNotApplied
            }
            try excludeFromBackup(url)
            return url
        } catch {
            // The path contains the exported account address; never log it.
            try? fileManager.removeItem(at: url)
            throw error
        }
    }

    /// Removes a file this store wrote. Any other URL is left untouched.
    func remove(_ url: URL) {
        guard url.isFileURL,
              url.deletingLastPathComponent().standardizedFileURL.path == directory.standardizedFileURL.path else {
            return
        }
        try? fileManager.removeItem(at: url)
    }

    /// Removes every export, including one a terminated share sheet left.
    func removeAll() {
        try? fileManager.removeItem(at: directory)
    }

    private func excludeFromBackup(_ url: URL) throws {
        var target = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try target.setResourceValues(values)
        // Read back through a fresh URL so a cached value cannot pass.
        let stored = try URL(fileURLWithPath: url.path).resourceValues(forKeys: [.isExcludedFromBackupKey])
        guard stored.isExcludedFromBackup == true else { throw Failure.protectionNotApplied }
    }
}

/// JSON exports made before 3.9.2. Those versions wrote each export to the
/// top level of Documents, as `<address>.json` or
/// `batch_exported_account_<time>.json`, and never removed it, so it kept
/// the default protection class and went into device backups.
///
/// The app never reads them again and does not share Documents with Files,
/// but an owner may still rely on one, so they are never deleted, moved or
/// rewritten. Each launch only gives them complete file protection and
/// excludes them from device backups.
enum LegacyAccountExportFiles {
    private static let batchPrefix = "batch_exported_account_"

    /// The legacy exports directly in `documents`: regular files named after
    /// a valid SS58 address or a batch export, with the `json` extension.
    /// Folders, links and other files are never included.
    static func exports(in documents: URL, fileManager: FileManager = .default) -> [URL] {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey]
        guard let entries = try? fileManager.contentsOfDirectory(
            at: documents,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        let addressFactory = SS58AddressFactory()
        return entries.filter { url in
            guard url.pathExtension == "json",
                  let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true, values.isSymbolicLink != true else {
                return false
            }
            let stem = url.deletingPathExtension().lastPathComponent
            return isBatchExportStem(stem) || isAddress(stem, factory: addressFactory)
        }
    }

    /// Protects every legacy export in `documents` and returns the ones that
    /// could not be protected now, for example while the device is locked.
    /// Repeating it is harmless, so a later launch simply tries again.
    @discardableResult
    static func protect(in documents: URL, fileManager: FileManager = .default) -> [URL] {
        exports(in: documents, fileManager: fileManager).filter { !protect($0, fileManager: fileManager) }
    }

    /// Changes attributes only; the file's bytes are never read or written.
    private static func protect(_ url: URL, fileManager: FileManager) -> Bool {
        do {
            if (try? FileProtectionMetadata.protectionClass(at: url, fileManager: fileManager)) != .complete {
                try FileProtectionMetadata.setProtectionClass(.complete, at: url, fileManager: fileManager)
            }
            if (try? URL(fileURLWithPath: url.path).resourceValues(forKeys: [.isExcludedFromBackupKey]))?
                .isExcludedFromBackup != true {
                var target = url
                var values = URLResourceValues()
                values.isExcludedFromBackup = true
                try target.setResourceValues(values)
            }
            // Read back through a fresh URL so a cached value cannot pass.
            let stored = try URL(fileURLWithPath: url.path).resourceValues(forKeys: [.isExcludedFromBackupKey])
            let protection = try FileProtectionMetadata.protectionClass(at: url, fileManager: fileManager)
            return stored.isExcludedFromBackup == true && protection == .complete
        } catch {
            // The file name contains the exported account address; never log it.
            return false
        }
    }

    /// A valid SS58 address, checksum included: `type(fromAddress:)` alone
    /// checks only the length and the network prefix.
    private static func isAddress(_ stem: String, factory: SS58AddressFactory) -> Bool {
        guard let type = try? factory.type(fromAddress: stem) else { return false }
        return (try? factory.accountId(fromAddress: stem, type: type.uint16Value)) != nil
    }

    /// `batch_exported_account_` followed by the export time in seconds
    /// since 1970, as `Date().timeIntervalSince1970` printed it.
    private static func isBatchExportStem(_ stem: String) -> Bool {
        guard stem.hasPrefix(batchPrefix) else { return false }
        let time = stem.dropFirst(batchPrefix.count)
        return !time.isEmpty && time.allSatisfy { $0.isASCII && ($0.isNumber || $0 == ".") } && Double(time) != nil
    }
}
