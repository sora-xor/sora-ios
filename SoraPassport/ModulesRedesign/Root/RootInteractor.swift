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
import CryptoKit
import SoraKeystore
import IrohaCrypto

enum LegacyWalletUpgradePolicy {
    static func isCandidate(
        keyIdentifiers: Set<String>,
        hasWatchOnlyWallet: Bool,
        snapshot: WalletNetworkSnapshot?,
        legacyIrohaKeyVerified: Bool = false
    ) -> Bool {
        let scopedSuffixes = [
            "-secretKey",
            "-entropy",
            "-deriv",
            "-seed",
        ]
        let hasScopedWallet = keyIdentifiers.contains {
            identifier in
            scopedSuffixes.contains {
                identifier.hasSuffix($0)
            }
        }
        // Some pre-account-model releases stored signing material under the
        // unscoped `privateKey` tag. Admit that pair only after the production
        // overload proves that it belongs to this exact retained entropy.
        let hasUnscopedPrivateKey = keyIdentifiers.contains("privateKey")
        return keyIdentifiers.contains(
            KeystoreTag.legacyEntropy.rawValue
        ) &&
            !hasScopedWallet &&
            (!hasUnscopedPrivateKey || legacyIrohaKeyVerified) &&
            !hasWatchOnlyWallet &&
            (snapshot?.selectedWalletId == nil) &&
            (snapshot?.wallets.isEmpty ?? true) &&
            (snapshot?.accounts.isEmpty ?? true)
    }

    static func isCandidate(
        keystore: KeystoreProtocol,
        hasWatchOnlyWallet: Bool,
        snapshot: WalletNetworkSnapshot?
    ) throws -> Bool {
        guard isCandidate(
            keyIdentifiers: Set(try keystore.allKeyIdentifiers()),
            hasWatchOnlyWallet: hasWatchOnlyWallet,
            snapshot: snapshot,
            legacyIrohaKeyVerified: true
        ) else { return false }
        var entropy = try keystore.fetchKey(for: KeystoreTag.legacyEntropy.rawValue)
        defer { entropy.resetBytes(in: entropy.startIndex ..< entropy.endIndex) }
        try keystore.verifyLegacyIrohaKeyIfPresent(entropy: entropy)
        return true
    }

    static func shouldDeferStorageMigration(
        storeExists: Bool,
        keystore: KeystoreProtocol,
        hasWatchOnlyWallet: Bool,
        snapshot: WalletNetworkSnapshot?
    ) throws -> Bool {
        try !storeExists && isCandidate(
            keystore: keystore,
            hasWatchOnlyWallet: hasWatchOnlyWallet,
            snapshot: snapshot
        )
    }

    static func shouldDeferStorageMigration(
        storeExists: Bool,
        keyIdentifiers: Set<String>,
        hasWatchOnlyWallet: Bool,
        snapshot: WalletNetworkSnapshot?
    ) -> Bool {
        !storeExists && isCandidate(
            keyIdentifiers: keyIdentifiers,
            hasWatchOnlyWallet: hasWatchOnlyWallet,
            snapshot: snapshot
        )
    }
}

/// Resolves the pre-account-model display name without normalizing or moving
/// either retained source. Some production releases stored `userName` in
/// settings, while older installations kept the same UTF-8 value in Keychain.
/// Conflicting or malformed evidence is a recovery condition, not permission
/// to silently choose one value and change the wallet's visible identity.
enum LegacyWalletUpgradeDisplayNameResolver {
    private static let maximumUTF8Bytes = 4 * 1_024

    static func resolve(
        settings: SettingsManagerProtocol,
        keystore: KeystoreProtocol
    ) throws -> String {
        let key = KeystoreTag.legacyUsername.rawValue

        let settingsName: String?
        if settings.allKeys().contains(key) {
            guard
                let retained = settings.anyValue(for: key) as? String,
                retained.utf8.count <= maximumUTF8Bytes
            else {
                throw WalletIntegrityError
                    .legacyWalletUpgradeVerificationFailed
            }
            settingsName = retained
        } else {
            settingsName = nil
        }

        var keychainBytes = try keystore.loadIfKeyExists(key)
        defer {
            if let count = keychainBytes?.count {
                keychainBytes?.resetBytes(in: 0 ..< count)
            }
            keychainBytes = nil
        }
        let keychainName: String?
        if let keychainBytes {
            guard
                keychainBytes.count <= maximumUTF8Bytes,
                let retained = String(
                    data: keychainBytes,
                    encoding: .utf8
                ),
                retained.utf8.count == keychainBytes.count
            else {
                throw WalletIntegrityError
                    .legacyWalletUpgradeVerificationFailed
            }
            keychainName = retained
        } else {
            keychainName = nil
        }

        switch (settingsName, keychainName) {
        case let (settingsName?, keychainName?):
            guard settingsName == keychainName else {
                throw WalletIntegrityError
                    .legacyWalletUpgradeVerificationFailed
            }
            return settingsName
        case let (settingsName?, nil):
            return settingsName
        case let (nil, keychainName?):
            return keychainName
        case (nil, nil):
            return ""
        }
    }
}

