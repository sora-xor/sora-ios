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

import Foundation
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

    func createContactViewModelListFromItems(_ items: [SearchData], parameters: ContactModuleParameters, locale: Locale, delegate: ContactViewModelDelegate?, commandFactory: WalletCommandFactoryProtocol) -> [ContactSectionViewModelProtocol] {
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
        return nil
    }
}
