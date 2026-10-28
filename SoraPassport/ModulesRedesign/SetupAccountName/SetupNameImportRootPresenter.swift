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

final class SetupNameImportRootPresenter {
    weak var view: UsernameSetupViewProtocol?
    var wireframe: UsernameSetupWireframeProtocol!
    var interactor: AccountImportInteractorInputProtocol!
    var viewModel: InputViewModel!
    let settingsManager: SelectedWalletSettingsProtocol
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
    private var activeImport: UUID?
    private var importedAccount: AccountItem?
    private var didFinishImport = false
    
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
         expectedAddress: String? = nil,
         selectedSettings: SelectedWalletSettingsProtocol = SelectedWalletSettings.shared) {
        self.settingsManager = selectedSettings
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
            let username = userName ?? usernameViewModel.inputHandler.value
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
            let username = userName ?? usernameViewModel.inputHandler.value
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
            let username = userName ?? usernameViewModel.inputHandler.value
            let request = AccountImportKeystoreRequest(keystore: keystore,
                                                       password: password,
                                                       username: username,
                                                       networkType: networkType,
                                                       cryptoType: cryptoType)

            interactor.importAccountWithKeystore(request: request, completion: completion)
        }
    }

    func proceed() {
        guard activeImport == nil, !didFinishImport else { return }
        let requestID = UUID()
        let displayName = userName ?? usernameViewModel.inputHandler.value
        activeImport = requestID
        if let account = importedAccount {
            saveName(for: account, displayName: displayName, requestID: requestID)
            return
        }
        importAccount { [weak self] result in
            let finish = { [weak self] in
                guard let self, self.activeImport == requestID, self.importedAccount == nil else { return }
                switch result {
                case let .success(account):
                    self.importedAccount = account
                    self.saveName(for: account, displayName: displayName, requestID: requestID)
                case let .failure(error):
                    self.activeImport = nil
                    if !(error is CancellationError) {
                        self.wireframe.present(message: error.localizedDescription,
                            title: WalletUX.text("Wallet keys not restored"), closeAction: WalletUX.text("OK"), from: self.view)
                    }
                case nil:
                    self.activeImport = nil
                }
            }
            if Thread.isMainThread { finish() }
            else { DispatchQueue.main.async(execute: finish) }
        }
    }

    private func saveName(for account: AccountItem, displayName: String, requestID: UUID) {
        settingsManager.performUpdateName(account: account, displayName: displayName) { [weak self] result in
            let finish = { [weak self] in
                guard let self, self.activeImport == requestID else { return }
                self.activeImport = nil
                switch result {
                case .success:
                    self.didFinishImport = true
                    self.eventCenter.notify(with: SelectedUsernameChanged())
                    self.wireframe.showPinCode(from: self.view)
                case let .failure(error):
                    if !(error is CancellationError) {
                        self.wireframe.present(message: error.localizedDescription,
                            title: WalletUX.text("Wallet name not saved"), closeAction: WalletUX.text("OK"), from: self.view)
                    }
                }
            }
            if Thread.isMainThread { finish() }
            else { DispatchQueue.main.async(execute: finish) }
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