/// Activates the account model for an unsuffixed legacy entropy record without
/// copying, normalizing, or replacing any secret. The normal importer remains
/// responsible only for in-memory derivation and identity verification.
enum LegacyWalletUpgradeSecretRetention {
    static func consumeWithoutPersisting(
        _ prepared: PreparedAccount,
        keystore: KeystoreProtocol,
        settings: SettingsManagerProtocol,
        expectedEntropyDigest: Data,
        expectedDisplayName: String,
        recoveryGate: WalletRecoveryCapabilityGate = .shared
    ) throws {
        try recoveryGate
            .requireAuthorizedLifecycleContinuation()
        let account = prepared.account
        guard
            account.username == expectedDisplayName,
            try LegacyWalletUpgradeDisplayNameResolver.resolve(
                settings: settings,
                keystore: keystore
            ) == expectedDisplayName
        else {
            throw WalletIntegrityError
                .legacyWalletUpgradeVerificationFailed
        }
        let scopedTags = [
            KeystoreTag.secretKeyTagForAddress(account.address),
            KeystoreTag.entropyTagForAddress(account.address),
            KeystoreTag.deriviationTagForAddress(account.address),
            KeystoreTag.seedTagForAddress(account.address),
        ]
        let identifiers = Set(try keystore.allKeyIdentifiers())
        guard
            scopedTags.allSatisfy({ !identifiers.contains($0) })
        else {
            throw WalletIntegrityError
                .legacyWalletUpgradeVerificationFailed
        }

        var retainedEntropy = try keystore.fetchKey(
            for: KeystoreTag.legacyEntropy.rawValue
        )
        defer {
            retainedEntropy.resetBytes(
                in: retainedEntropy.startIndex ..< retainedEntropy.endIndex
            )
        }
        let mnemonic = try IRMnemonicCreator(language: .english)
            .mnemonic(fromEntropy: retainedEntropy)
        try keystore.verifyLegacyIrohaKeyIfPresent(entropy: retainedEntropy)
        guard
            !retainedEntropy.isEmpty,
            Data(SHA256.hash(data: retainedEntropy)) ==
                expectedEntropyDigest,
            WalletMnemonicWordPolicy.retainedSoraWordCounts
                .contains(mnemonic.allWords().count)
        else {
            throw WalletIntegrityError
                .legacyWalletUpgradeVerificationFailed
        }
        try LegacySoraIdentityValidator.validate(
            address: account.address,
            publicKey: account.publicKeyData,
            cryptoType: account.cryptoType,
            networkType: account.networkType,
            derivationPath: nil,
            entropy: retainedEntropy,
            rawSeed: nil,
            secret: nil,
            recoveryGate: recoveryGate
        )

        // Wipe the normal importer's derived copies instead of persisting them.
        prepared.discard()

        var verifiedRetainedEntropy = try keystore.fetchKey(
            for: KeystoreTag.legacyEntropy.rawValue
        )
        defer {
            verifiedRetainedEntropy.resetBytes(
                in: verifiedRetainedEntropy.startIndex ..<
                    verifiedRetainedEntropy.endIndex
            )
        }
        let postIdentifiers = Set(try keystore.allKeyIdentifiers())
        try keystore.verifyLegacyIrohaKeyIfPresent(entropy: verifiedRetainedEntropy)
        guard
            Data(SHA256.hash(data: verifiedRetainedEntropy)) ==
                expectedEntropyDigest,
            try LegacyWalletUpgradeDisplayNameResolver.resolve(
                settings: settings,
                keystore: keystore
            ) == expectedDisplayName,
            postIdentifiers.contains("privateKey") == identifiers.contains("privateKey"),
            scopedTags.allSatisfy({ !postIdentifiers.contains($0) })
        else {
            throw WalletIntegrityError
                .legacyWalletUpgradeVerificationFailed
        }
    }
}

