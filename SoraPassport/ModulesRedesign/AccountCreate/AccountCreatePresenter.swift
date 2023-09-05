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

import UIKit
import IrohaCrypto
import SoraFoundation
import SSFCloudStorage

final class AccountCreatePresenter: SharingPresentable {
    weak var view: AccountCreateViewProtocol?
    var wireframe: AccountCreateWireframeProtocol!
    var interactor: AccountCreateInteractorInputProtocol!
    var createAccountService: CreateAccountServiceProtocol

    let username: String

    private var metadata: AccountCreationMetadata?

    private var selectedCryptoType: CryptoType?
    private var selectedNetworkType: Chain?
    private var derivationPathViewModel: InputViewModelProtocol?
    private var shouldCreatedWithGoogle: Bool

    init(username: String,
         shouldCreatedWithGoogle: Bool = true,
         createAccountService: CreateAccountServiceProtocol) {
        self.username = username
        self.shouldCreatedWithGoogle = shouldCreatedWithGoogle
        self.createAccountService = createAccountService
    }

    private func applyDerivationPathViewModel() {
        guard let cryptoType = selectedCryptoType else {
            return
        }

        let predicate: NSPredicate
        let placeholder: String

        if cryptoType == .sr25519 {
            predicate = NSPredicate.deriviationPathHardSoftPassword
            placeholder = DerivationPathConstants.hardSoftPasswordPlaceholder
        } else {
            predicate = NSPredicate.deriviationPathHardPassword
            placeholder = DerivationPathConstants.hardPasswordPlaceholder
        }

        let inputHandling = InputHandler(predicate: predicate)
        let viewModel = InputViewModel(inputHandler: inputHandling, placeholder: placeholder)

        self.derivationPathViewModel = viewModel
    }

    private func presentDerivationPathError(_ cryptoType: CryptoType) {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        switch cryptoType {
        case .sr25519:
            _ = wireframe.present(error: AccountCreationError.invalidDerivationHardSoftPassword,
                                  from: view,
                                  locale: locale)
        case .ed25519, .ecdsa:
            _ = wireframe.present(error: AccountCreationError.invalidDerivationHardPassword,
                                  from: view,
                                  locale: locale)
        }
    }
}

extension AccountCreatePresenter: AccountCreatePresenterProtocol {

    func setup() {
        interactor.setup()
    }

    func activateInfo() {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        let message = R.string.localizable.mnemonicAlertText(preferredLanguages: locale.rLanguages)
        let title = R.string.localizable.commonInfo(preferredLanguages: locale.rLanguages)
        wireframe.present(message: message,
                          title: title,
                          closeAction: R.string.localizable.commonOk(preferredLanguages: locale.rLanguages),
                          from: view)
    }

    func share() {
        guard let phrase = metadata?.mnemonic.joined(separator: " ") else { return }
        UIPasteboard.general.string = phrase
    }

    func proceed() {
        guard
            let networkType = selectedNetworkType,
            let cryptoType = selectedCryptoType,
            let viewModel = derivationPathViewModel,
            let metadata = metadata,
            let mnemonic = try? IRMnemonicCreator().mnemonic(fromList: metadata.mnemonic.joined(separator: " ")) else {
            return
        }

        guard viewModel.inputHandler.completed else {
            presentDerivationPathError(cryptoType)
            return
        }

        let request = AccountCreationRequest(username: username,
                                             type: networkType,
                                             derivationPath: viewModel.inputHandler.value,
                                             cryptoType: cryptoType)

        if interactor.isSignedInGoogleAccount {
            let backupAccount = OpenBackupAccount(name: username,
                                              address: "",
                                              passphrase: metadata.mnemonic.joined(separator: " "),
                                              cryptoType: cryptoType.googleIdentifier,
                                              substrateDerivationPath: viewModel.inputHandler.value)
            wireframe?.setupBackupAccountPassword(on: view,
                                                  account: backupAccount,
                                                  createAccountRequest: request,
                                                  createAccountService: createAccountService,
                                                  mnemonic: mnemonic)
        } else {
            wireframe.confirm(from: view,
                              request: request,
                              metadata: metadata)
        }
    }
    
    func skip() {
        guard
            let networkType = selectedNetworkType,
            let cryptoType = selectedCryptoType,
            let viewModel = derivationPathViewModel,
            let metadata = metadata,
            let mnemonic = try? IRMnemonicCreator().mnemonic(fromList: metadata.mnemonic.joined(separator: " ")) else {
            return
        }
        
        let request = AccountCreationRequest(username: username,
                                             type: networkType,
                                             derivationPath: viewModel.inputHandler.value,
                                             cryptoType: cryptoType)

        if interactor.isSignedInGoogleAccount {
            let backupAccount = OpenBackupAccount(name: username,
                                              address: "",
                                              passphrase: metadata.mnemonic.joined(separator: " "),
                                              cryptoType: cryptoType.googleIdentifier,
                                              substrateDerivationPath: viewModel.inputHandler.value)
            wireframe?.setupBackupAccountPassword(on: view,
                                                  account: backupAccount,
                                                  createAccountRequest: request,
                                                  createAccountService: createAccountService,
                                                  mnemonic: mnemonic)
            return
        }
       
        
        interactor.skipConfirmation(request: request, mnemonic: mnemonic)
    }

    func restoredApp() {}
    
    func backupToGoogle() {
        interactor.signInToGoogleIfNeeded(completion: { [weak self] state in
            self?.view?.hideLoading()
            guard state == .authorized else { return }
            self?.skip()
        })
    }
}

extension AccountCreatePresenter: AccountCreateInteractorOutputProtocol {
    func didReceive(words: [String], afterConfirmationFail: Bool) {
    }
    
    func didCompleteConfirmation(for account: AccountItem) {
        wireframe.proceed(on: view?.controller)
    }
    
    func didReceive(error: Error) {
        
    }
    
    func didReceive(metadata: AccountCreationMetadata) {
        self.metadata = metadata

        selectedCryptoType = metadata.defaultCryptoType
        selectedNetworkType = metadata.defaultNetwork

        view?.set(mnemonic: metadata.mnemonic)

        applyDerivationPathViewModel()
    }

    func didReceiveMnemonicGeneration(error: Error) {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        guard !wireframe.present(error: error, from: view, locale: locale) else {
            return
        }

        _ = wireframe.present(error: CommonError.undefined,
                              from: view,
                              locale: locale)
    }
}

extension AccountCreatePresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {

        }
    }
}
