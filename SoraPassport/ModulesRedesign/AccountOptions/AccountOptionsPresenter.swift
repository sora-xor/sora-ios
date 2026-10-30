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
import UIKit
import SoraUIKit

enum BackupState {
    case backedUp
    case notBackedUp
    
    var optionTitle: String {
        switch self {
        case .backedUp: return R.string.localizable.accountOptionsDeleteBackup(preferredLanguages: .currentLocale)
        case .notBackedUp: return R.string.localizable.accountOptionsBackupGoogle(preferredLanguages: .currentLocale)
        }
    }

    var optionTitleColor: SoramitsuColor {
        switch self {
        case .backedUp: return .statusError
        case .notBackedUp: return .fgPrimary
        }
    }
}

final class AccountOptionsPresenter {
    weak var view: AccountOptionsViewProtocol?
    var wireframe: AccountOptionsWireframeProtocol!
    var interactor: AccountOptionsInteractorInputProtocol!
    private var appEventService = AppEventService()
    private var backupState: BackupState {
        didSet {
            DispatchQueue.main.async {
                self.view?.setupOptions(with: self.backupState, hasEntropy: self.interactor.accountHasEntropy)
            }
        }
    }

    init(backupState: BackupState) {
        self.backupState = backupState
    }
    
    private func handle(_ account: OpenBackupAccount?, authorization: AccountOptionsCloudBackupAuthorization?) {
        Task {
            let isCurrentAccountBackedup = await interactor.checkCurrentAccountBackedup()
            view?.hideLoading()
            
            if isCurrentAccountBackedup {
                var backupedAccountAddresses = ApplicationConfig.shared.backupedAccountAddresses
                backupedAccountAddresses.append(account?.address ?? "")
                ApplicationConfig.shared.backupedAccountAddresses = backupedAccountAddresses
                
                backupState = .backedUp
                showAlert(about: account, authorization: authorization)
                return
            }
            
            DispatchQueue.main.async {
                self.showPasswordScreen(with: account, authorization: authorization)
            }
        }
    }
    
    private func showPasswordScreen(with account: OpenBackupAccount?,
                                    authorization: AccountOptionsCloudBackupAuthorization?) {
        guard let account, let authorization else { return }
        wireframe?.setupBackupAccountPassword(on: view,
                                              account: account,
                                              authorization: authorization,
                                              reauthorize: { [weak self] completion in
            guard let self else { return completion(nil) }
            self.reauthorizeCloudBackup(completion: completion)
        }, completion: { [weak self] in
            guard let self = self else { return }
            self.backupState = ApplicationConfig.shared.backupedAccountAddresses.contains(account.address) ? .backedUp : .notBackedUp
            self.view?.setupOptions(with: self.backupState, hasEntropy: self.interactor.accountHasEntropy)
        })
    }
    
    /// The backup password screen asks again through the same authorization
    /// as creating the backup did.
    private func reauthorizeCloudBackup(completion: @escaping (AccountOptionsCloudBackupAuthorization?) -> Void) {
        wireframe.authorizeCloudBackup(from: view) { [weak self] isAuthorized in
            completion(isAuthorized ? self?.interactor.makeCloudBackupAuthorization() : nil)
        }
    }

    private func showAlert(about account: OpenBackupAccount?, authorization: AccountOptionsCloudBackupAuthorization?) {
        let title = R.string.localizable.backupAccountAlreadyExist(preferredLanguages: .currentLocale)
        let closeActionTitle = R.string.localizable.commonClose(preferredLanguages: .currentLocale)
        let reviewTitle = R.string.localizable.review(preferredLanguages: .currentLocale)
        
        let reviewAction = AlertPresentableAction(title: reviewTitle, style: .normal) { [weak self] in
            self?.showPasswordScreen(with: account, authorization: authorization)
        }
        let viewModel = AlertPresentableViewModel(title: title, message: nil, actions: [reviewAction], closeAction: closeActionTitle)
        
        DispatchQueue.main.async {
            self.view?.present(viewModel: viewModel, style: .alert, from: self.view)
        }
    }

