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
import SoraFoundation
import RobinHood
import SoraKeystore

final class SetupAccountNameViewFactory {
    static func createViewForOnboarding(mode: UsernameSetupMode = .onboarding, endAddingBlock: (() -> Void)? = nil) -> UsernameSetupViewProtocol? {
        let localizationManager = LocalizationManager.shared
        let view = SetupAccountNameViewController()
        let presenter = UsernameSetupPresenter()
        presenter.mode = mode
        let wireframe = UsernameSetupWireframe(localizationManager: localizationManager, endAddingBlock: endAddingBlock)

        view.presenter = presenter
        presenter.view = view
        presenter.wireframe = wireframe

        presenter.localizationManager = localizationManager

        return view
    }
    
    static func createViewForAddImport(sourceType: AccountImportSource,
                                    cryptoType: CryptoType,
                                    networkType: Chain,
                                    sourceViewModel: InputViewModelProtocol,
                                    usernameViewModel: InputViewModelProtocol,
                                    passwordViewModel: InputViewModelProtocol?,
                                    derivationPathViewModel: InputViewModelProtocol?,
                                    endAddingBlock: (() -> Void)?) -> UsernameSetupViewProtocol? {
        guard let keystoreImportService: KeystoreImportServiceProtocol =
            URLHandlingService.shared.findService() else {
            Logger.shared.error("Missing required keystore import service")
            return nil
        }
        
        let localizationManager = LocalizationManager.shared

        let keystore = Keychain()
        let accountOperationFactory = AccountOperationFactory(keystore: keystore)
        
        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageFacade.shared.createRepository()
        
        let view = SetupAccountNameViewController()
        
        let presenter = SetupNameImportAccountPresenter(accountRepository: AnyDataProviderRepository(accountRepository),
                                                        eventCenter: EventCenter.shared,
                                                        operationManager: OperationManager(),
                                                        sourceType: sourceType,
                                                        cryptoType: cryptoType,
                                                        networkType: networkType,
                                                        sourceViewModel: sourceViewModel,
                                                        usernameViewModel: usernameViewModel,
                                                        passwordViewModel: passwordViewModel,
                                                        derivationPathViewModel: derivationPathViewModel)
        
        
        let wireframe = UsernameSetupWireframe(localizationManager: localizationManager)
        
        
        let interactor = AddAccountImportInteractor(accountOperationFactory: accountOperationFactory,
                                                    accountRepository: AnyDataProviderRepository(accountRepository),
                                                    operationManager: OperationManagerFacade.sharedManager,
                                                    settings: SelectedWalletSettings.shared,
                                                    keystoreImportService: keystoreImportService,
                                                    eventCenter: EventCenter.shared)

        view.presenter = presenter
        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        presenter.localizationManager = localizationManager
        presenter.completion = endAddingBlock
        
        return view
    }
    
    static func createViewForAccountImport(sourceType: AccountImportSource,
                                           cryptoType: CryptoType,
                                           networkType: Chain,
                                           sourceViewModel: InputViewModelProtocol,
                                           usernameViewModel: InputViewModelProtocol,
                                           passwordViewModel: InputViewModelProtocol?,
                                           derivationPathViewModel: InputViewModelProtocol?) -> UsernameSetupViewProtocol? {
        guard let keystoreImportService: KeystoreImportServiceProtocol =
                URLHandlingService.shared.findService() else {
            Logger.shared.error("Missing required keystore import service")
            return nil
        }
        
        let localizationManager = LocalizationManager.shared

        let keystore = Keychain()
        let accountOperationFactory = AccountOperationFactory(keystore: keystore)
        
        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageFacade.shared.createRepository()
        
        let view = SetupAccountNameViewController()
        
        let presenter = SetupNameImportRootPresenter(accountRepository: AnyDataProviderRepository(accountRepository),
                                                     eventCenter: EventCenter.shared,
                                                     operationManager: OperationManager(),
                                                     sourceType: sourceType,
                                                     cryptoType: cryptoType,
                                                     networkType: networkType,
                                                     sourceViewModel: sourceViewModel,
                                                     usernameViewModel: usernameViewModel,
                                                     passwordViewModel: passwordViewModel,
                                                     derivationPathViewModel: derivationPathViewModel)
        
        
        let wireframe = UsernameSetupWireframe(localizationManager: localizationManager)
        
        
        let interactor = AddAccountImportInteractor(accountOperationFactory: accountOperationFactory,
                                                    accountRepository: AnyDataProviderRepository(accountRepository),
                                                    operationManager: OperationManagerFacade.sharedManager,
                                                    settings: SelectedWalletSettings.shared,
                                                    keystoreImportService: keystoreImportService,
                                                    eventCenter: EventCenter.shared)

        view.presenter = presenter
        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        presenter.localizationManager = localizationManager
        
        return view
    }
    
    static func createViewForCreationImport(endAddingBlock: (() -> Void)?) -> UsernameSetupViewProtocol? {
        guard let keystoreImportService: KeystoreImportServiceProtocol =
            URLHandlingService.shared.findService() else {
            Logger.shared.error("Missing required keystore import service")
            return nil
        }
        
        let localizationManager = LocalizationManager.shared

        let keystore = Keychain()
        let accountOperationFactory = AccountOperationFactory(keystore: keystore)
        
        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageFacade.shared.createRepository()
        
        let view = SetupAccountNameViewController()
        
        let presenter = SetupNameCreateAccountPresenter(accountRepository: AnyDataProviderRepository(accountRepository),
                                                        eventCenter: EventCenter.shared,
                                                        operationManager: OperationManager())
        
        
        let wireframe = UsernameSetupWireframe(localizationManager: localizationManager)
        
        
        let interactor = AddAccountImportInteractor(accountOperationFactory: accountOperationFactory,
                                                    accountRepository: AnyDataProviderRepository(accountRepository),
                                                    operationManager: OperationManagerFacade.sharedManager,
                                                    settings: SelectedWalletSettings.shared,
                                                    keystoreImportService: keystoreImportService,
                                                    eventCenter: EventCenter.shared)

        view.presenter = presenter
        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        presenter.localizationManager = localizationManager
        presenter.completion = endAddingBlock
        
        return view
    }

    static func createViewForAdding(isGoogleBackupSelected: Bool = false,
                                    isNeedSetupName: Bool = true,
                                    endEditingBlock: (() -> Void)?) -> UsernameSetupViewProtocol? {
        let localizationManager = LocalizationManager.shared
        let view = SetupAccountNameViewController()
        let presenter = UsernameSetupPresenter()
        let wireframe = AddUsernameWireframe(localizationManager: localizationManager,
                                             isGoogleBackupSelected: isGoogleBackupSelected,
                                             isNeedSetupName: isNeedSetupName)

        view.presenter = presenter
        presenter.view = view
        presenter.wireframe = wireframe
        presenter.mode = .creating
        wireframe.endAddingBlock = endEditingBlock

        return view
    }
}