final class RootInteractor {
    weak var presenter: RootInteractorOutputProtocol?

    var settings: SettingsManagerProtocol
    var keystore: KeystoreProtocol
    let migrators: [Migrating]
    var securityLayerInteractor: SecurityLayerInteractorInputProtocol
    var networkAvailabilityLayerInteractor: NetworkAvailabilityLayerInteractorInputProtocol?
    private let legacyUpgradeLock = NSLock()
    private var didStartLegacyWalletUpgrade = false
    private let legacyUpgradeSelectedAccount: () -> AccountItem?
    private let legacyUpgradeSnapshotLoader:
        () throws -> WalletNetworkSnapshot?
    private let legacyUpgradeUnresolvedCommitLoader:
        () throws -> [WalletAccountCommitJournal]
    private let legacyUpgradeInteractorFactory:
        (
            KeystoreProtocol,
            SettingsManagerProtocol,
            Data,
            String
        ) -> AccountImportInteractorInputProtocol?

    init(settings: SettingsManagerProtocol,
         keystore: KeystoreProtocol,
         migrators: [Migrating],
         securityLayerInteractor: SecurityLayerInteractorInputProtocol,
         networkAvailabilityLayerInteractor: NetworkAvailabilityLayerInteractorInputProtocol?,
         legacyUpgradeSelectedAccount:
             @escaping () -> AccountItem? = {
                 SelectedWalletSettings.shared.currentAccount
             },
         legacyUpgradeSnapshotLoader:
             @escaping () throws -> WalletNetworkSnapshot? = {
                 try WalletNetworkStore().load()
             },
         legacyUpgradeUnresolvedCommitLoader:
             @escaping () throws -> [WalletAccountCommitJournal] = {
                 try WalletAccountCommitJournalStore().unresolved()
             },
         legacyUpgradeInteractorFactory:
             @escaping (
                 KeystoreProtocol,
                 SettingsManagerProtocol,
                 Data,
                 String
             ) -> AccountImportInteractorInputProtocol? = {
                 keystore,
                 settings,
                 expectedEntropyDigest,
                 expectedDisplayName in
                 AccountImportViewFactory.createLegacyUpgradeInteractor(
                     keystore: keystore,
                     settings: settings,
                     expectedEntropyDigest: expectedEntropyDigest,
                     expectedDisplayName: expectedDisplayName
                 )
             }) {
        self.settings = settings
        self.keystore = keystore
        self.migrators = migrators
        self.securityLayerInteractor = securityLayerInteractor
        self.networkAvailabilityLayerInteractor = networkAvailabilityLayerInteractor
        self.legacyUpgradeSelectedAccount =
            legacyUpgradeSelectedAccount
        self.legacyUpgradeSnapshotLoader =
            legacyUpgradeSnapshotLoader
        self.legacyUpgradeUnresolvedCommitLoader =
            legacyUpgradeUnresolvedCommitLoader
        self.legacyUpgradeInteractorFactory =
            legacyUpgradeInteractorFactory
    }

    private func configureSecurityService() {
        securityLayerInteractor.setup()
    }

    private func configureDeepLinkService() {
        let invitationLinkService = InvitationLinkService(settings: settings)
        DeepLinkService.shared.setup(children: [invitationLinkService])
    }

    private func configureNetworkAvailabilityService() {
        networkAvailabilityLayerInteractor?.setup()
    }

    private func setupURLHandlingService() {
        let keystoreImportService = KeystoreImportService(logger: Logger.shared)

//        let callbackUrl = applicationConfig.purchaseRedirect
//        let purchaseHandler = PurchaseCompletionHandler(callbackUrl: callbackUrl,
//                                                        eventCenter: eventCenter)

        URLHandlingService.shared.setup(children: [/*purchaseHandler,*/ keystoreImportService])
    }

    var legacyImportInteractor: AccountImportInteractorInputProtocol?

    private func isLegacyWalletUpgradeCandidate(
        snapshot: WalletNetworkSnapshot?
    ) throws -> Bool {
        try LegacyWalletUpgradePolicy.isCandidate(
            keystore: keystore,
            hasWatchOnlyWallet:
                settings.hasRetainedWatchOnlyWallet(),
            snapshot: snapshot
        )
    }

