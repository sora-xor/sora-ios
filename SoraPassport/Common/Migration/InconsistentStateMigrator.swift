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
