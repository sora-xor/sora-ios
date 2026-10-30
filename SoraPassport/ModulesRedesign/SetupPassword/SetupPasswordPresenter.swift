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

import SoraFoundation
import SoraUIKit
import SSFCloudStorage
import IrohaCrypto
import SoraKeystore

enum EntryPoint {
    case onboarding
    case profile
}

final class SetupPasswordPresenter: SetupPasswordPresenterProtocol {
    @Published var title: String = R.string.localizable.createBackupPasswordTitle(preferredLanguages: .currentLocale)
    var titlePublisher: Published<String>.Publisher { $title }
    
    @Published var snapshot: SetupPasswordSnapshot = SetupPasswordSnapshot()
    var snapshotPublisher: Published<SetupPasswordSnapshot>.Publisher { $snapshot }
    
    weak var view: SetupPasswordViewProtocol?
    var wireframe: SetupPasswordWireframeProtocol?
    private var completion: (() -> Void)? = nil
    private var backupAccount: OpenBackupAccount
    private let cloudStorageService: CloudStorageServiceProtocol
    private var createAccountRequest: AccountCreationRequest?
    private var createAccountService: CreateAccountServiceProtocol?
    private var mnemonic: IRMnemonicProtocol?
    private let entryPoint: EntryPoint
    private let keystore: KeystoreProtocol
    private let currentAccount: () -> AccountItem?
    private var isSavingBackup = false
    private var createdAccountForBackup: AccountItem?
    private let lifecycleCoordinator: WalletLifecycleCoordinator
    private let recoveryGate: WalletRecoveryCapabilityGate
    /// For an existing wallet (`.profile`): the Account Options authorization
    /// its secret is read under, and how to ask the owner again once that
    /// lapsed or was used.
    private var cloudBackupAuthorization: AccountOptionsCloudBackupAuthorization?
    private let reauthorizeCloudBackup: AccountOptionsCloudBackupReauthorization?

    init(account: OpenBackupAccount,
         cloudStorageService: CloudStorageServiceProtocol,
         createAccountRequest: AccountCreationRequest? = nil,
         createAccountService: CreateAccountServiceProtocol? = nil,
         mnemonic: IRMnemonicProtocol? = nil,
         entryPoint: EntryPoint,
         keystore: KeystoreProtocol,
         cloudBackupAuthorization: AccountOptionsCloudBackupAuthorization? = nil,
         reauthorizeCloudBackup: AccountOptionsCloudBackupReauthorization? = nil,
         completion: (() -> Void)? = nil,
         currentAccount: @escaping () -> AccountItem? = { SelectedWalletSettings.shared.currentAccount },
         lifecycleCoordinator: WalletLifecycleCoordinator = .shared,
         recoveryGate: WalletRecoveryCapabilityGate = .shared) {
        self.backupAccount = account
        self.completion = completion
        self.createAccountRequest = createAccountRequest
        self.createAccountService = createAccountService
        self.mnemonic = mnemonic
        self.entryPoint = entryPoint
        self.keystore = keystore
        self.cloudBackupAuthorization = cloudBackupAuthorization
        self.reauthorizeCloudBackup = reauthorizeCloudBackup
        self.cloudStorageService = cloudStorageService
        self.currentAccount = currentAccount
        self.lifecycleCoordinator = lifecycleCoordinator
        self.recoveryGate = recoveryGate
    }
    
    deinit {
        print("deinited")
    }
    
    func reload() {
        title = R.string.localizable.createBackupPasswordTitle(preferredLanguages: languages)
        snapshot = createSnapshot()
    }
    
    func backupAccount(with password: String) {
        Task { @MainActor [weak self] in
            guard let self, !self.isSavingBackup else { return }
            self.isSavingBackup = true
            self.view?.showLoading()
            defer {
                self.isSavingBackup = false
                self.view?.hideLoading()
            }
            do {
                // A leaked Drive backup can be guessed offline, so refuse a
                // weak password before any wallet is created or encrypted,
                // whatever the screen allowed.
                try BackupPasswordPolicy.validate(password)
                let account: AccountItem
                var authorization: AccountOptionsCloudBackupAuthorization?
                if self.entryPoint == .profile {
                    guard let current = self.currentAccount() else {
                        throw WalletCloudBackupWriteError.invalidBackup
                    }
                    guard current.address == self.backupAccount.address else {
                        throw WalletCloudBackupWriteError.invalidBackup
                    }
                    account = current
                    // Asked for, if needed, before the wallet lease is held.
                    authorization = try await self.authorizationForSecretRead(of: current)
                } else if let created = self.createdAccountForBackup {
                    account = created
                } else {
                    guard let request = self.createAccountRequest, let mnemonic = self.mnemonic,
                          let creator = self.createAccountService else {
                        throw WalletCloudBackupWriteError.invalidBackup
                    }
                    let result: Result<AccountItem, Error>? = await withCheckedContinuation { continuation in
                        creator.createAccount(request: request, mnemonic: mnemonic) { result in
                            continuation.resume(returning: result)
                        }
                    }
                    guard let result else { throw WalletCloudBackupWriteError.invalidBackup }
                    account = try result.get()
                    self.createdAccountForBackup = account
                }
                let lease = try await self.lifecycleCoordinator.acquireForMutableWalletAccessAsync()
                do {
                    self.backupAccount = try self.prepareBackup(with: account, password: password,
                                                                authorization: authorization)
                    lease.release()
                } catch {
                    lease.release()
                    throw error
                }
                // The production service returns only after preserving the previous
                // revision and reading back the exact newly encoded payload.
                try await self.cloudStorageService.saveBackup(account: self.backupAccount, password: password)
                var addresses = ApplicationConfig.shared.backupedAccountAddresses
                if !addresses.contains(self.backupAccount.address) { addresses.append(self.backupAccount.address) }
                ApplicationConfig.shared.backupedAccountAddresses = addresses
                if let completion = self.completion {
                    self.view?.controller.dismiss(animated: true, completion: completion)
                } else {
                    self.wireframe?.showSetupPinCode()
                }
            } catch AccountOptionsCloudBackupError.authorizationRequired {
                // The owner refused the PIN, or the authorization lapsed again
                // before the read. Nothing was read or saved, and saving again
                // asks once more.
            } catch {
                let message = (error as? BackupPasswordPolicy.Violation).map {
                    BackupPasswordPolicy.guidance(for: $0, preferredLanguages: .currentLocale)
                } ?? WalletCloudBackupWriteError.userMessage(for: error)
                self.wireframe?.present(message: message,
                    title: "Backup not saved",
                    closeAction: R.string.localizable.commonOk(preferredLanguages: .currentLocale),
                    from: self.view)
            }
        }
    }

