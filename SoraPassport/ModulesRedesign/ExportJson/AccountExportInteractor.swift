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

import UIKit
import FearlessUtils
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
            print("Error KeystoreExport to file: \(error.localizedDescription)")
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
            print("Error KeystoreExport to file: \(error.localizedDescription)")
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
            print("Error writing the file: \(error.localizedDescription)")
        }
        return nil
    }
}
