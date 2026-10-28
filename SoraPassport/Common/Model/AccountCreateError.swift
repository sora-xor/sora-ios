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

enum AccountCreateError: Error {
    case invalidMnemonicSize
    case invalidMnemonicFormat
    case invalidSeed
    case invalidKeystore
    case unsupportedNetwork
    case duplicated
    /// This iPhone already has different saved keys for the same address.
    /// Nothing was written; the existing items are left as they are.
    case retainedKeyConflict
    /// A Google Drive backup's phrase, seed or JSON does not derive the
    /// address the backup was saved for. Nothing was written.
    case backupIdentityMismatch
}

extension AccountCreateError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let title: String
        let message: String

        switch self {
        case .invalidMnemonicSize:
            title = R.string.localizable.mnemonicInvalidTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable
                .accessRestoreWordsErrorMessage(preferredLanguages: locale?.rLanguages)
        case .invalidMnemonicFormat:
            title = R.string.localizable.mnemonicInvalidTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable
                .accessRestorePhraseErrorMessage(preferredLanguages: locale?.rLanguages)
        case .invalidSeed:
            title = R.string.localizable.commonErrorSeedIsNotValidTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable.commonErrorSeedIsNotValid(preferredLanguages: locale?.rLanguages)
        case .duplicated:
            title = R.string.localizable.accountAlreadyImported(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable.accountAlreadyImportedDescription(preferredLanguages: locale?.rLanguages)
        case .retainedKeyConflict:
            title = WalletUX.text("Keys already on this iPhone", language: locale?.rLanguages?.first)
            message = WalletUX.text(
                "This iPhone already has different saved keys for this wallet. Nothing was changed. Contact SORA support.",
                language: locale?.rLanguages?.first
            )
        case .backupIdentityMismatch:
            title = WalletUX.text("Backup not restored", language: locale?.rLanguages?.first)
            message = WalletUX.text(
                "This backup does not match the wallet it was saved for. Nothing was changed.",
                language: locale?.rLanguages?.first
            )
        case .invalidKeystore:
            title = WalletUX.text("Invalid JSON backup", language: locale?.rLanguages?.first)
            message = WalletUX.text("Paste the complete contents of a wallet JSON backup file. A recovery phrase or wallet address cannot be used here.", language: locale?.rLanguages?.first)
        case .unsupportedNetwork:
            title = R.string.localizable.accountImportDefaultError(preferredLanguages: locale?.rLanguages)
            message = "" // TODO: no design
        }

        return ErrorContent(title: title, message: message)
    }
}
