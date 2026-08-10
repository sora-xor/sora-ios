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
import IrohaCrypto
import SoraKeystore
import SSFUtils

enum KeystoreTag: String, CaseIterable {
    case pincode = "pincode"
    case legacyEntropy = "seedEntropy"
    case legacyUsername = "userName"

    static func secretKeyTagForAddress(_ address: String) -> String { address + "-" + "secretKey" }
    static func entropyTagForAddress(_ address: String) -> String { address + "-" + "entropy"}
    static func deriviationTagForAddress(_ address: String) -> String { address + "-" + "deriv"}
    static func seedTagForAddress(_ address: String) -> String { address + "-" + "seed" }
}

extension KeystoreProtocol {
    func hasRetainedWalletMaterial() throws -> Bool {
        let scopedWalletSuffixes = [
            "-secretKey",
            "-entropy",
            "-deriv",
            "-seed",
        ]
        return try allKeyIdentifiers().contains { identifier in
                identifier == KeystoreTag.pincode.rawValue ||
                identifier == KeystoreTag.legacyEntropy.rawValue ||
                // The pre-account-model username is wallet-installation evidence even
                // when its paired entropy is missing or unreadable. Treating this known
                // retained tag as a pristine namespace could route an upgrade to
                // onboarding and let the user create a replacement wallet.
                identifier == KeystoreTag.legacyUsername.rawValue ||
                identifier == "privateKey" ||
                scopedWalletSuffixes.contains { identifier.hasSuffix($0) }
        }
    }

    func deleteAll(for address: String) throws {
        try deleteWalletMaterial(for: address)
        try deleteKeysIfExist(
            for: KeystoreTag.allCases.map(\.rawValue)
        )
    }

    func deleteWalletMaterial(for address: String) throws {
        try deleteKeysIfExist(
            for: [
                KeystoreTag.secretKeyTagForAddress(address),
                KeystoreTag.entropyTagForAddress(address),
                KeystoreTag.deriviationTagForAddress(address),
                KeystoreTag.seedTagForAddress(address)
            ]
        )
    }

    func deleteEntropy(for address: String) throws {
        try deleteKeyIfExists(for: KeystoreTag.entropyTagForAddress(address))
    }

    func loadIfKeyExists(_ tag: String) throws -> Data? {
        guard try checkKey(for: tag) else {
            return nil
        }

        return try fetchKey(for: tag)
    }

    func saveSecretKey(_ secretKey: Data, address: String) throws {
        let tag = KeystoreTag.secretKeyTagForAddress(address)

        try saveKey(secretKey, with: tag)
    }

    func fetchSecretKeyForAddress(_ address: String) throws -> Data? {
        let tag = KeystoreTag.secretKeyTagForAddress(address)

        return try loadIfKeyExists(tag)
    }

    func checkSecretKeyForAddress(_ address: String) throws -> Bool {
        let tag = KeystoreTag.secretKeyTagForAddress(address)
        return try checkKey(for: tag)
    }

    func saveEntropy(_ entropy: Data, address: String) throws {
        let tag = KeystoreTag.entropyTagForAddress(address)

        try saveKey(entropy, with: tag)
    }

    func fetchEntropyForAddress(_ address: String) throws -> Data? {
        let tag = KeystoreTag.entropyTagForAddress(address)
        if let scoped = try loadIfKeyExists(tag) {
            return scoped
        }

        return try fetchRetainedLegacyEntropyForAddress(
            address,
            activeSnapshot: try WalletNetworkStore().load()
        )
    }

    /// Testable/in-transaction form used when the caller has already pinned
    /// the exact active snapshot under a wallet lifecycle lease.
    func fetchEntropyForAddress(
        _ address: String,
        activeSnapshot: WalletNetworkSnapshot
    ) throws -> Data? {
        let tag = KeystoreTag.entropyTagForAddress(address)
        if let scoped = try loadIfKeyExists(tag) {
            return scoped
        }

        return try fetchRetainedLegacyEntropyForAddress(
            address,
            activeSnapshot: activeSnapshot
        )
    }

