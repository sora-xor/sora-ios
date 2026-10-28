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
import SoraFoundation
import SoraKeystore
import RobinHood
import SSFCloudStorage

final class AccountCreateViewFactory {
    static func createViewForCreateAccount(username: String, endAddingBlock: (() -> Void)?) -> AccountCreateViewProtocol? {
        let keychain = Keychain()
        let settings = SelectedWalletSettings.shared

        let accountOperationFactory = AccountOperationFactory(keystore: keychain)
        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageFacade.shared.createRepository()
        
        let view = AccountCreateViewController()
        let cloudStorageService = CloudStorageService(uiDelegate: view)
        view.mode = cloudStorageService.isUserAuthorized ? .registration : .registrationWithoutAccessToGoogle
        
        let accountProvider = AnyDataProviderRepository(accountRepository)
        let createAccountService = CreateAccountService(accountRepository: accountProvider,
                                                        accountOperationFactory: accountOperationFactory,
                                                        settings: settings,
                                                        eventCenter: EventCenter.shared)
        let presenter = AccountCreatePresenter(username: username, createAccountService: createAccountService)
        
        let interactor = AccountCreateInteractor(mnemonicCreator: IRMnemonicCreator(),
                                                 supportedNetworkTypes: Chain.allCases,
                                                 defaultNetwork: Chain.sora,
                                                 accountOperationFactory: accountOperationFactory,
                                                 accountRepository: accountProvider,
                                                 settings: settings,
                                                 eventCenter: EventCenter.shared,
                                                 cloudStorageService: cloudStorageService)
        
        let wireframe = AccountCreateWireframe()
        wireframe.endAddingBlock = endAddingBlock
        
        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter
        
        let localizationManager = LocalizationManager.shared
        view.localizationManager = localizationManager
        presenter.localizationManager = localizationManager
        
        return view
    }

    static func createViewForShowPassthrase(_ account: AccountItem) -> AccountCreateViewProtocol? {
        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageFacade.shared.createRepository()
        let accountProvider = AnyDataProviderRepository(accountRepository)
        let accountOperationFactory = AccountOperationFactory(keystore: Keychain())
        
        let createAccountService = CreateAccountService(accountRepository: accountProvider,
                                                        accountOperationFactory: accountOperationFactory,
                                                        settings: SelectedWalletSettings.shared,
                                                        eventCenter: EventCenter.shared)
        
        let view = AccountCreateViewController()
        view.mode = .view
        let presenter = AccountCreatePresenter(username: account.username, createAccountService: createAccountService)
        
        let interactor = AccountBackupInteractor(keystore: Keychain(),
                                                 mnemonicCreator: IRMnemonicCreator(language: .english),
                                                 account: account)
        let wireframe = AccountCreateWireframe()
        
        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter
        
        let localizationManager = LocalizationManager.shared
        view.localizationManager = localizationManager
        presenter.localizationManager = localizationManager
        
        return view
    }
    
    static func createViewForImportAccount(
        username: String,
        isGoogleBackupSelected: Bool = false,
        isNeedSetupName: Bool,
        endAddingBlock: (() -> Void)?
    ) -> AccountCreateViewProtocol? {
        let keychain = Keychain()
        let settings = SelectedWalletSettings.shared
        
        let accountOperationFactory = AccountOperationFactory(keystore: keychain)
        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
        UserDataStorageFacade.shared.createRepository()
        let accountProvider = AnyDataProviderRepository(accountRepository)
        
        let view = AccountCreateViewController()
        let cloudStorageService = CloudStorageService(uiDelegate: view)
        view.mode = isGoogleBackupSelected ? .registration : .registrationWithoutAccessToGoogle
        
        let createAccountService = CreateAccountService(accountRepository: accountProvider,
                                                        accountOperationFactory: accountOperationFactory,
                                                        settings: SelectedWalletSettings.shared,
                                                        eventCenter: EventCenter.shared)
        
        let presenter = AccountCreatePresenter(username: username,
                                               shouldCreatedWithGoogle: isGoogleBackupSelected,
                                               createAccountService: createAccountService)
        
        let interactor = AccountCreateInteractor(mnemonicCreator: IRMnemonicCreator(),
                                                 supportedNetworkTypes: Chain.allCases,
                                                 defaultNetwork: Chain.sora,
                                                 accountOperationFactory: accountOperationFactory,
                                                 accountRepository: accountProvider,
                                                 settings: settings,
                                                 eventCenter: EventCenter.shared,
                                                 cloudStorageService: cloudStorageService)
        
        let wireframe = AddCreationWireframe()
        wireframe.isNeedSetupName = isNeedSetupName
        
        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter
        wireframe.endAddingBlock = endAddingBlock
        
        let localizationManager = LocalizationManager.shared
        view.localizationManager = localizationManager
        presenter.localizationManager = localizationManager
        
        return view
    }
}
