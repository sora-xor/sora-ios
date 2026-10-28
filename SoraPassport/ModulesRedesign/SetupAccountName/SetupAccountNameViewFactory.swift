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
                                    expectedAddress: String? = nil,
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
                                                        derivationPathViewModel: derivationPathViewModel,
                                                        expectedAddress: expectedAddress)
        
        
        let wireframe = UsernameSetupWireframe(localizationManager: localizationManager)
        
        
        let interactor = AddAccountImportInteractor(accountOperationFactory: accountOperationFactory,
                                                    accountRepository: AnyDataProviderRepository(accountRepository),
                                                    operationManager: OperationManagerFacade.sharedManager,
                                                    settings: SelectedWalletSettings.shared,
                                                    keystoreImportService: keystoreImportService,
                                                    eventCenter: EventCenter.shared)

        interactor.credentialRepairFlow = WalletMissingAccountRepairFlow(controller: view.controller,
            keystore: keystore, selection: SelectedWalletSettings.shared)
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
                                           derivationPathViewModel: InputViewModelProtocol?,
                                           expectedAddress: String? = nil) -> UsernameSetupViewProtocol? {
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
                                                     derivationPathViewModel: derivationPathViewModel,
                                                        expectedAddress: expectedAddress)
        
        
        let wireframe = UsernameSetupWireframe(localizationManager: localizationManager)
        
        
        let interactor = AddAccountImportInteractor(accountOperationFactory: accountOperationFactory,
                                                    accountRepository: AnyDataProviderRepository(accountRepository),
                                                    operationManager: OperationManagerFacade.sharedManager,
                                                    settings: SelectedWalletSettings.shared,
                                                    keystoreImportService: keystoreImportService,
                                                    eventCenter: EventCenter.shared)

        interactor.credentialRepairFlow = WalletMissingAccountRepairFlow(controller: view.controller,
            keystore: keystore, selection: SelectedWalletSettings.shared)
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

        interactor.credentialRepairFlow = WalletMissingAccountRepairFlow(controller: view.controller,
            keystore: keystore, selection: SelectedWalletSettings.shared)
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