    /// Creating or deleting the Google Drive backup starts only after the
    /// same fresh wallet authorization as the local exports, so cancelling
    /// or failing it changes nothing. The authorization is bound to this
    /// account; if it lapses before the operation runs, it is asked for
    /// once more.
    private func authorizeCloudBackup(then operation: @escaping (AccountOptionsCloudBackupAuthorization) -> Void) {
        wireframe.authorizeCloudBackup(from: view) { [weak self] isAuthorized in
            guard let self, isAuthorized else { return }
            operation(self.interactor.makeCloudBackupAuthorization())
        }
    }

    private func createBackup(askingAgainIfLapsed: Bool) {
        authorizeCloudBackup { [weak self] authorization in
            guard let self else { return }
            self.view?.showLoading()
            ApplicationConfig.shared.updateAvailableBackupedAccounts(account: self.interactor.currentAccount)
            self.interactor.signInToGoogleIfNeeded(authorization: authorization) { [weak self] preparation in
                guard let self else { return }
                switch preparation {
                case let .ready(account, passwordAuthorization):
                    self.handle(account, authorization: passwordAuthorization)
                case .unavailable:
                    self.handle(nil, authorization: nil)
                case .authorizationRequired:
                    self.view?.hideLoading()
                    if askingAgainIfLapsed {
                        self.createBackup(askingAgainIfLapsed: false)
                    }
                }
            }
        }
    }

    private func deleteBackup(askingAgainIfLapsed: Bool) {
        authorizeCloudBackup { [weak self] authorization in
            guard let self else { return }
            self.view?.showLoading()
            self.interactor.deleteBackup(authorization: authorization) { [weak self] error in
                self?.view?.hideLoading()
                guard let error = error else {
                    self?.backupState = .notBackedUp
                    return
                }
                if (error as? AccountOptionsCloudBackupError) == .authorizationRequired {
                    if askingAgainIfLapsed {
                        self?.deleteBackup(askingAgainIfLapsed: false)
                    }
                    return
                }
                self?.view?.present(message: nil,
                                    title: error.localizedDescription,
                                    closeAction: R.string.localizable.commonOk(preferredLanguages: .currentLocale),
                                    from: self?.view)
            }
        }
    }
}

extension AccountOptionsPresenter: AccountOptionsPresenterProtocol {
    func setup() {
        view?.didReceive(username: interactor.currentAccount.username)
        view?.didReceive(address: interactor.currentAccount.address)
        view?.setupOptions(with: backupState, hasEntropy: interactor.accountHasEntropy)
    }

    func didUpdateUsername(_ new: String) {
        interactor.updateUsername(new)
    }

    func showPassphrase() {
        let account = interactor.currentAccount
        ApplicationConfig.shared.updateAvailableBackupedAccounts(account: account)
        wireframe.showPassphrase(from: view, account: account)
    }

    func showRawSeed() {
        let account = interactor.currentAccount
        ApplicationConfig.shared.updateAvailableBackupedAccounts(account: account)
        wireframe.showRawSeed(from: view, account: account)
    }

    func showJson() {
        let account = interactor.currentAccount
        ApplicationConfig.shared.updateAvailableBackupedAccounts(account: account)
        wireframe.showJson(account: account, from: view)
    }
    
    func deleteBackup() {
        deleteBackup(askingAgainIfLapsed: true)
    }
    
    func createBackup() {
        createBackup(askingAgainIfLapsed: true)
    }
    
    func doLogout() {
        interactor.isLastAccountWithCustomNodes { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.wireframe.showLogout(from: self.view, isNeedCustomNodeText: result, completionBlock: self.interactor.logoutAndClean)
            }
        }
    }

    func close() {
        wireframe.dismissAfterDeletion(from: view)
    }

    func restart() {
        wireframe.showRoot()
    }

    func accountDeletionBlocked(message: String) {
        view?.hideLoading()
        view?.present(
            message: message,
            title: "Account deletion paused",
            closeAction: R.string.localizable.commonOk(
                preferredLanguages: .currentLocale
            ),
            from: view
        )
    }
    
    func copyToClipboard() {
        let title = NSAttributedString(string: R.string.localizable.commonCopied(preferredLanguages: .currentLocale))
        let viewModel = AppEventViewController.ViewModel(title: title)
        let appEventController = AppEventViewController(style: .custom(viewModel))
        appEventService.showToasterIfNeeded(viewController: appEventController)
        UIPasteboard.general.string = interactor.currentAccount.address
    }
}

extension AccountOptionsPresenter: AccountOptionsInteractorOutputProtocol {}
