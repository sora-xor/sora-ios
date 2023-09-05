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
    
    private func handleResult(_ result: Result<AccountItem, Error>?) {
        switch result {
        case .success(let accountItem):
            settings.save(value: accountItem)
            eventCenter.notify(with: SelectedAccountChanged())

            presenter.didCompleteConfirmation(for: accountItem)
        case .failure(let error):
            presenter.didReceive(error: error)
        case .none:
            let error = BaseOperationError.parentOperationCancelled
            presenter.didReceive(error: error)
        }
    }
}

extension AccountCreateInteractor: AccountCreateInteractorInputProtocol {
    func setup() {
        do {
            let mnemonic = try mnemonicCreator.randomMnemonic(.entropy128)

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
        let operation = accountOperationFactory.newAccountOperation(request: request, mnemonic: mnemonic)
        guard currentOperation == nil else {
            return
        }

        let persistentOperation = accountRepository.saveOperation({
            let accountItem = try operation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            return [accountItem]
        }, { [] })

        persistentOperation.addDependency(operation)

        let connectionOperation: BaseOperation<AccountItem> = ClosureOperation {
            let accountItem = try operation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            return accountItem
        }

        connectionOperation.addDependency(persistentOperation)

        currentOperation = connectionOperation

        connectionOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.currentOperation = nil

                self?.handleResult(connectionOperation.result)
            }
        }

        operationManager.enqueue(operations: [operation, persistentOperation, connectionOperation], in: .sync)
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
