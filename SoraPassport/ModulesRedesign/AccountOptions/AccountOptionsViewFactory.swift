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
