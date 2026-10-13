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
        let operation = accountOperationFactory.prepareAccountOperation(
            request: request,
            mnemonic: mnemonic
        )
        guard currentOperation == nil else {
            return
        }
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
        let entropy = try keystore.fetchEntropyForAddress(account.address)
        let mnemonic = try mnemonicCreator.mnemonic(fromEntropy: entropy!)
        return mnemonic
    }

    func setup() {
        do {
            let mnemonic = try loadPhrase()

            let metadata = AccountCreationMetadata(mnemonic: mnemonic.allWords(),
                                                   availableNetworks: Chain.allCases,
                                                   defaultNetwork: .sora,
                                                   availableCryptoTypes: CryptoType.allCases,
                                                   defaultCryptoType: .sr25519)
            presenter.didReceive(metadata: metadata)
        } catch {
            presenter.didReceiveMnemonicGeneration(error: error)
        }
    }
    
    func skipConfirmation(request: AccountCreationRequest, mnemonic: IRMnemonicProtocol) {}
}
