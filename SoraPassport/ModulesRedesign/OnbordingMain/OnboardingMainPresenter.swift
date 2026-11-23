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
    private var isConnectingCloudStorage = false

    init(locale: Locale) {
        self.locale = locale
    }
    
    private func showCloudImportError(_ error: Error) {
        let recoveryError: WalletCloudBackupRecoveryError
        switch error as? CloudStorageServiceError {
        case .notAuthorized: recoveryError = .notAuthorized
        case .notFound: recoveryError = .notFound
        default:
            recoveryError = WalletCloudBackupRecoveryError.authorizationError(for: error) == .authorizationCanceled
                ? .authorizationCanceled : .unavailable
        }
        let title: String
        let message: String
        switch recoveryError {
        case .authorizationCanceled:
            title = "Google sign-in canceled"
            message = "Choose Google to try again."
        case .notAuthorized:
            title = "Google sign-in required"
            message = "Sign in to the Google account used for this wallet’s backup. SORA will read its encrypted backup."
        case .notFound:
            title = "Backup not found"
            message = "Check which Google account holds your backup."
        default:
            title = "Google Drive unavailable"
            message = "Check your connection and try again."
        }
        let language = locale.identifier
        wireframe.present(message: WalletUX.text(message, language: language), title: WalletUX.text(title, language: language),
            closeAction: R.string.localizable.commonOk(preferredLanguages: locale.rLanguages), from: view)
    }

}

extension OnboardingMainPresenter: OnboardingMainPresenterProtocol {

    func setup() {
        interactor.setup()
    }
    
    func viewWillAppear() {
        guard !isConnectingCloudStorage else { return }
        interactor.resetGoogleState()
    }

    func activateSignup() {
        wireframe.showSignup(from: view, isGoogleBackupSelected: false)
    }

    func activateAccountRestore() {
        wireframe.showImportMethods(from: view) { [weak self] method in
            guard let self else { return }
            switch method {
            case .passphrase:
                self.wireframe.showAccountRestoreRedesign(from: self.view, sourceType: .mnemonic)
            case .rawSeed:
                self.wireframe.showAccountRestoreRedesign(from: self.view, sourceType: .seed)
            case .google:
                self.activateCloudStorageConnection()
            }
        }
    }
    
    func activateCloudStorageConnection() {
        guard !isConnectingCloudStorage else { return }
        isConnectingCloudStorage = true
        view?.showLoading()
        Task { @MainActor [weak self] in
            guard let self else { return }
            let outcome: Result<[OpenBackupAccount], Error>
            do { outcome = .success(try await self.interactor.getBackupedAccounts()) }
            catch { outcome = .failure(error) }
            self.isConnectingCloudStorage = false
            self.view?.hideLoading()
            switch outcome {
            case .success(let result):
                // Accounts whose keys are not on this iPhone stay listed.
                let accounts = result.filter { !WalletDriveBackupList.hidesBackup(of: $0.address) }
                if accounts.isEmpty {
                    self.wireframe.showSignup(from: self.view, isGoogleBackupSelected: true)
                } else {
                    self.wireframe.showBackupedAccounts(from: self.view, accounts: accounts)
                }
            case .failure(let error):
                self.showCloudImportError(error)
            }
        }
    }
}

extension OnboardingMainPresenter: OnboardingMainInteractorOutputProtocol {
    func didSuggestKeystoreImport() {
        wireframe.showKeystoreImport(from: view)
    }
}
