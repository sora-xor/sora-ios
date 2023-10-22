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
import CommonWallet
import SoraFoundation

public protocol ContactsListViewModelFactoryProtocol {
    func createContactViewModelListFromItems(_ items: [SearchData],
                                             parameters: ContactModuleParameters,
                                             locale: Locale,
                                             delegate: ContactViewModelDelegate?,
                                             commandFactory: WalletCommandFactoryProtocol)
        -> [ContactSectionViewModelProtocol]

    func createSearchViewModelListFromItems(_ items: [SearchData],
                                            parameters: ContactModuleParameters,
                                            locale: Locale,
                                            delegate: ContactViewModelDelegate?,
                                            commandFactory: WalletCommandFactoryProtocol)
        -> [WalletViewModelProtocol]

    func createBarActionForAccountId(_ parameters: ContactModuleParameters,
                                     locale: Locale,
                                     commandFactory: WalletCommandFactoryProtocol)
        -> WalletBarActionViewModelProtocol?
}


final class ContactsListViewModelFactory: ContactsListViewModelFactoryProtocol {
    private var itemViewModelFactory =
        ContactsViewModelFactory(dataStorageFacade: SubstrateDataStorageFacade.shared)

    func createContactViewModelListFromItems(_ items: [CommonWallet.SearchData], parameters: ContactModuleParameters, locale: Locale, delegate: ContactViewModelDelegate?, commandFactory: WalletCommandFactoryProtocol) -> [ContactSectionViewModelProtocol] {
        let (localItems, remoteItems) = items.reduce(([SearchData](), [SearchData]())) { (result, item) in
            let context = ContactContext(context: item.context ?? [:])

            switch context.destination {
            case .local:
                return (result.0 + [item], result.1)
            case .remote:
                return (result.0, result.1 + [item])
            }
        }
        let locale = LocalizationManager.shared.selectedLocale
        var sections = [ContactSectionViewModelProtocol]()

        if !localItems.isEmpty {
            let viewModels = createSearchViewModelListFromItems(localItems,
                                                                parameters: parameters,
                                                                locale: locale,
                                                                delegate: delegate, commandFactory: commandFactory)

            let sectionTitle = R.string.localizable
                .search(preferredLanguages: locale.rLanguages)
            let section = ContactSectionViewModel(title: sectionTitle,
                                                  items: viewModels)
            sections.append(section)
        }

        if !remoteItems.isEmpty {
            let viewModels = createSearchViewModelListFromItems(remoteItems,
                                                                parameters: parameters,
                                                                locale: locale,
                                                                delegate: delegate, commandFactory: commandFactory)
            let sectionTitle = R.string.localizable
                .search(preferredLanguages: locale.rLanguages)
            let section = ContactSectionViewModel(title: sectionTitle,
                                                  items: viewModels)
            sections.append(section)
        }

        return sections
    }

    func createSearchViewModelListFromItems(_ items: [SearchData],
                                            parameters: ContactModuleParameters,
                                            locale: Locale,
                                            delegate: ContactViewModelDelegate?,
                                            commandFactory: WalletCommandFactoryProtocol)
    -> [WalletViewModelProtocol] {
        items.compactMap {
            itemViewModelFactory.createContactViewModelFromContact($0,
                                                                   parameters: parameters,
                                                                   locale: locale,
                                                                   delegate: delegate)
        }
    }

    func createBarActionForAccountId(_ parameters: ContactModuleParameters,
                                     locale: Locale,
                                     commandFactory: WalletCommandFactoryProtocol)
    -> WalletBarActionViewModelProtocol? {
        guard let icon = R.image.iconWalletScan() else {
            return nil
        }

        let command = commandFactory.prepareScanReceiverCommand()
        let viewModel = WalletBarActionViewModel(displayType: .icon(icon.withRenderingMode(.alwaysOriginal)),
                                                 command: command)
        return viewModel
    }
}
