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

import Foundation
import SoraKeystore

enum WalletIntegrityError: LocalizedError, Equatable {
    case selectedAccountSecretMissing(address: String)
    case selectedAccountMissing
    case legacyWalletUpgradeVerificationFailed

    var errorDescription: String? {
        switch self {
        case .selectedAccountSecretMissing:
            return "The secure key for the selected wallet is unavailable. The wallet data was preserved."
        case .selectedAccountMissing:
            return "Existing wallet data was found, but the selected wallet setting is unavailable. The wallet data was preserved."
        case .legacyWalletUpgradeVerificationFailed:
            return "The protected legacy wallet could not be verified and was preserved without creating a replacement account."
        }
    }
}

final class InconsistentStateMigrator: Migrating {
    private(set) var settings: SettingsManagerProtocol
    private(set) var keychain: KeystoreProtocol

    init(
        settings: SettingsManagerProtocol,
        keychain: KeystoreProtocol
    ) {
        self.settings = settings
        self.keychain = keychain
    }

    /// Logs a selected account that has no signing material on this device.
    ///
    /// It does not latch recovery or change any data: that account is
    /// read-only here (signing reports `keysNotOnThisDevice`) and the user
    /// can restore it with its phrase or backup. Every other account stays
    /// usable. App Store 3.8.6 called `settings.removeAll()` here.
    func migrate() throws {
        guard let selectedAccount = SelectedWalletSettings.shared.currentAccount else {
            return
        }

        let hasSecretKey = try keychain.checkSecretKeyForAddress(selectedAccount.address)
        let hasEntropy = try keychain.checkEntropyForAddress(
            selectedAccount.address
        )
        let hasRawSeed = try keychain.checkSeedForAddress(
            selectedAccount.address
        )
        let isExplicitWatchOnly =
            settings.bool(for: "wallet.watchOnly.\(selectedAccount.address)") == true

        if !hasSecretKey && !hasEntropy && !hasRawSeed && !isExplicitWatchOnly {
            Logger.shared.warning("Selected wallet is read-only on this device: signing material unavailable")
            throw WalletIntegrityError.selectedAccountSecretMissing(address: selectedAccount.address)
        }
    }
}
