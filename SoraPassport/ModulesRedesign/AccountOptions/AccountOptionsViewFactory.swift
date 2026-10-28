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
import SoraKeystore
import RobinHood
import SoraFoundation
import SSFCloudStorage
import IrohaCrypto

final class AccountOptionsViewFactory: AccountOptionsViewFactoryProtocol {
    static func createView(account: AccountItem) -> AccountOptionsViewProtocol? {

        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem>
            = UserDataStorageFacade.shared.createRepository()
        let chain = ChainRegistryFacade.sharedRegistry.getChain(for: Chain.sora.genesisHash())!
        let view = AccountOptionsViewController()
        let cloudStorageService = CloudStorageService(uiDelegate: view)
        let interactor = AccountOptionsInteractor(keystore: Keychain(),
                                                  settings: SettingsManager.shared,
                                                  chain: chain,
                                                  cacheFacade: CacheFacade.shared,
                                                  substrateDataFacade: SubstrateDataStorageFacade.shared,
                                                  userDataFacade: UserDataStorageFacade.shared,
                                                  account: account,
                                                  accountRepository: AnyDataProviderRepository(accountRepository),
                                                  operationManager: OperationManagerFacade.sharedManager,
                                                  eventCenter: EventCenter.shared,
                                                  mnemonicCreator: IRMnemonicCreator(language: .english),
                                                  cloudStorageService: cloudStorageService)
        
        let backedupAddresses = ApplicationConfig.shared.backupedAccountAddresses
        let backupState: BackupState = backedupAddresses.contains(interactor.currentAccount.address) ? .backedUp : .notBackedUp
        let presenter = AccountOptionsPresenter(backupState: backupState)
        
        let wireframe = AccountOptionsWireframe(localizationManager: LocalizationManager.shared)
        
        view.localizationManager = LocalizationManager.shared
        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
