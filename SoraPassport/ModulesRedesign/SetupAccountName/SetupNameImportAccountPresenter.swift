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

final class SetupNameImportAccountPresenter {
    weak var view: UsernameSetupViewProtocol?
    var wireframe: UsernameSetupWireframeProtocol!
    var interactor: AccountImportInteractorInputProtocol!
    var viewModel: InputViewModel!
    var completion: (() -> Void)?
    let settingsManager = SelectedWalletSettings.shared
    var mode: UsernameSetupMode = .onboarding
    var userName: String?

    private let accountRepository: AnyDataProviderRepository<AccountItem>
    private let eventCenter: EventCenterProtocol
    private let operationManager: OperationManagerProtocol
    private let isNeedImport: Bool
    
    private(set) var sourceType: AccountImportSource?
    private(set) var cryptoType: CryptoType?
    private(set) var networkType: Chain?
    private(set) var sourceViewModel: InputViewModelProtocol?
    private(set) var usernameViewModel: InputViewModelProtocol?
    private(set) var passwordViewModel: InputViewModelProtocol?
    private(set) var derivationPathViewModel: InputViewModelProtocol?
    
    init(accountRepository: AnyDataProviderRepository<AccountItem>,
         eventCenter: EventCenterProtocol,
         operationManager: OperationManagerProtocol,
         sourceType: AccountImportSource?,
         cryptoType: CryptoType?,
         networkType: Chain?,
         sourceViewModel: InputViewModelProtocol?,
         usernameViewModel: InputViewModelProtocol?,
         passwordViewModel: InputViewModelProtocol?,
         derivationPathViewModel: InputViewModelProtocol?,
         isNeedImport: Bool) {
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
        self.isNeedImport = isNeedImport
    }
}

extension SetupNameImportAccountPresenter: UsernameSetupPresenterProtocol {
    func setup() {
        let value = mode == .creating ? "" : userName ?? ""
        
        let inputHandling = InputHandler(value: value,
                                         required: false,
                                         predicate: NSPredicate.notEmpty,
                                         processor: ByteLengthProcessor.username)
        viewModel = InputViewModel(inputHandler: inputHandling)
        view?.set(viewModel: viewModel)
    }
    
    func importAccount() {
        guard
            let sourceType = sourceType,
            let networkType = networkType,
            let cryptoType = cryptoType,
            let sourceViewModel = sourceViewModel,
            let usernameViewModel = viewModel
        else {
            return
        }
        
        switch sourceType {
        case .mnemonic:
            let mnemonic = sourceViewModel.inputHandler.value
            let username = usernameViewModel.inputHandler.value
            let derivationPath = derivationPathViewModel?.inputHandler.value ?? ""
            let request = AccountImportMnemonicRequest(mnemonic: mnemonic,
                                                       username: username,
                                                       networkType: networkType,
                                                       derivationPath: derivationPath,
                                                       cryptoType: cryptoType)
            interactor.importAccountWithMnemonic(request: request)
        case .seed:
            let seed = sourceViewModel.inputHandler.value
            let username = usernameViewModel.inputHandler.value
            let derivationPath = derivationPathViewModel?.inputHandler.value ?? ""
            let request = AccountImportSeedRequest(seed: seed,
                                                   username: username,
                                                   networkType: networkType,
                                                   derivationPath: derivationPath,
                                                   cryptoType: cryptoType)
            interactor.importAccountWithSeed(request: request)
        case .keystore:
            let keystore = sourceViewModel.inputHandler.value
            let password = passwordViewModel?.inputHandler.value ?? ""
            let username = usernameViewModel.inputHandler.value
            let request = AccountImportKeystoreRequest(keystore: keystore,
                                                       password: password,
                                                       username: username,
                                                       networkType: networkType,
                                                       cryptoType: cryptoType)

            interactor.importAccountWithKeystore(request: request)
        }
    }

    func proceed() {
        if isNeedImport {
            importAccount()
            return
        }
        
        if let updated = self.settingsManager.currentAccount?.replacingUsername(self.userName ?? "") {
            self.settingsManager.save(value: updated, runningCompletionIn: .main) { [weak self] result in
                if case .success = result {
                    self?.eventCenter.notify(with: SelectedUsernameChanged())
                }
            }
            
            self.completion == nil ? self.wireframe.showPinCode(from: view) : self.view?.controller.dismiss(animated: true, completion: completion)
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

extension SetupNameImportAccountPresenter: AccountImportInteractorOutputProtocol {
    func didReceiveAccountImport(metadata: AccountImportMetadata) {}

    func didCompleteAccountImport() {
        completion == nil ? wireframe.showPinCode(from: view) : view?.controller.dismiss(animated: true, completion: completion)
    }

    func didReceiveAccountImport(error: Error) {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        guard !wireframe.present(error: error, from: view, locale: locale, completion: { [weak self] in
            self?.view?.resetFocus()
        }) else {
            return
        }

        _ = wireframe.present(error: CommonError.undefined,
                              from: view,
                              locale: locale) { [weak self] in
            self?.view?.resetFocus()
        }
    }

    func didSuggestKeystore(text: String, preferredInfo: AccountImportPreferredInfo?) {}
}
    
extension SetupNameImportAccountPresenter: Localizable {
    func applyLocalization() {}
}
