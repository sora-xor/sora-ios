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

    init(account: OpenBackupAccount,
         cloudStorageService: CloudStorageServiceProtocol,
         createAccountRequest: AccountCreationRequest? = nil,
         createAccountService: CreateAccountServiceProtocol? = nil,
         mnemonic: IRMnemonicProtocol? = nil,
         entryPoint: EntryPoint,
         keystore: KeystoreProtocol,
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
                let account: AccountItem
                if self.entryPoint == .profile {
                    guard let current = self.currentAccount() else {
                        throw WalletCloudBackupWriteError.invalidBackup
                    }
                    guard current.address == self.backupAccount.address else {
                        throw WalletCloudBackupWriteError.invalidBackup
                    }
                    account = current
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
                    self.backupAccount = try self.prepareBackup(with: account, password: password)
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
            } catch {
                self.wireframe?.present(message: WalletCloudBackupWriteError.userMessage(for: error),
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
    
    private func prepareBackup(with account: AccountItem, password: String) throws -> OpenBackupAccount {
        try recoveryGate.requireAuthorizedLifecycleContinuation()
        guard backupAccount.address == account.address || (entryPoint == .onboarding && backupAccount.address.isEmpty) else {
            throw WalletCloudBackupWriteError.invalidBackup
        }
        if let crypto = backupAccount.cryptoType, !crypto.isEmpty {
            guard crypto.lowercased() == account.cryptoType.typeString.lowercased() ||
                crypto == String(account.cryptoType.rawValue) else { throw WalletCloudBackupWriteError.invalidBackup }
        }
        let path = try keystore.fetchDeriviationForAddress(account.address) ?? ""
        if let suppliedPath = backupAccount.substrateDerivationPath, !suppliedPath.isEmpty, suppliedPath != path {
            throw WalletCloudBackupWriteError.invalidBackup
        }
        var entropy = try keystore.fetchEntropyForAddress(account.address)
        var rawSeed = try keystore.fetchSeedForAddress(account.address)
        var secret = try keystore.fetchSecretKeyForAddress(account.address)
        defer {
            let entropyCount = entropy?.count ?? 0, seedCount = rawSeed?.count ?? 0, secretCount = secret?.count ?? 0
            entropy?.resetBytes(in: 0..<entropyCount)
            rawSeed?.resetBytes(in: 0..<seedCount)
            secret?.resetBytes(in: 0..<secretCount)
        }
        if let suppliedPhrase = backupAccount.passphrase,
           !suppliedPhrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let mnemonic = try IRMnemonicCreator(language: .english).mnemonic(
                fromList: suppliedPhrase.split(whereSeparator: \.isWhitespace).joined(separator: " "))
            let suppliedEntropy = mnemonic.entropy()
            guard entropy == nil || entropy == suppliedEntropy else { throw WalletCloudBackupWriteError.invalidBackup }
            entropy = suppliedEntropy
        }
        if let rawSeed, rawSeed.count != 32 && rawSeed.count != 64 { throw WalletCloudBackupWriteError.invalidBackup }
        if let secret { try WalletCloudBackupRecoveryService.validateSecretEncoding(secret, cryptoType: account.cryptoType) }
        guard entropy != nil || rawSeed != nil || secret != nil else { throw WalletCloudBackupWriteError.invalidBackup }
        try LegacySoraIdentityValidator.validate(address: account.address,
            publicKey: account.publicKeyData, cryptoType: account.cryptoType, networkType: account.networkType,
            derivationPath: path.isEmpty ? nil : path, entropy: entropy, rawSeed: rawSeed, secret: secret,
            recoveryGate: recoveryGate)
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
