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

import SoraFoundation
import SoraUIKit
import SSFCloudStorage
import RobinHood

enum EnterPasswordErrorKind: Equatable {
    case incorrectPassword
    case backupNotFound
    case authorization
    case unreadableBackup
    case differentWallet
    case retry
}

final class EnterPasswordViewModel {
    @Published var title: String = R.string.localizable.enterBackupPasswordTitle(preferredLanguages: .currentLocale)
    var titlePublisher: Published<String>.Publisher { $title }
    
    @Published var snapshot: EnterPasswordSnapshot = EnterPasswordSnapshot()
    var snapshotPublisher: Published<EnterPasswordSnapshot>.Publisher { $snapshot }
    
    private var wireframe: EnterPasswordWireframeProtocol?
    private var interactor: AccountImportInteractorInputProtocol
    private var errorText = ""
    private let selectedAccount: OpenBackupAccount?
    private var backedUpAccounts: [OpenBackupAccount]
    private weak var view: EnterPasswordViewProtocol?
    private let isRecovery: Bool
    private let googleAccountEmail: String?
    private let expectedGoogleAccountID: String?
    private var isSubmitting = false

    init(selectedAddress: String,
         backedUpAccounts: [OpenBackupAccount],
         interactor: AccountImportInteractorInputProtocol,
         wireframe: EnterPasswordWireframeProtocol,
         view: EnterPasswordViewProtocol?,
         isRecovery: Bool = false,
         googleAccountEmail: String? = nil,
         expectedGoogleAccountID: String? = nil) {
        self.selectedAccount = backedUpAccounts.first(where: { $0.address == selectedAddress })
        self.interactor = interactor
        self.backedUpAccounts = backedUpAccounts
        self.wireframe = wireframe
        self.view = view
        self.isRecovery = isRecovery
        self.googleAccountEmail = googleAccountEmail
        self.expectedGoogleAccountID = expectedGoogleAccountID
    }
    
    deinit {
        print("deinited")
    }

    private func createSnapshot() -> EnterPasswordSnapshot {
        var snapshot = EnterPasswordSnapshot()
        
        let sections = [ contentSection() ]
        snapshot.appendSections(sections)
        sections.forEach { snapshot.appendItems($0.items, toSection: $0) }
        
        return snapshot
    }

    private func contentSection() -> EnterPasswordSection {
        let item = EnterPasswordItem(accountName: selectedAccount?.name ?? "",
                                     accountAddress: selectedAccount?.address ?? "",
                                     descriptionText: isRecovery
                                        ? Self.recoveryDescription(
                                            googleAccountEmail: googleAccountEmail
                                        )
                                        : R.string.localizable.enterPasswordDescription(
                                            preferredLanguages: .currentLocale
                                        ),
                                     continueTitle: isRecovery
                                        ? Self.localized(
                                            "wallet.recovery.verify",
                                            fallback: "Verify and restore"
                                        )
                                        : R.string.localizable.transactionContinue(
                                            preferredLanguages: .currentLocale
                                        ),
                                     errorText: errorText,
                                     continueButtonHandler: checkPassword)
        return EnterPasswordSection(items: [ .enterPassword(item) ])
    }
    
    private func checkPassword(password: String) {
        guard !isSubmitting else { return }
        guard !password.isEmpty else {
            errorText = Self.localized(
                "wallet.recovery.password.required",
                fallback: "Enter your backup password."
            )
            reload()
            return
        }
        guard let selectedAccount else {
            errorText = Self.localized(
                "wallet.recovery.backup.not.found",
                fallback: "No Google Drive backup was found for this wallet."
            )
            reload()
            return
        }

        isSubmitting = true
        errorText = ""
        view?.showLoading()
        let request = AccountImportBackedupRequest(
            account: selectedAccount,
            password: password,
            expectedCloudAccountID: expectedGoogleAccountID
        )
        interactor.importBackedupAccount(request: request)
    }