    private func fetchRetainedLegacyEntropyForAddress(
        _ address: String,
        activeSnapshot snapshot: WalletNetworkSnapshot?
    ) throws -> Data? {

        // The oldest installations retained one unsuffixed entropy record.
        // Resolve it only through an already activated, exact SORA2 identity;
        // never copy it into a new Keychain tag or guess its owner.
        guard let snapshot else {
            return nil
        }
        let matchingWallets = snapshot.wallets.filter {
            $0.id == address && $0.existingSoraAddress == address
        }
        let matchingSoraAccounts = snapshot.accounts.filter {
            $0.walletId == address &&
                $0.networkId == .sora2 &&
                $0.derivationVersion == 0 &&
                $0.address == address
        }
        guard
            try !checkKey(
                for: KeystoreTag.secretKeyTagForAddress(address)
            ),
            try !checkKey(for: KeystoreTag.seedTagForAddress(address)),
            try !checkKey(
                for: KeystoreTag.deriviationTagForAddress(address)
            ),
            try !checkKey(for: "privateKey"),
            matchingWallets.count == 1,
            let wallet = matchingWallets.first,
            wallet.secretSource == .mnemonicEntropy ||
                wallet.secretSource == .legacyMnemonicEntropy,
            matchingSoraAccounts.count == 1,
            let soraAccount = matchingSoraAccounts.first,
            try checkKey(for: KeystoreTag.legacyEntropy.rawValue)
        else {
            return nil
        }

        var legacyEntropy = try fetchKey(
            for: KeystoreTag.legacyEntropy.rawValue
        )
        do {
            let mnemonic = try IRMnemonicCreator(language: .english)
                .mnemonic(fromEntropy: legacyEntropy)
            guard
                WalletMnemonicWordPolicy.retainedSecretSource(
                    forWordCount: mnemonic.allWords().count
                ) == wallet.secretSource
            else {
                throw WalletNetworkMigrationError
                    .legacyIdentityMismatch(address)
            }
            try LegacySoraIdentityValidator.validate(
                address: address,
                publicKey: soraAccount.publicKey,
                cryptoType: .sr25519,
                networkType: SNAddressType(chain: .sora),
                derivationPath: nil,
                entropy: legacyEntropy,
                rawSeed: nil,
                secret: nil
            )
            return legacyEntropy
        } catch {
            legacyEntropy.resetBytes(
                in: legacyEntropy.startIndex ..< legacyEntropy.endIndex
            )
            throw error
        }
    }

    func checkEntropyForAddress(_ address: String) throws -> Bool {
        var entropy = try fetchEntropyForAddress(address)
        defer {
            if let count = entropy?.count {
                entropy?.resetBytes(in: 0 ..< count)
            }
            entropy = nil
        }
        return entropy != nil
    }

    func saveDeriviation(_ path: String, address: String) throws {
        guard let data = path.data(using: .utf8) else {
            return
        }

        let tag = KeystoreTag.deriviationTagForAddress(address)

        try saveKey(data, with: tag)
    }

    func fetchDeriviationForAddress(_ address: String) throws -> String? {
        let tag = KeystoreTag.deriviationTagForAddress(address)

        guard let data = try loadIfKeyExists(tag) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    func checkDeriviationForAddress(_ address: String) throws -> Bool {
        let tag = KeystoreTag.deriviationTagForAddress(address)
        return try checkKey(for: tag)
    }

    func saveSeed(_ data: Data, address: String) throws {
        let tag = KeystoreTag.seedTagForAddress(address)

        try saveKey(data, with: tag)
    }

    func fetchSeedForAddress(_ address: String) throws -> Data? {
        let tag = KeystoreTag.seedTagForAddress(address)

        return try loadIfKeyExists(tag)
    }

    func checkSeedForAddress(_ address: String) throws -> Bool {
        let tag = KeystoreTag.seedTagForAddress(address)
        return try checkKey(for: tag)
    }
}

extension SettingsManagerProtocol {
    func hasRetainedWalletSettings() -> Bool {
        let retainedKeys = Set([
            SettingsKey.selectedAccount.rawValue,
            // Legacy identity registration was produced only for an installed
            // wallet. A surviving DID or public-key identifier with a missing
            // selected-account payload is an inconsistent upgrade, not a
            // pristine namespace that may create a replacement wallet.
            SettingsKey.decentralizedId.rawValue,
            SettingsKey.publicKeyId.rawValue,
            // A completed legacy migration proves that wallet-backed identity
            // state existed even if its account record is now unreadable.
            SettingsKey.hasMigrated.rawValue,
            SettingsKey.migratedAccountsV1.rawValue,
            // Written only after a wallet-network snapshot is verified or
            // atomically activated. If the snapshot later disappears, this
            // marker is evidence of a damaged installation, not first run.
            SettingsKey.walletNetworkStoreVersion.rawValue,
            // Pre-account-model releases retained the display name under this
            // raw key. Its presence is installation evidence even if the
            // selected-account payload or paired entropy can no longer be read.
            KeystoreTag.legacyUsername.rawValue,
        ])
        return allKeys().contains { retainedKeys.contains($0) }
    }

    func hasRetainedWatchOnlyWallet() -> Bool {
        let prefix = "wallet.watchOnly."
        return allKeys().contains { key in
            guard key.hasPrefix(prefix), key.count > prefix.count else {
                return false
            }
            guard let marker = anyValue(for: key) as? Bool else {
                // A malformed marker still names a retained wallet. Preserve
                // it as recovery evidence instead of treating it as `false`.
                return true
            }
            return marker
        }
    }
}
