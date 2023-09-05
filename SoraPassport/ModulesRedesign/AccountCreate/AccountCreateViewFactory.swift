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
