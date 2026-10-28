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
import SoraKeystore
import RobinHood
import IrohaCrypto

final class AccountImportViewFactory {
    static func createViewForOnboardingRedesign(sourceType: AccountImportSource) -> AccountImportViewProtocol? {
        guard let keystoreImportService: KeystoreImportServiceProtocol =
            URLHandlingService.shared.findService() else {
            Logger.shared.error("Missing required keystore import service")
            return nil
        }

        let view = ImportAccountViewController()
        let presenter = AccountImportPresenter(sourceType: sourceType, config: ApplicationConfig.shared)

        let keystore = Keychain()
        let settings = SelectedWalletSettings.shared
        let accountOperationFactory = AccountOperationFactory(keystore: keystore)

        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem>
            = UserDataStorageFacade.shared.createRepository()

        let interactor = AccountImportInteractor(accountOperationFactory: accountOperationFactory,
                                                 accountRepository: AnyDataProviderRepository(accountRepository),
                                                 operationManager: OperationManagerFacade.sharedManager,
                                                 settings: settings,
                                                 keystoreImportService: keystoreImportService,
                                                 eventCenter: EventCenter.shared)

        let localizationManager = LocalizationManager.shared
        
        let wireframe = AccountImportWireframe(localizationManager: localizationManager)

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        presenter.localizationManager = localizationManager

        return view
    }

    static func createSilentImportInteractor() -> AccountImportInteractorInputProtocol? {
        let keystoreImportService = KeystoreImportService(logger: Logger.shared)
        let keystore = Keychain()
        let settings = SelectedWalletSettings.shared
        let accountOperationFactory = AccountOperationFactory(keystore: keystore)

        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem>
            = UserDataStorageFacade.shared.createRepository()

        let interactor = AccountImportInteractor(accountOperationFactory: accountOperationFactory,
                                                 accountRepository: AnyDataProviderRepository(accountRepository),
                                                 operationManager: OperationManagerFacade.sharedManager,
                                                 settings: settings,
                                                 keystoreImportService: keystoreImportService,
                                                 eventCenter: EventCenter.shared)
        return interactor
    }
    
    static func createViewForAdding(endAddingBlock: (() -> Void)?) -> AccountImportViewProtocol? {
        guard let keystoreImportService: KeystoreImportServiceProtocol =
            URLHandlingService.shared.findService() else {
            Logger.shared.error("Missing required keystore import service")
            return nil
        }

        let view = ImportAccountViewController()
        let presenter = AccountImportPresenter(config: ApplicationConfig.shared)

        let keystore = Keychain()
        let accountOperationFactory = AccountOperationFactory(keystore: keystore)

        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem>
            = UserDataStorageFacade.shared.createRepository()

        let interactor = AddAccountImportInteractor(accountOperationFactory: accountOperationFactory,
                                                    accountRepository: AnyDataProviderRepository(accountRepository),
                                                    operationManager: OperationManagerFacade.sharedManager,
                                                    settings: SelectedWalletSettings.shared,
                                                    keystoreImportService: keystoreImportService,
                                                    eventCenter: EventCenter.shared)

        let localizationManager = LocalizationManager.shared

        let wireframe = AddImportedWireframe(localizationManager: localizationManager)
   
        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter
        wireframe.endAddingBlock = endAddingBlock

        presenter.localizationManager = localizationManager

        return view
    }
    
    static func createViewForRedesignAdding(sourceType: AccountImportSource, endAddingBlock: (() -> Void)?) -> AccountImportViewProtocol? {
        guard let keystoreImportService: KeystoreImportServiceProtocol =
            URLHandlingService.shared.findService() else {
            Logger.shared.error("Missing required keystore import service")
            return nil
        }

        let view = ImportAccountViewController()
        let presenter = AccountImportPresenter(sourceType: sourceType, config: ApplicationConfig.shared)

        let keystore = Keychain()
        let accountOperationFactory = AccountOperationFactory(keystore: keystore)

        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem>
            = UserDataStorageFacade.shared.createRepository()

        let interactor = AddAccountImportInteractor(accountOperationFactory: accountOperationFactory,
                                                    accountRepository: AnyDataProviderRepository(accountRepository),
                                                    operationManager: OperationManagerFacade.sharedManager,
                                                    settings: SelectedWalletSettings.shared,
                                                    keystoreImportService: keystoreImportService,
                                                    eventCenter: EventCenter.shared)

        let localizationManager = LocalizationManager.shared

        let wireframe = AddImportedWireframe(localizationManager: localizationManager)
   
        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter
        wireframe.endAddingBlock = endAddingBlock

        presenter.localizationManager = localizationManager

        return view
    }
}
