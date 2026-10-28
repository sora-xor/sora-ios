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
