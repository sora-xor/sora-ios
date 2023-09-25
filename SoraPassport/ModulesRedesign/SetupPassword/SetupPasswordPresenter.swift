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
            cloudStorageService.saveBackupAccount(account: backupAccount, password: password) { [weak self] result in
                self?.view?.hideLoading()
                self?.handler(result)
            }
            return
        }
        
        if let createAccountRequest = createAccountRequest, let mnemonic = mnemonic {
            self.view?.showLoading()
            createAccountService?.createAccount(request: createAccountRequest, mnemonic: mnemonic) { [weak self] result in
                guard let self = self, let result = result, case .success(let account) = result else { return }
    
                self.updateBackupedAccount(with: account, password: password)
                
                self.cloudStorageService.saveBackupAccount(account: self.backupAccount, password: password) { [weak self] result in
                    self?.view?.hideLoading()
                    self?.handler(result)
                }
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

        var rawSeed = getRawSeed(from: account)
        if rawSeed != nil {
            backupAccountType.append(.seed)
        }

        _ = try? keystore.fetchSecretKeyForAddress(account.address)
        
        var substrateJson = getJson(from: account, password: password)
        if substrateJson != nil {
            backupAccountType.append(.json)
        }

        backupAccount.address = account.address
        backupAccount.backupAccountType = backupAccountType
        backupAccount.encryptedSeed = OpenBackupAccount.Seed(substrateSeed: rawSeed)
        backupAccount.json = OpenBackupAccount.Json(substrateJson: substrateJson)
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