    private func failLegacyWalletUpgrade(_ error: Error) {
        settings.walletMigrationRecoveryRequired = true
        settings.walletMigrationRecoveryReason =
            UserStorageMigrationError
                .privacySafeRecoveryDescription(for: error)
        legacyImportInteractor = nil
        presenter?.didDecideBroken()
    }

    private func verifyLegacyWalletUpgrade(
        account: AccountItem,
        expectedEntropyDigest: Data,
        expectedDisplayName: String
    ) throws {
        let scopedTags = [
            KeystoreTag.secretKeyTagForAddress(account.address),
            KeystoreTag.entropyTagForAddress(account.address),
            KeystoreTag.deriviationTagForAddress(account.address),
            KeystoreTag.seedTagForAddress(account.address),
        ]
        let identifiers = Set(try keystore.allKeyIdentifiers())
        var retainedEntropy = try keystore.fetchKey(
            for: KeystoreTag.legacyEntropy.rawValue
        )
        defer {
            retainedEntropy.resetBytes(
                in: retainedEntropy.startIndex ..<
                retainedEntropy.endIndex
            )
        }
        let mnemonic = try IRMnemonicCreator(language: .english)
            .mnemonic(fromEntropy: retainedEntropy)
        try keystore.verifyLegacyIrohaKeyIfPresent(entropy: retainedEntropy)
        let wordCount = mnemonic.allWords().count
        guard
            let expectedSource = WalletMnemonicWordPolicy
                .retainedSecretSource(forWordCount: wordCount)
        else {
            throw WalletIntegrityError
                .legacyWalletUpgradeVerificationFailed
        }
        let expectedNetworks: Set<NetworkId> =
            expectedSource == .legacyMnemonicEntropy
                ? [.sora2]
                : NexusNetworkConfiguration.admittedWalletNetworkIds
        guard
            !retainedEntropy.isEmpty,
            Data(SHA256.hash(data: retainedEntropy)) ==
                expectedEntropyDigest,
            scopedTags.allSatisfy({ !identifiers.contains($0) }),
            let snapshot = try legacyUpgradeSnapshotLoader(),
            snapshot.wallets.count == 1,
            snapshot.selectedWalletId == account.address,
            snapshot.wallets.first?.id == account.address,
            snapshot.wallets.first?.existingSoraAddress ==
                account.address,
            account.username == expectedDisplayName,
            snapshot.wallets.first?.displayName == expectedDisplayName,
            snapshot.wallets.first?.secretSource == expectedSource,
            snapshot.accounts.filter({
                $0.walletId == account.address &&
                    $0.networkId == .sora2 &&
                    $0.address == account.address &&
                    $0.publicKey == account.publicKeyData
            }).count == 1,
            snapshot.accounts.allSatisfy({
                $0.walletId == account.address
            }),
            snapshot.accounts.count == expectedNetworks.count,
            Set(snapshot.accounts.map(\.networkId)) == expectedNetworks,
            try legacyUpgradeUnresolvedCommitLoader().isEmpty
        else {
            throw WalletIntegrityError
                .legacyWalletUpgradeVerificationFailed
        }
    }
}

extension RootInteractor: RootInteractorInputProtocol {
    func decideModuleSynchroniously() {
        do {
            if settings.walletMigrationRecoveryRequired {
                presenter?.didDecideBroken()
                return
            }

            let pincodeExists = try keystore.checkKey(
                for: KeystoreTag.pincode.rawValue
            )
            if legacyUpgradeSelectedAccount() == nil {
                let hasWatchOnlyWallet =
                    settings.hasRetainedWatchOnlyWallet()
                let networkSnapshot = try legacyUpgradeSnapshotLoader()
                let hasInventoriedWallets =
                    networkSnapshot?.wallets.isEmpty == false
                let hasRetainedWalletSettings =
                    settings.hasRetainedWalletSettings()
                if try isLegacyWalletUpgradeCandidate(
                    snapshot: networkSnapshot
                ) {
                    presenter?.didDecideLegacyWalletUpgrade()
                    return
                }
                let hasProtectedWalletMaterial =
                    try keystore.hasRetainedWalletMaterial()

                if hasProtectedWalletMaterial ||
                    hasRetainedWalletSettings ||
                    hasWatchOnlyWallet ||
                    hasInventoriedWallets ||
                    pincodeExists {
                    let error = WalletIntegrityError.selectedAccountMissing
                    settings.walletMigrationRecoveryRequired = true
                    settings.walletMigrationRecoveryReason =
                        UserStorageMigrationError
                            .privacySafeRecoveryDescription(for: error)
                    presenter?.didDecideBroken()
                    return
                }

                presenter?.didDecideOnboarding()
                return
            }

            // Keep the legacy entropy record during this migration release.
            // The wallet model remains dual-readable for rollback/recovery and
            // a successful import is not permission to delete its source.

            if pincodeExists {
                presenter?.didDecideLocalAuthentication()
            } else {
                presenter?.didDecidePincodeSetup()
            }

        } catch {
            settings.walletMigrationRecoveryRequired = true
            settings.walletMigrationRecoveryReason =
                UserStorageMigrationError
                    .privacySafeRecoveryDescription(for: error)
            presenter?.didDecideBroken()
        }
    }

