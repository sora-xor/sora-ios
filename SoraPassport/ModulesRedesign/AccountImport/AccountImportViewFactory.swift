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
