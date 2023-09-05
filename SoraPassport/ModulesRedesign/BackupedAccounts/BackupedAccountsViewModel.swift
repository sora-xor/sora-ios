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

final class BackupedAccountsViewModel {
    @Published var title: String = R.string.localizable.selectAccountImport(preferredLanguages: .currentLocale)
    var titlePublisher: Published<String>.Publisher { $title }
    
    @Published var snapshot: BackupedAccountsSnapshot = BackupedAccountsSnapshot()
    var snapshotPublisher: Published<BackupedAccountsSnapshot>.Publisher { $snapshot }
    
    var wireframe: BackupedAccountsWireframeProtocol
    var backedUpAccounts: [OpenBackupAccount]

    init(backedUpAccounts: [OpenBackupAccount], wireframe: BackupedAccountsWireframeProtocol) {
        self.backedUpAccounts = backedUpAccounts
        self.wireframe = wireframe
    }
    
    deinit {
        print("deinited")
    }
    
    private func createSnapshot() -> BackupedAccountsSnapshot {
        var snapshot = BackupedAccountsSnapshot()

        let backedUpAddresses = ApplicationConfig.shared.backupedAccountAddresses
        let accounts = backedUpAddresses.isEmpty ? backedUpAccounts : backedUpAccounts.filter { !ApplicationConfig.shared.backupedAccountAddresses.contains($0.address) }
        
        let sections = [ contentSection(with: accounts) ]
        snapshot.appendSections(sections)
        sections.forEach { snapshot.appendItems($0.items, toSection: $0) }
        
        return snapshot
    }

    private func contentSection(with accounts: [OpenBackupAccount]) -> BackupedAccountsSection {
        var items = accountItems(from: accounts)
        
        items.append(contentsOf: [
            .space(SoramitsuTableViewSpacerItem(space: 16, color: .custom(uiColor: .clear))),
            .button(buttonItem())
        ])

        return BackupedAccountsSection(items: items)
    }
    
    private func accountItems(from accounts: [OpenBackupAccount]) -> [BackupedAccountSectionItem] {
        return accounts.enumerated().map { (index, account) in
            var accountItemConfig = BackupedAccountItem.Config(cornerMask: .none,
                                                               cornerRaduis: .zero,
                                                               topOffset: 18,
                                                               bottomOffset: -18)
            
            if index == 0 {
                accountItemConfig = BackupedAccountItem.Config(cornerMask: .top,
                                                               cornerRaduis: .max,
                                                               topOffset: 24,
                                                               bottomOffset: -18)
            }
            
            if index == accounts.count - 1 {
                accountItemConfig = BackupedAccountItem.Config(cornerMask: .bottom,
                                                               cornerRaduis: .max,
                                                               topOffset: 18,
                                                               bottomOffset: -24)
            }
            
            if accounts.count == 1 {
                accountItemConfig = BackupedAccountItem.Config(cornerMask: .all,
                                                               cornerRaduis: .max,
                                                               topOffset: 24,
                                                               bottomOffset: -24)
            }
            
            return .account(BackupedAccountItem(accountName: account.name,
                                                accountAddress: account.address,
                                                config: accountItemConfig))
        }
    }

    private func buttonItem() -> SoramitsuButtonItem {
        let buttonTitle = SoramitsuTextItem(text: R.string.localizable.createNewAccountTitle(preferredLanguages: languages),
                                            fontData: FontType.buttonM,
                                            textColor: .bgSurface,
                                            alignment: .center)
        return SoramitsuButtonItem(title: buttonTitle, buttonBackgroudColor: .accentPrimary, handler: wireframe.showCreateAccount)
    }
}

extension BackupedAccountsViewModel: BackupedAccountsViewModelProtocol {
    func reload() {
        title = R.string.localizable.selectAccountImport(preferredLanguages: languages)
        snapshot = createSnapshot()
    }
    
    func didSelectAccount(with address: String) {
        wireframe.openInputPassword(selectedAddress: address, backedUpAccounts: backedUpAccounts)
    }
}

extension BackupedAccountsViewModel: Localizable {
    private var languages: [String]? {
        LocalizationManager.shared.preferredLocalizations
    }

    func applyLocalization() {
        reload()
    }
}
