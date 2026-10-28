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

import IrohaCrypto
import SoraFoundation
import SSFCloudStorage

protocol AccountCreateViewProtocol: ControllerBackedProtocol {
    func set(mnemonic: [String])
    func showLoading()
    func hideLoading()
}

protocol AccountCreatePresenterProtocol: AnyObject {
    func setup()
    func activateInfo()
    func proceed()
    func share()
    func restoredApp()
    func skip()
    func backupToGoogle()
}

protocol AccountCreateInteractorInputProtocol: SignInGoogle {
    func setup()
    func skipConfirmation(request: AccountCreationRequest, mnemonic: IRMnemonicProtocol)
}

protocol AccountCreateInteractorOutputProtocol: AnyObject {
    func didReceive(metadata: AccountCreationMetadata)
    func didReceiveMnemonicGeneration(error: Swift.Error)
    func didReceive(words: [String], afterConfirmationFail: Bool)
    func didCompleteConfirmation(for account: AccountItem)
    func didReceive(error: Swift.Error)
}

protocol AccountCreateWireframeProtocol: AlertPresentable, ErrorPresentable, ModalAlertPresenting, Authorizable, Loadable {
    func proceed(on controller: UIViewController?)
    func confirm(from view: AccountCreateViewProtocol?,
                 request: AccountCreationRequest,
                 metadata: AccountCreationMetadata)
    func setupBackupAccountPassword(
        on controller: AccountCreateViewProtocol?,
        account: OpenBackupAccount,
        createAccountRequest: AccountCreationRequest,
        createAccountService: CreateAccountServiceProtocol,
        mnemonic: IRMnemonicProtocol
    )
}

protocol Authorizable {
    func authorize()
}

extension Authorizable {
    func authorize() {}
}
