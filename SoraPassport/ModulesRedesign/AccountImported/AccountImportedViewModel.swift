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
import Combine

final class AccountImportedViewModel: AccountImportedViewModelProtocol {
    @Published var title: String = R.string.localizable.importedAccountTitle(preferredLanguages: .currentLocale)
    var titlePublisher: Published<String>.Publisher { $title }
    
    @Published var snapshot: AccountImportedSnapshot = AccountImportedSnapshot()
    var snapshotPublisher: Published<AccountImportedSnapshot>.Publisher { $snapshot }

    private let wireframe: AccountImportedWireframeProtocol
    private let importedAccount: OpenBackupAccount?
    private let backedUpAccounts: [OpenBackupAccount]
    private var endAddingBlock: (() -> Void)?

    init(importedAccountAddress: String,
         backedUpAccounts: [OpenBackupAccount],
         wireframe: AccountImportedWireframeProtocol,
         endAddingBlock: (() -> Void)? = nil) {
        self.importedAccount = backedUpAccounts.first(where: { $0.address == importedAccountAddress })
        self.backedUpAccounts = backedUpAccounts
        self.wireframe = wireframe
        self.endAddingBlock = endAddingBlock
    }
    
    deinit {
        print("deinited")
    }
    
    func reload() {
        title = R.string.localizable.importedAccountTitle(preferredLanguages: languages)
        snapshot = createSnapshot()
    }

    private func createSnapshot() -> AccountImportedSnapshot {
        var snapshot = AccountImportedSnapshot()
        
        let sections = [ contentSection() ]
        snapshot.appendSections(sections)
        sections.forEach { snapshot.appendItems($0.items, toSection: $0) }
        
        return snapshot
    }

    private func contentSection() -> AccountImportedSection {
        let importedAccountsAddresses = ApplicationConfig.shared.backupedAccountAddresses
        let areThereAnotherAccounts = !(Set(backedUpAccounts.map { $0.address }).subtracting(importedAccountsAddresses).isEmpty)
        let item = AccountImportedItem(accountName: importedAccount?.name ?? "",
                                       accountAddress: importedAccount?.address ?? "",
                                       areThereAnotherAccounts: areThereAnotherAccounts )
        item.loadMoreTapHandler = { [weak self] in
            let notBackedUpAccount = self?.backedUpAccounts.filter { !ApplicationConfig.shared.backupedAccountAddresses.contains($0.address) }
            self?.wireframe.showBackepedAccounts(accounts: notBackedUpAccount ?? [])
        }
        item.continueTapHandler = { [weak self] in
            if self?.endAddingBlock != nil {
                self?.wireframe.dissmiss(completion: self?.endAddingBlock)
                return
            }
            self?.wireframe.showSetupPinCode()
        }
        return AccountImportedSection(items: [ .accountImported(item) ])
    }
}

extension AccountImportedViewModel: Localizable {
    private var languages: [String]? {
        LocalizationManager.shared.preferredLocalizations
    }

    func applyLocalization() {
        reload()
    }
}
