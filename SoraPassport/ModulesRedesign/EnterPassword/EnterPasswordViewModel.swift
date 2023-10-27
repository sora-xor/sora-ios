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
import RobinHood

final class EnterPasswordViewModel {
    @Published var title: String = R.string.localizable.enterBackupPasswordTitle(preferredLanguages: .currentLocale)
    var titlePublisher: Published<String>.Publisher { $title }
    
    @Published var snapshot: EnterPasswordSnapshot = EnterPasswordSnapshot()
    var snapshotPublisher: Published<EnterPasswordSnapshot>.Publisher { $snapshot }
    
    private var wireframe: EnterPasswordWireframeProtocol?
    private var interactor: AccountImportInteractorInputProtocol
    private var errorText = ""
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
                                     continueButtonHandler: checkPassword)
        return EnterPasswordSection(items: [ .enterPassword(item) ])
    }
    
    private func checkPassword(password: String) {
        view?.showLoading()
        guard let selectedAccount = selectedAccount else { return }
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
        view?.hideLoading()
        guard let selectedAccount = selectedAccount else { return }
        
        var backupedAccountAddresses = ApplicationConfig.shared.backupedAccountAddresses
        backupedAccountAddresses.append(selectedAccount.address)
        ApplicationConfig.shared.backupedAccountAddresses = backupedAccountAddresses
        
        wireframe?.openSuccessImport(importedAccountAddress: selectedAccount.address, accounts: backedUpAccounts)
    }
    
    func didReceiveAccountImport(error: Error) {
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
