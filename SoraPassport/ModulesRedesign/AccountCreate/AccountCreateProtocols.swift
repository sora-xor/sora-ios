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
