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

    init(
        keystore: KeystoreProtocol,
        settings: SettingsManagerProtocol,
        accounts: [AccountItem]
    ) {
        self.keystore = keystore
        self.settings = settings
        self.accounts = accounts
    }
}

extension AccountExportInteractor: AccountExportInteractorInputProtocol {

    func exportToFileWith(password: String) -> NSURL? {
        guard !accounts.isEmpty else { return nil }
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
            let url = exportData.saveToFile(name: "\(account.address).json") ?? .init()
            return url
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
            let url = exportData.saveToFile(name: "batch_exported_account_\(Date().timeIntervalSince1970).json") ?? .init()
            return url
        } catch {
            // Keychain errors can contain an address-derived identifier.
            return nil
        }
    }
}

extension Data {
    func saveToFile(name: String) -> NSURL? {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let filePath = (paths[0] as NSString).appendingPathComponent(name)
        do {
            try self.write(to: URL(fileURLWithPath: filePath))
            return NSURL(fileURLWithPath: filePath)
        } catch {
            // The destination path can contain the exported account address.
        }
        return nil
    }
}
