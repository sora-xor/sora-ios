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

import UIKit
import IrohaCrypto
import FearlessUtils
import RobinHood
import SoraKeystore
import SSFCloudStorage

enum ImportAccountError: Error {
    case unexpectedError
}

class BaseAccountImportInteractor {
    weak var presenter: AccountImportInteractorOutputProtocol!

    private(set) lazy var jsonDecoder = JSONDecoder()
    private(set) lazy var mnemonicCreator = IRMnemonicCreator()

    let accountOperationFactory: AccountOperationFactoryProtocol
    let accountRepository: AnyDataProviderRepository<AccountItem>
    let operationManager: OperationManagerProtocol
    let keystoreImportService: KeystoreImportServiceProtocol
    let supportedNetworks: [Chain]
    let defaultNetwork: Chain
    let cloudStorage: CloudStorageServiceProtocol?

    init(accountOperationFactory: AccountOperationFactoryProtocol,
         accountRepository: AnyDataProviderRepository<AccountItem>,
         operationManager: OperationManagerProtocol,
         keystoreImportService: KeystoreImportServiceProtocol,
         supportedNetworks: [Chain],
         defaultNetwork: Chain,
         cloudStorage: CloudStorageServiceProtocol?) {
        self.accountOperationFactory = accountOperationFactory
        self.accountRepository = accountRepository
        self.operationManager = operationManager
        self.keystoreImportService = keystoreImportService
        self.supportedNetworks = supportedNetworks
        self.defaultNetwork = defaultNetwork
        self.cloudStorage = cloudStorage
    }

    private func setupKeystoreImportObserver() {
        keystoreImportService.add(observer: self)
        handleIfNeededKeystoreImport()
    }

    private func handleIfNeededKeystoreImport() {
        if let definition = keystoreImportService.definition {
            keystoreImportService.clear()
            do {
                let jsonData = try JSONEncoder().encode(definition)
                let info = try AccountImportJsonFactory().createInfo(from: definition)

                if let text = String(data: jsonData, encoding: .utf8) {
                    presenter.didSuggestKeystore(text: text, preferredInfo: info)
                }

            } catch {
                presenter.didReceiveAccountImport(error: error)
            }
        }
    }

    private func provideMetadata() {
        let metadata = AccountImportMetadata(availableSources: AccountImportSource.allCases,
                                             defaultSource: .mnemonic,
                                             availableNetworks: supportedNetworks,
                                             defaultNetwork: defaultNetwork,
                                             availableCryptoTypes: CryptoType.allCases,
                                             defaultCryptoType: .sr25519)

        presenter.didReceiveAccountImport(metadata: metadata)
    }

    func importAccountUsingOperation(_ importOperation: BaseOperation<AccountItem>) {}
    
    private func importAccount(_ account: OpenBackupAccount, password: String) {
        let backupAccountTypes = account.backupAccountType ?? []

        if backupAccountTypes.contains(.passphrase) {
            let request = AccountImportMnemonicRequest(mnemonic: account.passphrase ?? "",
                                                       username: account.name ?? "",
                                                       networkType: .sora,
                                                       derivationPath: account.substrateDerivationPath ?? "",
                                                       cryptoType: CryptoType(googleIdentifier: account.cryptoType ?? "SR25519"))
            importAccountWithMnemonic(request: request)
            return
        }
        
        
        if  backupAccountTypes.contains(.seed) {
            let request = AccountImportSeedRequest(seed: account.encryptedSeed?.substrateSeed ?? "",
                                                   username: account.name ?? "",
                                                   networkType: .sora,
                                                   derivationPath: account.substrateDerivationPath ?? "",
                                                   cryptoType: CryptoType(googleIdentifier: account.cryptoType ?? "SR25519"))
            importAccountWithSeed(request: request)
            return
        }
        
        if let substrateJson = account.json?.substrateJson {
            let request = AccountImportKeystoreRequest(keystore: substrateJson,
                                                       password: password,
                                                       username: account.name ?? "",
                                                       networkType: .sora,
                                                       cryptoType: CryptoType(googleIdentifier: account.cryptoType ?? "SR25519"))
            importAccountWithKeystore(request: request)
        }
        
        presenter.didReceiveAccountImport(error: ImportAccountError.unexpectedError)
    }
}

extension BaseAccountImportInteractor: AccountImportInteractorInputProtocol {
    func setup() {
        provideMetadata()
        setupKeystoreImportObserver()
    }

    func importAccountWithMnemonic(request: AccountImportMnemonicRequest) {
        guard let mnemonic = try? mnemonicCreator.mnemonic(fromList: request.mnemonic) else {
            presenter.didReceiveAccountImport(error: AccountCreateError.invalidMnemonicFormat)
            return
        }

        let creationRequest = AccountCreationRequest(username: request.username,
                                                     type: request.networkType,
                                                     derivationPath: request.derivationPath,
                                                     cryptoType: request.cryptoType)

        let accountOperation = accountOperationFactory.newAccountOperation(request: creationRequest,
                                                                           mnemonic: mnemonic)

        importAccountUsingOperation(accountOperation)
    }

    func importAccountWithSeed(request: AccountImportSeedRequest) {
        let operation = accountOperationFactory.newAccountOperation(request: request)
        importAccountUsingOperation(operation)
    }

    func importAccountWithKeystore(request: AccountImportKeystoreRequest) {
        let operation = accountOperationFactory.newAccountOperation(request: request)
        importAccountUsingOperation(operation)
    }

    func deriveMetadataFromKeystore(_ keystore: String) {
        if
            let data = keystore.data(using: .utf8),
            let definition = try? jsonDecoder.decode(KeystoreDefinition.self, from: data),
            let info = try? AccountImportJsonFactory().createInfo(from: definition) {

            presenter.didSuggestKeystore(text: keystore, preferredInfo: info)
        }
    }
    
    func importBackedupAccount(request: AccountImportBackedupRequest) {
        cloudStorage?.importBackupAccount(account: request.account, password: request.password) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let account):
                self.importAccount(account, password: request.password)
            case .failure(let error):
                self.presenter.didReceiveAccountImport(error: error)
            }
        }
    }
}

extension BaseAccountImportInteractor: KeystoreImportObserver {
    func didUpdateDefinition(from oldDefinition: KeystoreDefinition?) {
        handleIfNeededKeystoreImport()
    }
}