    private func createSnapshot() -> SetupPasswordSnapshot {
        var snapshot = SetupPasswordSnapshot()
        
        let sections = [ contentSection() ]
        snapshot.appendSections(sections)
        sections.forEach { snapshot.appendItems($0.items, toSection: $0) }
        
        return snapshot
    }

    private func contentSection() -> SetupPasswordSection {
        let item = SetupPasswordItem()
        item.setupPasswordButtonTapped = { [weak self] password in
            self?.backupAccount(with: password)
        }
        return SetupPasswordSection(items: [ .setupPassword(item) ])
    }
    
    /// The authorization for one read of `account`'s wallet secret: the one
    /// Account Options handed over while it holds, otherwise one the owner
    /// gives now. Throws `AccountOptionsCloudBackupError.authorizationRequired`
    /// when the owner refuses or nothing can ask.
    @MainActor
    private func authorizationForSecretRead(of account: AccountItem) async throws -> AccountOptionsCloudBackupAuthorization {
        if let authorization = cloudBackupAuthorization, (try? authorization.require(for: account.address)) != nil {
            return authorization
        }
        cloudBackupAuthorization = nil
        guard let reauthorize = reauthorizeCloudBackup else {
            throw AccountOptionsCloudBackupError.authorizationRequired
        }
        let renewed = await withCheckedContinuation { continuation in
            reauthorize { continuation.resume(returning: $0) }
        }
        guard let renewed else {
            throw AccountOptionsCloudBackupError.authorizationRequired
        }
        cloudBackupAuthorization = renewed
        return renewed
    }

    private func prepareBackup(with account: AccountItem, password: String,
                               authorization: AccountOptionsCloudBackupAuthorization?) throws -> OpenBackupAccount {
        try recoveryGate.requireAuthorizedLifecycleContinuation()
        guard backupAccount.address == account.address || (entryPoint == .onboarding && backupAccount.address.isEmpty) else {
            throw WalletCloudBackupWriteError.invalidBackup
        }
        if let crypto = backupAccount.cryptoType, !crypto.isEmpty {
            guard crypto.lowercased() == account.cryptoType.typeString.lowercased() ||
                crypto == String(account.cryptoType.rawValue) else { throw WalletCloudBackupWriteError.invalidBackup }
        }
        // An existing wallet's secret is read only while the owner's
        // authorization holds, and each read uses one up. The onboarding
        // wallet was created in this flow and needs none.
        if entryPoint == .profile {
            guard let authorization else { throw AccountOptionsCloudBackupError.authorizationRequired }
            try authorization.redeem(for: account.address)
        }
        var backup = try WalletBackupMaterial.load(for: account, keystore: keystore, recoveryGate: recoveryGate)
        defer { backup.wipe() }
        let path = backup.derivationStatus == .matching ? (backup.derivationPath ?? "") : ""
        let entropy = backup.entropy
        let rawSeed = backup.seed
        var prepared = backupAccount
        prepared.address = account.address
        prepared.cryptoType = account.cryptoType.typeString
        prepared.substrateDerivationPath = path
        prepared.passphrase = try entropy.map { try IRMnemonicCreator(language: .english).mnemonic(fromEntropy: $0).toString() }
        prepared.encryptedSeed = OpenBackupAccount.Seed(substrateSeed: rawSeed?.toHex(includePrefix: true),
            ethSeed: backupAccount.encryptedSeed?.ethSeed)
        let exported = try KeystoreExportWrapper(keystore: keystore).export(account: account, password: password)
        guard let json = String(data: exported, encoding: .utf8) else { throw WalletCloudBackupWriteError.invalidBackup }
        prepared.json = OpenBackupAccount.Json(substrateJson: json, ethJson: backupAccount.json?.ethJson)
        var formats: [OpenBackupAccount.BackupAccountType] = [.json]
        if prepared.passphrase != nil { formats.append(.passphrase) }
        if rawSeed != nil { formats.append(.seed) }
        prepared.backupAccountType = formats
        try recoveryGate.requireAuthorizedLifecycleContinuation()
        return prepared
    }

}

extension SetupPasswordPresenter: Localizable {
    private var languages: [String]? {
        LocalizationManager.shared.preferredLocalizations
    }

    func applyLocalization() {
        reload()
    }
}
