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

import IrohaCrypto
import SSFUtils
import RobinHood
import SoraFoundation

protocol ContactsLocalSearchEngineProtocol {
    func search(query: String,
                parameters: ContactModuleParameters,
                locale: Locale,
                delegate: ContactViewModelDelegate?) -> [ContactViewModelProtocol]?
}
 
final class ContactsLocalSearchEngine: ContactsLocalSearchEngineProtocol {
    let contactViewModelFactory: ContactsFactoryWrapperProtocol
    let networkType: SNAddressType

    private lazy var addressFactory = SS58AddressFactory()

    init(networkType: SNAddressType, contactViewModelFactory: ContactsFactoryWrapperProtocol) {
        self.contactViewModelFactory = contactViewModelFactory
        self.networkType = networkType
    }

    func search(query: String,
                parameters: ContactModuleParameters,
                locale: Locale,
                delegate: ContactViewModelDelegate?) -> [ContactViewModelProtocol]? {
        do {
            let peerId = try addressFactory.accountId(fromAddress: query, type: networkType)
            let accountIdData = try Data(hexStringSSF: parameters.accountId)

            guard peerId != accountIdData  else {
                return []
            }

            let searchData = SearchData(accountId: peerId.toHex(),
                                        firstName: query,
                                        lastName: "")

            guard let viewModel = contactViewModelFactory
                .createContactViewModelFromContact(searchData,
                                                   parameters: parameters,
                                                   locale: locale,
                                                   delegate: delegate) else {
                return nil
            }

            return [viewModel]
        } catch {
            return nil
        }

    }
}
