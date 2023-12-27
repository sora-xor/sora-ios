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
import RobinHood

protocol AccountImportViewProtocol: ControllerBackedProtocol {
    func setSource(type: AccountImportSource)
    func setSource(viewModel: InputViewModelProtocol)
    func setName(viewModel: InputViewModelProtocol)
    func setPassword(viewModel: InputViewModelProtocol)
    func setDerivationPath(viewModel: InputViewModelProtocol)
    func setUploadWarning(message: String)
    func dismissPresentedController()
    func resetFocus()
}

protocol AccountImportPresenterProtocol: AnyObject {
    func setup()
    func proceed()
    func activateURL(_ url: URL)
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
}

protocol AccountImportWireframeProtocol: AlertPresentable, ErrorPresentable, WebPresentable {
    func proceed(from view: AccountImportViewProtocol?,
                 sourceType: AccountImportSource,
                 cryptoType: CryptoType,
                 networkType: Chain,
                 sourceViewModel: InputViewModelProtocol,
                 usernameViewModel: InputViewModelProtocol,
                 passwordViewModel: InputViewModelProtocol?,
                 derivationPathViewModel: InputViewModelProtocol?)
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
