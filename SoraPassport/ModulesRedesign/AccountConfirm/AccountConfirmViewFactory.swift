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
import SoraFoundation
import IrohaCrypto
import RobinHood

final class AccountConfirmViewFactory {
    static func createViewForOnboardingRedesign(request: AccountCreationRequest,
                                        metadata: AccountCreationMetadata) -> ControllerBackedProtocol? {
        guard let mnemonic = try? IRMnemonicCreator()
            .mnemonic(fromList: metadata.mnemonic.joined(separator: " ")) else {
            return nil
        }
        
        let viewModel = ConfirmPassphraseViewModel(mnemonic: metadata.mnemonic)
        
        let keychain = Keychain()
        let settings = SelectedWalletSettings.shared

        let accountOperationFactory = AccountOperationFactory(keystore: keychain)
        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageFacade.shared.createRepository()

        let interactor = AccountConfirmInteractor(request: request,
                                                  mnemonic: mnemonic,
                                                  accountOperationFactory: accountOperationFactory,
                                                  accountRepository: AnyDataProviderRepository(accountRepository),
                                                  settings: settings,
                                                  operationManager: OperationManagerFacade.sharedManager)
        viewModel.interactor = interactor
        viewModel.wireframe = ConfirmPassphraseWireframe()
        interactor.presenter = viewModel

        let view = ConfirmPassphraseViewController(viewModel: viewModel)
        viewModel.view = view

        return view
    }
    
    static func createViewForRedesignAdding(request: AccountCreationRequest,
                                            metadata: AccountCreationMetadata,
                                            isNeedSetupName: Bool = true,
                                            endAddingBlock: (() -> Void)?) -> ControllerBackedProtocol? {
        guard let mnemonic = try? IRMnemonicCreator()
            .mnemonic(fromList: metadata.mnemonic.joined(separator: " ")) else {
            return nil
        }

        let viewModel = ConfirmPassphraseViewModel(mnemonic: metadata.mnemonic)

        let keychain = Keychain()

        let accountOperationFactory = AccountOperationFactory(keystore: keychain)
        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageFacade.shared.createRepository()

        let interactor = AddAccountConfirmInteractor(request: request,
                                                     mnemonic: mnemonic,
                                                     accountOperationFactory: accountOperationFactory,
                                                     accountRepository: AnyDataProviderRepository(accountRepository),
                                                     operationManager: OperationManagerFacade.sharedManager,
                                                     settings: SelectedWalletSettings.shared,
                                                     eventCenter: EventCenter.shared)
        let wireframe = ConfirmPassphraseWireframe()

        viewModel.interactor = interactor
        viewModel.wireframe = wireframe
        interactor.presenter = viewModel
        wireframe.endAddingBlock = endAddingBlock
        wireframe.isNeedSetupName = isNeedSetupName

        
        let view = ConfirmPassphraseViewController(viewModel: viewModel)
        viewModel.view = view

        return view
    }
}
