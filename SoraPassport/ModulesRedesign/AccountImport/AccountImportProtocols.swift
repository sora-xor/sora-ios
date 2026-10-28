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
