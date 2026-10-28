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

final class AccountExportRawSeedInteractor {
    weak var presenter: AccountExportRawSeedInteractorOutputProtocol!

    private(set) var keystore: KeystoreProtocol
    private let account: AccountItem
    private var rawSeed = ""

    init(
        keystore: KeystoreProtocol,
        settings: SettingsManagerProtocol,
        account: AccountItem
    ) {
        self.keystore = keystore
        self.account = account
    }
}

extension AccountExportRawSeedInteractor: AccountExportRawSeedInteractorInputProtocol {
    func copyRawSeedToClipboard() {
        guard !rawSeed.isEmpty else { return }
        UIPasteboard.general.setItems([["public.utf8-plain-text": rawSeed]],
            options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(45)])
    }

    func exportRawSeed() {
        do {
            rawSeed = ""
            var backup = try WalletBackupMaterial.load(for: account, keystore: keystore)
            defer { backup.wipe() }
            guard let expectedSeedData = backup.seed else {
                presenter.set(rawSeed: "", derivationPath: "")
                return
            }
            rawSeed = expectedSeedData.toHex(includePrefix: true)
            presenter.set(rawSeed: rawSeed, derivationPath: backup.derivationPath ?? "")
        } catch {
            // Never emit the address, Keychain identifier, or underlying error from a
            // secret-export path. The presenter keeps the existing no-value failure behavior.
            rawSeed = ""
            presenter.set(rawSeed: "", derivationPath: "")
            return
        }
    }
}
