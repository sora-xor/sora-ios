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
