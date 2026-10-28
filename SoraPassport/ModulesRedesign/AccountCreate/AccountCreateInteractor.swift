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
import RobinHood
import SoraKeystore
import SSFCloudStorage

final class AccountCreateInteractor {
    weak var presenter: AccountCreateInteractorOutputProtocol!

    let mnemonicCreator: IRMnemonicCreatorProtocol
    let supportedNetworkTypes: [Chain]
    let defaultNetwork: Chain
    let accountOperationFactory: AccountOperationFactoryProtocol
    let accountRepository: AnyDataProviderRepository<AccountItem>
    let settings: SelectedWalletSettingsProtocol
    let eventCenter: EventCenterProtocol
    let operationManager: OperationManagerProtocol = OperationManager()
    var cloudStorageService: CloudStorageServiceProtocol?
    private var currentOperation: Operation?

    init(mnemonicCreator: IRMnemonicCreatorProtocol,
         supportedNetworkTypes: [Chain],
         defaultNetwork: Chain,
         accountOperationFactory: AccountOperationFactoryProtocol,
         accountRepository: AnyDataProviderRepository<AccountItem>,
         settings: SelectedWalletSettingsProtocol,
         eventCenter: EventCenterProtocol,
         cloudStorageService: CloudStorageServiceProtocol) {
        self.mnemonicCreator = mnemonicCreator
        self.supportedNetworkTypes = supportedNetworkTypes
        self.defaultNetwork = defaultNetwork
        self.accountOperationFactory = accountOperationFactory
        self.accountRepository = accountRepository
        self.settings = settings
        self.cloudStorageService = cloudStorageService
        self.eventCenter = eventCenter
    }
    
}

extension AccountCreateInteractor: AccountCreateInteractorInputProtocol {
    func setup() {
        do {
            // New wallets use 24 words. Existing 12/24-word imports and every
            // legacy account keep their original entropy and derivation.
            let mnemonic = try mnemonicCreator.randomMnemonic(.entropy256)

            let metadata = AccountCreationMetadata(mnemonic: mnemonic.allWords(),
                                                   availableNetworks: supportedNetworkTypes,
                                                   defaultNetwork: defaultNetwork,
                                                   availableCryptoTypes: CryptoType.allCases,
                                                   defaultCryptoType: .sr25519)
            presenter.didReceive(metadata: metadata)
        } catch {
            presenter.didReceiveMnemonicGeneration(error: error)
        }
    }
    
    func skipConfirmation(request: AccountCreationRequest,
                          mnemonic: IRMnemonicProtocol) {
        guard currentOperation == nil else {
            return
        }
        let operation = accountOperationFactory.prepareAccountOperation(
            request: request,
            mnemonic: mnemonic
        )
        let lifecycleCoordinator = WalletLifecycleCoordinator.shared
        let lifecycleOperation =
            lifecycleCoordinator.makeAcquireOperation()
        operation.addDependency(lifecycleOperation)

        currentOperation = operation
        let selectionEventCenter = eventCenter

        operation.completionBlock = { [weak self] in
            let leaseResult = Result {
                try lifecycleOperation.extractNoCancellableResultData()
            }
            let preparedResult = Result {
                try operation.extractNoCancellableResultData()
            }
            guard let self else {
                try? preparedResult.get().discard()
                try? leaseResult.get().release()
                return
            }
            do {
                let lifecycleLease = try leaseResult.get()
                let prepared = try preparedResult.get()
                self.settings.performInsertAndSelect(
                    prepared: prepared,
                    persistSecrets: {
                        try self.accountOperationFactory
                            .persistPreparedAccount(prepared)
                    },
                    lifecycleLease: lifecycleLease
                ) { [weak self] result in
                    lifecycleLease.release()
                    DispatchQueue.main.async {
                        self?.currentOperation = nil
                        switch result {
                        case let .success(accountItem):
                            selectionEventCenter.notify(
                                with: SelectedAccountChanged(),
                                completionOnMain: { [weak self] in
                                    self?.presenter?
                                        .didCompleteConfirmation(
                                            for: accountItem
                                        )
                                }
                            )
                        case let .failure(error):
                            self?.presenter?.didReceive(error: error)
                        }
                    }
                }
            } catch {
                try? preparedResult.get().discard()
                try? leaseResult.get().release()
                DispatchQueue.main.async { [weak self] in
                    self?.currentOperation = nil
                    self?.presenter?.didReceive(error: error)
                }
            }
        }

        lifecycleCoordinator.enqueueOwnedAcquireOperation(
            lifecycleOperation
        )
        operationManager.enqueue(
            operations: [
                operation,
            ],
            in: .sync
        )
    }
}

class AccountBackupInteractor {
    weak var presenter: AccountCreateInteractorOutputProtocol!

    let keystore: KeystoreProtocol
    let mnemonicCreator: IRMnemonicCreatorProtocol
    let account: AccountItem
    var cloudStorageService: CloudStorageServiceProtocol?

    init(keystore: KeystoreProtocol,
         mnemonicCreator: IRMnemonicCreatorProtocol,
         account: AccountItem) {
        self.keystore = keystore
        self.mnemonicCreator = mnemonicCreator
        self.account = account
    }
}

extension AccountBackupInteractor: AccountCreateInteractorInputProtocol {
    private func loadPhrase() throws -> IRMnemonicProtocol {
        var backup = try WalletBackupMaterial.load(for: account, keystore: keystore)
        defer { backup.wipe() }
        guard let entropy = backup.entropy else { throw WalletBackupMaterial.Failure.noMatchingPhrase }
        presenter.didReceive(backupDerivationPath: backup.derivationPath ?? "")
        let mnemonic = try mnemonicCreator.mnemonic(fromEntropy: entropy)
        return mnemonic
    }

    func setup() {
        do {
            let mnemonic = try loadPhrase()

            let metadata = AccountCreationMetadata(mnemonic: mnemonic.allWords(),
                                                   availableNetworks: Chain.allCases,
                                                   defaultNetwork: .sora,
                                                   availableCryptoTypes: CryptoType.allCases,
                                                   defaultCryptoType: account.cryptoType)
            presenter.didReceive(metadata: metadata)
        } catch {
            presenter.didReceiveMnemonicGeneration(error: error)
        }
    }
    
    func skipConfirmation(request: AccountCreationRequest, mnemonic: IRMnemonicProtocol) {}
}
