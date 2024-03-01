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
import SSFCloudStorage

final class OnboardingMainPresenter {
    weak var view: OnboardingMainViewProtocol?
    var interactor: OnboardingMainInteractorInputProtocol!
    var wireframe: OnboardingMainWireframeProtocol!

    let locale: Locale

    init(locale: Locale) {
        self.locale = locale
    }
    
    private func showScreenAfterSelection(_ result: (Result<[OpenBackupAccount], Error>)) {
        view?.hideLoading()
        switch result {
        case .success(let accounts):
            let accounts = accounts.filter { !ApplicationConfig.shared.backupedAccountAddresses.contains($0.address) }
            if accounts.isEmpty {
                wireframe.showSignup(from: view, isGoogleBackupSelected: true)
                return
            }
            wireframe.showBackupedAccounts(from: view, accounts: accounts)
        case .failure:
            break
        }
    }
}

extension OnboardingMainPresenter: OnboardingMainPresenterProtocol {

    func setup() {
        interactor.setup()
    }
    
    func viewWillAppear() {
        interactor.resetGoogleState()
    }

    func activateSignup() {
        wireframe.showSignup(from: view, isGoogleBackupSelected: false)
    }

    func activateAccountRestore() {
        showActionSheet()
    }
    
    func activateCloudStorageConnection() {
        view?.showLoading()
        Task { [weak self] in
            do {
                guard let self else { return }
                let result = try await self.interactor.getBackupedAccounts()
                
                let accounts = result.filter { !ApplicationConfig.shared.backupedAccountAddresses.contains($0.address) }
                if accounts.isEmpty {
                    self.wireframe.showSignup(from: self.view, isGoogleBackupSelected: true)
                    return
                }
                self.wireframe.showBackupedAccounts(from: self.view, accounts: accounts)
            } catch {}
        }
    }
}

extension OnboardingMainPresenter: OnboardingMainInteractorOutputProtocol {
    func didSuggestKeystoreImport() {
        wireframe.showKeystoreImport(from: view)
    }
}

private extension OnboardingMainPresenter {
    func showActionSheet() {
        let title = R.string.localizable.recoveryTitleV2(preferredLanguages: .currentLocale)
        let message = R.string.localizable.importAccountMessage(preferredLanguages: .currentLocale)
        let closeActionText = R.string.localizable.commonCancel(preferredLanguages: .currentLocale)
        let rawSeedText = R.string.localizable.commonRawSeed(preferredLanguages: .currentLocale)
        let passphraseText = R.string.localizable.recoveryPassphrase(preferredLanguages: .currentLocale)
        
        let passphraseAction = AlertPresentableAction(title: passphraseText) { [weak self] in
            guard let self = self else { return }
            self.wireframe.showAccountRestoreRedesign(from: self.view, sourceType: .mnemonic)
        }
        
        let rawSeedAction = AlertPresentableAction(title: rawSeedText) { [weak self] in
            guard let self = self else { return }
            self.wireframe.showAccountRestoreRedesign(from: self.view, sourceType: .seed)
        }
        
        let googleAction = AlertPresentableAction(title: "Google") { [weak self] in
            guard let self = self else { return }
            self.activateCloudStorageConnection()
        }
        

        let viewModel = AlertPresentableViewModel(title: title,
                                                  message: message,
                                                  actions: [googleAction, passphraseAction, rawSeedAction],
                                                  closeAction: closeActionText)
        wireframe.present(viewModel: viewModel, style: .actionSheet, from: view)
    }
}
