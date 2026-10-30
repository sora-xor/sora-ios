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
import RobinHood

final class EnterPasswordViewModel {
    @Published var title: String = R.string.localizable.enterBackupPasswordTitle(preferredLanguages: .currentLocale)
    var titlePublisher: Published<String>.Publisher { $title }
    
    @Published var snapshot: EnterPasswordSnapshot = EnterPasswordSnapshot()
    var snapshotPublisher: Published<EnterPasswordSnapshot>.Publisher { $snapshot }
    
    private var wireframe: EnterPasswordWireframeProtocol?
    private var interactor: AccountImportInteractorInputProtocol
    private var errorText = ""
    private var isImporting = false
    /// This import is restoring a 3-, 6- or 9-word phrase; success shows the warning first.
    private var restoredShortPhrase = false
    private let selectedAccount: OpenBackupAccount?
    private var backedUpAccounts: [OpenBackupAccount]
    private weak var view: EnterPasswordViewProtocol?

    init(selectedAddress: String,
         backedUpAccounts: [OpenBackupAccount],
         interactor: AccountImportInteractorInputProtocol,
         wireframe: EnterPasswordWireframeProtocol,
         view: EnterPasswordViewProtocol?) {
        self.selectedAccount = backedUpAccounts.first(where: { $0.address == selectedAddress })
        self.interactor = interactor
        self.backedUpAccounts = backedUpAccounts
        self.wireframe = wireframe
        self.view = view
    }
    
    deinit {
        print("deinited")
    }

    private func createSnapshot() -> EnterPasswordSnapshot {
        var snapshot = EnterPasswordSnapshot()
        
        let sections = [ contentSection() ]
        snapshot.appendSections(sections)
        sections.forEach { snapshot.appendItems($0.items, toSection: $0) }
        
        return snapshot
    }

    private func contentSection() -> EnterPasswordSection {
        let item = EnterPasswordItem(accountName: selectedAccount?.name ?? "",
                                     accountAddress: selectedAccount?.address ?? "",
                                     errorText: errorText,
                                     continueButtonHandler: { [weak self] password in self?.checkPassword(password: password) })
        return EnterPasswordSection(items: [ .enterPassword(item) ])
    }
    
    private func checkPassword(password: String) {
        guard !isImporting, let selectedAccount else { return }
        isImporting = true
        restoredShortPhrase = false
        errorText = ""
        reload()
        view?.showLoading()
        let request = AccountImportBackedupRequest(account: selectedAccount, password: password)
        interactor.importBackedupAccount(request: request)
    }
}

extension EnterPasswordViewModel: EnterPasswordViewModelProtocol {
    func reload() {        
        title = R.string.localizable.enterBackupPasswordTitle(preferredLanguages: languages)
        snapshot = createSnapshot()
    }
}

extension EnterPasswordViewModel: AccountImportInteractorOutputProtocol {
    func didCompleteAccountImport() {
        guard isImporting, let selectedAccount else { return }
        isImporting = false
        view?.hideLoading()
        var backupedAccountAddresses = ApplicationConfig.shared.backupedAccountAddresses
        if !backupedAccountAddresses.contains(selectedAccount.address) {
            backupedAccountAddresses.append(selectedAccount.address)
        }
        ApplicationConfig.shared.backupedAccountAddresses = backupedAccountAddresses
        
        let wireframe = wireframe, accounts = backedUpAccounts
        let openSuccess: () -> Void = {
            wireframe?.openSuccessImport(importedAccountAddress: selectedAccount.address, accounts: accounts)
        }
        if restoredShortPhrase {
            restoredShortPhrase = false
            wireframe?.presentShortPhraseWarning(acknowledged: openSuccess)
        } else {
            openSuccess()
        }
    }
    
    func didRestoreShortPhraseWallet() {
        guard isImporting else { return }
        restoredShortPhrase = true
    }
    
    func didReceiveAccountImport(error: Error) {
        isImporting = false
        restoredShortPhrase = false
        errorText = error.localizedDescription
        view?.hideLoading()
        reload()
    }
    
    func didSuggestKeystore(text: String, preferredInfo: AccountImportPreferredInfo?) {}
    func didReceiveAccountImport(metadata: AccountImportMetadata) {}
}

extension EnterPasswordViewModel: Localizable {
    private var languages: [String]? {
        LocalizationManager.shared.preferredLocalizations
    }

    func applyLocalization() {
        reload()
    }
}