    func performLegacyWalletUpgrade() {
        legacyUpgradeLock.lock()
        guard !didStartLegacyWalletUpgrade else {
            legacyUpgradeLock.unlock()
            return
        }
        didStartLegacyWalletUpgrade = true
        legacyUpgradeLock.unlock()

        do {
            guard
                !settings.walletMigrationRecoveryRequired,
                legacyUpgradeSelectedAccount() == nil,
                try isLegacyWalletUpgradeCandidate(
                    snapshot: legacyUpgradeSnapshotLoader()
                )
            else {
                throw WalletIntegrityError
                    .legacyWalletUpgradeVerificationFailed
            }

            var legacyEntropy = try keystore.fetchKey(
                for: KeystoreTag.legacyEntropy.rawValue
            )
            defer {
                legacyEntropy.resetBytes(
                    in: legacyEntropy.startIndex ..<
                        legacyEntropy.endIndex
                )
            }
            guard !legacyEntropy.isEmpty else {
                throw WalletIntegrityError
                    .legacyWalletUpgradeVerificationFailed
            }
            let expectedEntropyDigest = Data(
                SHA256.hash(data: legacyEntropy)
            )
            let mnemonic = try IRMnemonicCreator(
                language: .english
            ).mnemonic(fromEntropy: legacyEntropy)
            var phrase = mnemonic.toString()
            defer {
                phrase.removeAll(keepingCapacity: false)
            }
            let username = try LegacyWalletUpgradeDisplayNameResolver
                .resolve(
                    settings: settings,
                    keystore: keystore
                )
            guard
                WalletMnemonicWordPolicy.retainedSoraWordCounts
                    .contains(mnemonic.allWords().count),
                let importInteractor = legacyUpgradeInteractorFactory(
                    keystore,
                    settings,
                    expectedEntropyDigest,
                    username
                )
            else {
                throw WalletIntegrityError
                    .legacyWalletUpgradeVerificationFailed
            }

            let request = AccountImportMnemonicRequest(
                mnemonic: phrase,
                username: username,
                networkType: .sora,
                derivationPath: "",
                cryptoType: .sr25519
            )
            legacyImportInteractor = importInteractor
            importInteractor.importAccountWithMnemonic(
                request: request
            ) { [weak self] result in
                guard let self else {
                    return
                }
                switch result {
                case let .success(account):
                    do {
                        try self.verifyLegacyWalletUpgrade(
                            account: account,
                            expectedEntropyDigest:
                                expectedEntropyDigest,
                            expectedDisplayName: username
                        )
                        self.legacyImportInteractor = nil
                        self.decideModuleSynchroniously()
                    } catch {
                        self.failLegacyWalletUpgrade(error)
                    }
                case let .failure(error):
                    self.failLegacyWalletUpgrade(error)
                case .none:
                    self.failLegacyWalletUpgrade(
                        WalletIntegrityError
                            .legacyWalletUpgradeVerificationFailed
                    )
                }
            }
        } catch {
            failLegacyWalletUpgrade(error)
        }
    }

    private func runMigrators() {
        migrators.forEach { migrator in
            do {
                try migrator.migrate()
            } catch {
                let outcome = UserStorageMigrationError
                    .privacySafeOutcomeCode(for: error)
                Logger.shared.error(
                    "Wallet migrator outcome: \(outcome)"
                )
            }
        }
    }

    func setup() {
        setupURLHandlingService()
        configureSecurityService()
        configureNetworkAvailabilityService()
        configureDeepLinkService()
        runMigrators()

    }
}
