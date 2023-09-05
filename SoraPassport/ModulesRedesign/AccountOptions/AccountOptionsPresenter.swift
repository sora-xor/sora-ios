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
            view?.setupOptions(with: backupState, hasEntropy: interactor.accountHasEntropy)
        }
    }

    init(backupState: BackupState) {
        self.backupState = backupState
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
        wireframe.showPassphrase(from: view, account: interactor.currentAccount)
    }

    func showRawSeed() {
        wireframe.showRawSeed(from: view, account: interactor.currentAccount)
    }

    func showJson() {
        wireframe.showJson(account: interactor.currentAccount, from: view)
    }
    
    func deleteBackup() {
        view?.showLoading()
        interactor.deleteBackup { [weak self] error in
            self?.view?.hideLoading()
            guard let error = error else {
                self?.backupState = .notBackedUp
                return
            }
            self?.view?.present(message: nil,
                                title: error.localizedDescription,
                                closeAction: R.string.localizable.commonOk(preferredLanguages: .currentLocale),
                                from: self?.view)
        }
    }
    
    func createBackup() {
        view?.showLoading()
        interactor.signInToGoogleIfNeeded { [weak self] account in
            self?.view?.hideLoading()
            guard let account else { return }
            self?.wireframe?.setupBackupAccountPassword(on: self?.view,
                                                        account: account,
                                                        completion: { [weak self] in
                guard let self = self else { return }
                self.backupState = ApplicationConfig.shared.backupedAccountAddresses.contains(account.address) ? .backedUp : .notBackedUp
                self.view?.setupOptions(with: self.backupState, hasEntropy: self.interactor.accountHasEntropy)
            })
        }
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
        wireframe.back(from: self.view)
    }

    func restart() {
        wireframe.showRoot()
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
