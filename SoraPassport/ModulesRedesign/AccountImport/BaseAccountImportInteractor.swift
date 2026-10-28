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
import SSFUtils
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

    func importAccountUsingOperation(_ importOperation: BaseOperation<AccountItem>, completion: ((Result<AccountItem, Swift.Error>?) -> Void)?) {}
    
    func validateAccountUsingOperation(_ importOperation: BaseOperation<AccountItem>, completion: ((Result<AccountItem?, Swift.Error>?) -> Void)?) {}
    
    private func importAccount(_ account: OpenBackupAccount, password: String) {
        let backupAccountTypes = account.backupAccountType ?? []

        if backupAccountTypes.contains(.passphrase) {
            let request = AccountImportMnemonicRequest(mnemonic: account.passphrase ?? "",
                                                       username: account.name ?? "",
                                                       networkType: .sora,
                                                       derivationPath: account.substrateDerivationPath ?? "",
                                                       cryptoType: CryptoType(type: account.cryptoType ?? "SR25519"))
            importAccountWithMnemonic(request: request)
            return
        }
        
        
        if  backupAccountTypes.contains(.seed) {
            let request = AccountImportSeedRequest(seed: account.encryptedSeed?.substrateSeed ?? "",
                                                   username: account.name ?? "",
                                                   networkType: .sora,
                                                   derivationPath: account.substrateDerivationPath ?? "",
                                                   cryptoType: CryptoType(type: account.cryptoType ?? "SR25519"))
            importAccountWithSeed(request: request)
            return
        }
        
        if let substrateJson = account.json?.substrateJson {
            let request = AccountImportKeystoreRequest(keystore: substrateJson,
                                                       password: password,
                                                       username: account.name ?? "",
                                                       networkType: .sora,
                                                       cryptoType: CryptoType(type: account.cryptoType ?? "SR25519"))
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

    func importAccountWithMnemonic(request: AccountImportMnemonicRequest, completion: ((Result<AccountItem, Swift.Error>?) -> Void)?) {
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

        importAccountUsingOperation(accountOperation, completion: completion)
    }

    func importAccountWithSeed(request: AccountImportSeedRequest, completion: ((Result<AccountItem, Swift.Error>?) -> Void)?) {
        let operation = accountOperationFactory.newAccountOperation(request: request)
        importAccountUsingOperation(operation, completion: completion)
    }

    func importAccountWithKeystore(request: AccountImportKeystoreRequest, completion: ((Result<AccountItem, Swift.Error>?) -> Void)?){
        let operation = accountOperationFactory.newAccountOperation(request: request)
        importAccountUsingOperation(operation, completion: completion)
    }
    
    func validateAccountWithMnemonic(request: AccountImportMnemonicRequest, completion: ((Result<AccountItem?, Swift.Error>?) -> Void)?) {
        guard let mnemonic = try? mnemonicCreator.mnemonic(fromList: request.mnemonic) else {
            presenter.didReceiveAccountImport(error: AccountCreateError.invalidMnemonicFormat)
            return
        }
        
        let creationRequest = AccountCreationRequest(username: request.username,
                                                     type: request.networkType,
                                                     derivationPath: request.derivationPath,
                                                     cryptoType: request.cryptoType)
        
        let operation = accountOperationFactory.newAccountOperation(request: creationRequest,
                                                                    mnemonic: mnemonic)
        
        validateAccountUsingOperation(operation, completion: completion)
    }
    
    func validateAccountWithSeed(request: AccountImportSeedRequest, completion: ((Result<AccountItem?, Swift.Error>?) -> Void)?) {
        let operation = accountOperationFactory.newAccountOperation(request: request)
        validateAccountUsingOperation(operation, completion: completion)
    }
    
    func validateAccountWithKeystore(request: AccountImportKeystoreRequest, completion: ((Result<AccountItem?, Swift.Error>?) -> Void)?) {
        let operation = accountOperationFactory.newAccountOperation(request: request)
        validateAccountUsingOperation(operation, completion: completion)
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
        Task { [weak self] in
            guard let cloudStorage = self?.cloudStorage else { return }
            do {
                let account = try await cloudStorage.importBackup(account: request.account, password: request.password)
                self?.importAccount(account, password: request.password)
            } catch {
                self?.presenter.didReceiveAccountImport(error: error)
            }
        }
    }
}

extension BaseAccountImportInteractor: KeystoreImportObserver {
    func didUpdateDefinition(from oldDefinition: KeystoreDefinition?) {
        handleIfNeededKeystoreImport()
    }
}
