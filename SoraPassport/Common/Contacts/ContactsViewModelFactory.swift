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
import UIKit
import RobinHood

public protocol ContactsFactoryWrapperProtocol {
    func createContactViewModelFromContact(_ contact: SearchData,
                                           parameters: ContactModuleParameters,
                                           locale: Locale,
                                           delegate: ContactViewModelDelegate?)
    -> ContactViewModelProtocol?
}


final class ContactsViewModelFactory: ContactsFactoryWrapperProtocol {
    private let iconGenerator = PolkadotIconGenerator()
    var dataStorageFacade: StorageFacadeProtocol

    init(dataStorageFacade: StorageFacadeProtocol) {
        self.dataStorageFacade = dataStorageFacade
    }

    func createContactViewModelFromContact(_ contact: SearchData,
                                           parameters: ContactModuleParameters,
                                           locale: Locale,
                                           delegate: ContactViewModelDelegate?)
    -> ContactViewModelProtocol? {
        do {
            guard parameters.accountId != contact.accountId else {
                return nil
            }

            let icon = try iconGenerator.generateFromAddress(contact.firstName)
                .imageWithFillColor(UIColor.white,
                                    size: CGSize(width: 24.0, height: 24.0),
                                    contentScale: UIScreen.main.scale)

            let viewModel = ContactViewModel(
                firstName: contact.firstName,
                lastName: contact.lastName,
                accountId: contact.accountId,
                image: icon,
                name: contact.firstName)
            return viewModel
        } catch {
            return nil
        }
    }
}