    static func classify(error: Error) -> EnterPasswordErrorKind {
        if let cloudError = error as? CloudStorageServiceError {
            switch cloudError {
            case .incorectPassword:
                return .incorrectPassword
            case .notFound:
                return .backupNotFound
            case .notAuthorized:
                return .authorization
            case .incorectJson:
                return .unreadableBackup
            }
        }

        if let accountError = error as? AccountCreateError {
            switch accountError {
            case .invalidSeed:
                return .differentWallet
            case .invalidKeystore, .unsupportedNetwork:
                return .unreadableBackup
            default:
                break
            }
        }

        return .retry
    }

    static func message(for kind: EnterPasswordErrorKind, isRecovery: Bool) -> String {
        guard isRecovery else {
            return R.string.localizable.enterPasswordIncorectTitle(preferredLanguages: .currentLocale)
        }

        switch kind {
        case .incorrectPassword:
            return localized(
                "wallet.recovery.password.incorrect",
                fallback: "That backup password is incorrect. It may be different from your app PIN."
            )
        case .backupNotFound:
            return localized(
                "wallet.recovery.backup.not.found",
                fallback: "No Google Drive backup was found for this wallet."
            )
        case .authorization:
            return localized(
                "wallet.recovery.google.authorization",
                fallback: "Google Drive authorization ended. Sign in again and retry."
            )
        case .unreadableBackup:
            return localized(
                "wallet.recovery.backup.unreadable",
                fallback: "This backup could not be read. Nothing was changed."
            )
        case .differentWallet:
            return localized(
                "wallet.recovery.backup.different",
                fallback: "This backup belongs to a different wallet. Nothing was changed."
            )
        case .retry:
            return localized(
                "wallet.recovery.backup.retry",
                fallback: "The backup could not be verified. Check your connection and retry."
            )
        }
    }

    static func recoveryDescription(googleAccountEmail: String?) -> String {
        let passwordHelp = localized(
            "wallet.recovery.google.password.help",
            fallback: "Enter the backup password you created for Google Drive. It is not your app PIN."
        )
        guard let email = googleAccountEmail?.trimmingCharacters(in: .whitespacesAndNewlines),
              !email.isEmpty else {
            return passwordHelp
        }

        let accountLabel = localized(
            "wallet.recovery.google.account.label",
            fallback: "Google Drive account"
        )
        return "\(accountLabel): \(email)\n\n\(passwordHelp)"
    }

    private static func localized(_ key: String, fallback: String) -> String {
        recoveryText(key, fallback: fallback)
    }
}

extension EnterPasswordViewModel: EnterPasswordViewModelProtocol {
    func reload() {        
        title = isRecovery
            ? Self.localized("wallet.recovery.google.title", fallback: "Restore from Google Drive")
            : R.string.localizable.enterBackupPasswordTitle(preferredLanguages: languages)
        snapshot = createSnapshot()
    }
}

extension EnterPasswordViewModel: AccountImportInteractorOutputProtocol {
    func didCompleteAccountImport() {
        isSubmitting = false
        view?.hideLoading()
        guard let selectedAccount = selectedAccount else { return }
        
        var backupedAccountAddresses = ApplicationConfig.shared.backupedAccountAddresses
        if !backupedAccountAddresses.contains(selectedAccount.address) {
            backupedAccountAddresses.append(selectedAccount.address)
        }
        ApplicationConfig.shared.backupedAccountAddresses = backupedAccountAddresses

        if isRecovery {
            wireframe?.completeRecovery()
            return
        }

        wireframe?.openSuccessImport(importedAccountAddress: selectedAccount.address, accounts: backedUpAccounts)
    }
    
    func didReceiveAccountImport(error: Error) {
        isSubmitting = false
        errorText = Self.message(for: Self.classify(error: error), isRecovery: isRecovery)
        view?.hideLoading()
        reload()
    }
    
    func didSuggestKeystore(text: String, preferredInfo: AccountImportPreferredInfo?) {}
    func didReceiveAccountImport(metadata: AccountImportMetadata) {}
}

extension EnterPasswordViewModel: Localizable {
    private var languages: [String]? {
        LocalizationManager.shared.preferredLocalizations
    }

    func applyLocalization() {
        reload()
    }
}
