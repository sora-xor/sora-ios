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
import SoraKeystore
import IrohaCrypto
import RobinHood

class AddAccountConfirmInteractor: BaseAccountConfirmInteractor {
    private(set) var settings: SelectedWalletSettingsProtocol
    let eventCenter: EventCenterProtocol

    private var currentOperation: Operation?

    init(request: AccountCreationRequest,
         mnemonic: IRMnemonicProtocol,
         accountOperationFactory: AccountOperationFactoryProtocol,
         accountRepository: AnyDataProviderRepository<AccountItem>,
         operationManager: OperationManagerProtocol,
         settings: SelectedWalletSettingsProtocol,
         eventCenter: EventCenterProtocol) {
        self.settings = settings
        self.eventCenter = eventCenter

        super.init(request: request,
                   mnemonic: mnemonic,
                   accountOperationFactory: accountOperationFactory,
                   accountRepository: accountRepository,
                   operationManager: operationManager)
    }

    override func createAccountUsingOperation(
        _ importOperation: BaseOperation<PreparedAccount>
    ) {
        guard currentOperation == nil else {
            return
        }
        let lifecycleCoordinator = WalletLifecycleCoordinator.shared
        let lifecycleOperation =
            lifecycleCoordinator.makeAcquireOperation()
        importOperation.addDependency(lifecycleOperation)
        currentOperation = importOperation
        let selectionEventCenter = eventCenter

        importOperation.completionBlock = { [weak self] in
            let leaseResult = Result {
                try lifecycleOperation.extractNoCancellableResultData()
            }
            let preparedResult = Result {
                try importOperation.extractNoCancellableResultData()
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
        operationManager.enqueue(operations: [
            importOperation,
        ],
                                 in: .sync)
    }
}
