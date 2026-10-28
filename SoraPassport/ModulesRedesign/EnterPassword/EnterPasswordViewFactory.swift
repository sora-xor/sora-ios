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

import UIKit
import SoraFoundation
import SoraKeystore
import SSFCloudStorage
import SSFUtils
import RobinHood

final class EnterPasswordViewFactory {
    static func createView(
        with selectedAddress: String,
        backedUpAccounts: [OpenBackupAccount],
        endAddingBlock: (() -> Void)? = nil
    ) -> EnterPasswordViewProtocol? {
        guard let keystoreImportService: KeystoreImportServiceProtocol =
            URLHandlingService.shared.findService() else {
            Logger.shared.error("Missing required keystore import service")
            return nil
        }

        let keystore = Keychain()
        let settings = SelectedWalletSettings.shared
        let accountOperationFactory = AccountOperationFactory(keystore: keystore)

        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem>
            = UserDataStorageFacade.shared.createRepository()
        
        let view = EnterPasswordViewController()
        let cloudStorage = CloudStorageService(uiDelegate: view)
        
        let interactor = AccountImportInteractor(accountOperationFactory: accountOperationFactory,
                                                 accountRepository: AnyDataProviderRepository(accountRepository),
                                                 operationManager: OperationManagerFacade.sharedManager,
                                                 settings: settings,
                                                 keystoreImportService: keystoreImportService,
                                                 eventCenter: EventCenter.shared,
                                                 cloudStorage: cloudStorage)

        let wireframe = EnterPasswordWireframe(currentController: view, endAddingBlock: endAddingBlock)
        let viewModel = EnterPasswordViewModel(selectedAddress: selectedAddress,
                                               backedUpAccounts: backedUpAccounts,
                                               interactor: interactor,
                                               wireframe: wireframe,
                                               view: view)
        interactor.credentialRepairFlow = WalletMissingAccountRepairFlow(controller: view.controller,
            keystore: keystore, selection: SelectedWalletSettings.shared)
        interactor.presenter = viewModel
        view.viewModel = viewModel

        return view
    }
}
