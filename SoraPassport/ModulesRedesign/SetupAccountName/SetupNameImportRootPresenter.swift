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

final class SetupNameImportRootPresenter {
    weak var view: UsernameSetupViewProtocol?
    var wireframe: UsernameSetupWireframeProtocol!
    var interactor: AccountImportInteractorInputProtocol!
    var viewModel: InputViewModel!
    let settingsManager = SelectedWalletSettings.shared
    var mode: UsernameSetupMode = .onboarding
    var userName: String?

    private let accountRepository: AnyDataProviderRepository<AccountItem>
    private let eventCenter: EventCenterProtocol
    private let operationManager: OperationManagerProtocol
    
    private(set) var sourceType: AccountImportSource
    private(set) var cryptoType: CryptoType
    private(set) var networkType: Chain
    private(set) var sourceViewModel: InputViewModelProtocol
    private(set) var usernameViewModel: InputViewModelProtocol
    private(set) var passwordViewModel: InputViewModelProtocol?
    private(set) var derivationPathViewModel: InputViewModelProtocol?
    private let expectedAddress: String?
    
    init(accountRepository: AnyDataProviderRepository<AccountItem>,
         eventCenter: EventCenterProtocol,
         operationManager: OperationManagerProtocol,
         sourceType: AccountImportSource,
         cryptoType: CryptoType,
         networkType: Chain,
         sourceViewModel: InputViewModelProtocol,
         usernameViewModel: InputViewModelProtocol,
         passwordViewModel: InputViewModelProtocol?,
         derivationPathViewModel: InputViewModelProtocol?,
         expectedAddress: String? = nil) {
        self.accountRepository = accountRepository
        self.eventCenter = eventCenter
        self.operationManager = operationManager
        self.sourceType = sourceType
        self.cryptoType = cryptoType
        self.networkType = networkType
        self.sourceViewModel = sourceViewModel
        self.usernameViewModel = usernameViewModel
        self.passwordViewModel = passwordViewModel
        self.derivationPathViewModel = derivationPathViewModel
        self.expectedAddress = expectedAddress
    }
}

extension SetupNameImportRootPresenter: UsernameSetupPresenterProtocol {
    func setup() {
        let value = mode == .creating ? "" : userName ?? ""
        
        let inputHandling = InputHandler(value: value,
                                         required: false,
                                         predicate: NSPredicate.notEmpty,
                                         processor: ByteLengthProcessor.username)
        viewModel = InputViewModel(inputHandler: inputHandling)
        view?.set(viewModel: viewModel)
    }
    
    func importAccount(completion: ((Result<AccountItem, Swift.Error>?) -> Void)?) {
        switch sourceType {
        case .mnemonic:
            let mnemonic = sourceViewModel.inputHandler.value
            let username = usernameViewModel.inputHandler.value
            let derivationPath = derivationPathViewModel?.inputHandler.value ?? ""
            let request = AccountImportMnemonicRequest(mnemonic: mnemonic,
                                                       username: username,
                                                       networkType: networkType,
                                                       derivationPath: derivationPath,
                                                       cryptoType: cryptoType,
                                                       expectedAddress: expectedAddress)
            interactor.importAccountWithMnemonic(request: request, completion: completion)
        case .seed:
            let seed = sourceViewModel.inputHandler.value
            let username = usernameViewModel.inputHandler.value
            let derivationPath = derivationPathViewModel?.inputHandler.value ?? ""
            let request = AccountImportSeedRequest(seed: seed,
                                                   username: username,
                                                   networkType: networkType,
                                                   derivationPath: derivationPath,
                                                   cryptoType: cryptoType)
            interactor.importAccountWithSeed(request: request, completion: completion)
        case .keystore:
            let keystore = sourceViewModel.inputHandler.value
            let password = passwordViewModel?.inputHandler.value ?? ""
            let username = usernameViewModel.inputHandler.value
            let request = AccountImportKeystoreRequest(keystore: keystore,
                                                       password: password,
                                                       username: username,
                                                       networkType: networkType,
                                                       cryptoType: cryptoType)

            interactor.importAccountWithKeystore(request: request, completion: completion)
        }
    }

    func proceed() {
        let endingBlock: (() -> Void)? = { [weak self] in
            guard let self = self else { return }
            if let account = self.settingsManager.currentAccount {
                self.settingsManager.performUpdateName(
                    account: account,
                    displayName: self.userName ?? ""
                ) { [weak self] result in
                    DispatchQueue.main.async {
                        if case .success = result {
                            self?.eventCenter.notify(with: SelectedUsernameChanged())
                        }
                    }
                }
                
               self.wireframe.showPinCode(from: view)
                return
            }
        }
        
       
        importAccount { [weak self] result in
            switch result {
            case .success: endingBlock?()
            case .failure(let error) where !(error is CancellationError):
                self?.wireframe.present(message: error.localizedDescription,
                    title: WalletUX.text("Wallet keys not restored"), closeAction: WalletUX.text("OK"), from: self?.view)
            default: break
            }
        }
    }
    
    func endEditing() {}

    func activateURL(_ url: URL) {
        if let view = view {
            wireframe.showWeb(url: url,
                              from: view,
                              style: .modal)
        }
    }
}
    
extension SetupNameImportRootPresenter: Localizable {
    func applyLocalization() {}
}
