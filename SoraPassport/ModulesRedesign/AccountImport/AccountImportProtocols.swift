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

import UIKit
import IrohaCrypto
import SoraFoundation
import RobinHood

protocol AccountImportViewProtocol: ControllerBackedProtocol {
    func setSource(type: AccountImportSource)
    func setSource(viewModel: InputViewModelProtocol)
    func setName(viewModel: InputViewModelProtocol)
    func setPassword(viewModel: InputViewModelProtocol)
    func setDerivationPath(viewModel: InputViewModelProtocol)
    func setCryptoType(_ type: CryptoType, available: [CryptoType])
    func setUploadWarning(message: String)
    func dismissPresentedController()
    func resetFocus()
}

protocol AccountImportPresenterProtocol: AnyObject {
    func setup()
    func proceed()
    func activateURL(_ url: URL)
    func selectCryptoType(_ type: CryptoType)
}

protocol AccountImportInteractorInputProtocol: AnyObject {
    func setup()
    
    func importAccountWithMnemonic(request: AccountImportMnemonicRequest, completion: ((Result<AccountItem, Swift.Error>?) -> Void)?)
    func importAccountWithSeed(request: AccountImportSeedRequest, completion: ((Result<AccountItem, Swift.Error>?) -> Void)?)
    func importAccountWithKeystore(request: AccountImportKeystoreRequest, completion: ((Result<AccountItem, Swift.Error>?) -> Void)?)
    
    func validateAccountWithMnemonic(request: AccountImportMnemonicRequest, completion: ((Result<AccountItem?, Swift.Error>?) -> Void)?)
    func validateAccountWithSeed(request: AccountImportSeedRequest, completion: ((Result<AccountItem?, Swift.Error>?) -> Void)?)
    func validateAccountWithKeystore(request: AccountImportKeystoreRequest, completion: ((Result<AccountItem?, Swift.Error>?) -> Void)?)
    
    func deriveMetadataFromKeystore(_ keystore: String)
    func importBackedupAccount(request: AccountImportBackedupRequest)
}

protocol AccountImportInteractorOutputProtocol: AnyObject {
    func didReceiveAccountImport(metadata: AccountImportMetadata)
    func didCompleteAccountImport()
    func didReceiveAccountImport(error: Swift.Error)
    func didSuggestKeystore(text: String, preferredInfo: AccountImportPreferredInfo?)
    /// A Google Drive backup is being restored from a 3-, 6- or 9-word phrase (see
    /// `WalletShortPhraseWarning`). Sent on the main queue before the import completes or fails.
    func didRestoreShortPhraseWallet()
}

extension AccountImportInteractorOutputProtocol {
    func didRestoreShortPhraseWallet() {}
}

protocol AccountImportWireframeProtocol: AlertPresentable, ErrorPresentable, WebPresentable {
    func requestKnownAddress(from view: AccountImportViewProtocol?, completion: @escaping (String?) -> Void)
    func proceed(from view: AccountImportViewProtocol?,
                 sourceType: AccountImportSource,
                 cryptoType: CryptoType,
                 networkType: Chain,
                 sourceViewModel: InputViewModelProtocol,
                 usernameViewModel: InputViewModelProtocol,
                 passwordViewModel: InputViewModelProtocol?,
                 derivationPathViewModel: InputViewModelProtocol?,
                 expectedAddress: String?)
}

extension AccountImportInteractorInputProtocol {
    func importAccountWithMnemonic(request: AccountImportMnemonicRequest, completion: ((Result<AccountItem, Swift.Error>?) -> Void)? = nil) {
        importAccountWithMnemonic(request: request, completion: completion)
    }
    
    func importAccountWithSeed(request: AccountImportSeedRequest, completion: ((Result<AccountItem, Swift.Error>?) -> Void)? = nil) {
        importAccountWithSeed(request: request, completion: completion)
    }
    
    func importAccountWithKeystore(request: AccountImportKeystoreRequest, completion: ((Result<AccountItem, Swift.Error>?) -> Void)? = nil) {
        importAccountWithKeystore(request: request, completion: completion)
    }
}


extension AccountImportWireframeProtocol {
    func requestKnownAddress(from view: AccountImportViewProtocol?, completion: @escaping (String?) -> Void) {
        guard let view else { completion(nil); return }
        view.resetFocus()
        let alert = UIAlertController(title: WalletUX.text("Restore a historical wallet"),
            message: WalletUX.text("For a 3-, 6-, or 9-word phrase, enter the SORA address of the wallet you want to restore. The phrase and derivation path must match this address before any keys are saved.")
                + "\n\n" + WalletShortPhraseWarning.restoreNotice,
            preferredStyle: .alert)
        alert.addTextField {
            $0.placeholder = WalletUX.text("SORA wallet address")
            $0.autocapitalizationType = .none
            $0.autocorrectionType = .no
            $0.spellCheckingType = .no
            $0.accessibilityIdentifier = "historical-wallet-known-address"
        }
        alert.addAction(UIAlertAction(title: WalletUX.text("Cancel"), style: .cancel) { _ in completion(nil) })
        alert.addAction(UIAlertAction(title: WalletUX.text("Continue"), style: .default) { [weak alert] _ in
            let address = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
            completion(address?.isEmpty == false ? address : nil)
        })
        view.controller.present(alert, animated: true)
    }
}

/// The 3-, 6- and 9-word phrases App Store 3.8.6 accepted hold 32, 64 or 96 bits of entropy
/// instead of at least 128, so their keys are far easier to guess. Restoring one says so and
/// recommends moving the funds to a new 24-word wallet.
enum WalletShortPhraseWarning {
    static var restoreNotice: String {
        WalletUX.text("A phrase with fewer than 12 words is much easier to guess. After restoring, create a new wallet with a 24-word phrase and move your funds to it.")
    }

    static var title: String { WalletUX.text("Move your funds to a new wallet") }

    static var message: String {
        WalletUX.text("This wallet's recovery phrase has fewer than 12 words, which makes it much easier to guess. Create a new wallet with a 24-word phrase and move your funds to it.")
    }

    /// Shows the warning over `controller`. `acknowledged` runs once it is closed, or at once
    /// when nothing on screen can show it, so a finished restore never waits on the alert.
    static func present(from controller: UIViewController?, acknowledged: @escaping () -> Void) {
        var top = controller
        while let presented = top?.presentedViewController { top = presented }
        guard let top, top.viewIfLoaded?.window != nil else { acknowledged(); return }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: WalletUX.text("OK"), style: .default) { _ in acknowledged() })
        top.present(alert, animated: true)
    }
}
