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

    init(account: OpenBackupAccount,
         cloudStorageService: CloudStorageServiceProtocol,
         createAccountRequest: AccountCreationRequest? = nil,
         createAccountService: CreateAccountServiceProtocol? = nil,
         mnemonic: IRMnemonicProtocol? = nil,
         entryPoint: EntryPoint,
         keystore: KeystoreProtocol,
         completion: (() -> Void)? = nil) {
        self.backupAccount = account
        self.completion = completion
        self.createAccountRequest = createAccountRequest
        self.createAccountService = createAccountService
        self.mnemonic = mnemonic
        self.entryPoint = entryPoint
        self.keystore = keystore
        self.cloudStorageService = cloudStorageService
    }
    
    deinit {
        print("deinited")
    }
    
    func reload() {
        title = R.string.localizable.createBackupPasswordTitle(preferredLanguages: languages)
        snapshot = createSnapshot()
    }
    
    func backupAccount(with password: String) {
        if entryPoint == .profile {
            guard let account = SelectedWalletSettings.shared.currentAccount else { return }
    
            updateBackupedAccount(with: account, password: password)
            
            view?.showLoading()
            updateCloudStorage(with: password)
            return
        }
        
        if let createAccountRequest = createAccountRequest, let mnemonic = mnemonic {
            self.view?.showLoading()
            createAccountService?.createAccount(request: createAccountRequest, mnemonic: mnemonic) { [weak self] result in
                guard let self = self, let result = result, case .success(let account) = result else { return }
    
                self.updateBackupedAccount(with: account, password: password)
                self.updateCloudStorage(with: password)
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
    
    private func handler(_ result: Result<Void, Error>) {
        switch result {
        case .success:
            var backupedAccountAddresses = ApplicationConfig.shared.backupedAccountAddresses
            backupedAccountAddresses.append(backupAccount.address)
            ApplicationConfig.shared.backupedAccountAddresses = backupedAccountAddresses
            
            if completion != nil {
                view?.controller.dismiss(animated: true, completion: completion)
            } else {
                wireframe?.showSetupPinCode()
            }
        case .failure(let error):
            wireframe?.present(message: nil,
                               title: error.localizedDescription,
                               closeAction: R.string.localizable.commonOk(preferredLanguages: .currentLocale),
                               from: view)
        }
    }
    
    private func updateBackupedAccount(with account: AccountItem, password: String) {
        var backupAccountType: [OpenBackupAccount.BackupAccountType] = []
        
        if mnemonic != nil {
            backupAccountType.append(.passphrase)
        }

        let rawSeed = getRawSeed(from: account)
        if rawSeed != nil {
            backupAccountType.append(.seed)
        }

        _ = try? keystore.fetchSecretKeyForAddress(account.address)
        
        let substrateJson = getJson(from: account, password: password)
        if substrateJson != nil {
            backupAccountType.append(.json)
        }

        backupAccount.address = account.address
        backupAccount.backupAccountType = backupAccountType
        backupAccount.encryptedSeed = OpenBackupAccount.Seed(substrateSeed: rawSeed)
        backupAccount.json = OpenBackupAccount.Json(substrateJson: substrateJson)
    }
    
    private func updateCloudStorage(with password: String) {
        Task { [weak self] in
            guard let self = self else { return }
            
            do {
                let accounts = try await self.cloudStorageService.getBackupAccounts()
                if let foudedAccount = accounts.first(where: { self.backupAccount.address == $0.address }) {
                    try await self.cloudStorageService.deleteBackup(account: foudedAccount)
                    
                    let backupedAddresses = ApplicationConfig.shared.backupedAccountAddresses
                    ApplicationConfig.shared.backupedAccountAddresses = backupedAddresses.filter { $0 != foudedAccount.address }
                    
                    try await self.cloudStorageService.saveBackup(account: self.backupAccount, password: password)
                    
                    self.view?.hideLoading()
                    
                    var backupedAccountAddresses = ApplicationConfig.shared.backupedAccountAddresses
                    backupedAccountAddresses.append(backupAccount.address)
                    ApplicationConfig.shared.backupedAccountAddresses = backupedAccountAddresses
                    
                    if completion != nil {
                        await view?.controller.dismiss(animated: true, completion: completion)
                    } else {
                        wireframe?.showSetupPinCode()
                    }
                }
            } catch {
                try? await self.cloudStorageService.saveBackup(account: self.backupAccount, password: password)
                self.view?.hideLoading()
                self.wireframe?.present(message: nil,
                                        title: error.localizedDescription,
                                        closeAction: R.string.localizable.commonOk(preferredLanguages: .currentLocale),
                                        from: view)
            }
        }
    }
    
    private func getRawSeed(from account: AccountItem) -> String? {
        return try? keystore.fetchSeedForAddress(account.address)?.toHex(includePrefix: true)
    }
    
    private func getJson(from account: AccountItem, password: String) -> String? {
        guard let exportData = try? KeystoreExportWrapper(keystore: keystore).export(account: account, password: password) else { return nil }
        return String(data: exportData, encoding: .utf8)
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
