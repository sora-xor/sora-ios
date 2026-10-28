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
//
final class AddAccountImportInteractor: BaseAccountImportInteractor {
    private(set) var settings: SelectedWalletSettingsProtocol
    let eventCenter: EventCenterProtocol
    private let lifecycleCoordinator: WalletLifecycleCoordinator

    init(accountOperationFactory: AccountOperationFactoryProtocol,
         accountRepository: AnyDataProviderRepository<AccountItem>,
         operationManager: OperationManagerProtocol,
         settings: SelectedWalletSettingsProtocol,
         keystoreImportService: KeystoreImportServiceProtocol,
         eventCenter: EventCenterProtocol,
         cloudStorage: CloudStorageServiceProtocol? = nil,
         lifecycleCoordinator: WalletLifecycleCoordinator = .shared) {
        self.settings = settings
        self.eventCenter = eventCenter
        self.lifecycleCoordinator = lifecycleCoordinator

        super.init(accountOperationFactory: accountOperationFactory,
                   accountRepository: accountRepository,
                   operationManager: operationManager,
                   keystoreImportService: keystoreImportService,
                   supportedNetworks: Chain.allCases,
                   defaultNetwork: Chain.sora,
                   cloudStorage: cloudStorage)
    }

    override func importAccountUsingOperation(
        _ importOperation: BaseOperation<PreparedAccount>,
        completion: ((Result<AccountItem, Swift.Error>?) -> Void)?
    ) {
        let lifecycleCoordinator = self.lifecycleCoordinator
        let lifecycleOperation =
            lifecycleCoordinator.makeAcquireOperation()
        importOperation.addDependency(lifecycleOperation)
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
                if try self.requestExplicitCredentialRepairIfNeeded(prepared, lifecycleLease: lifecycleLease,
                    eventCenter: selectionEventCenter, completion: completion) { return }
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
                        switch result {
                        case let .success(accountItem):
                            selectionEventCenter.notify(
                                with: SelectedAccountChanged(),
                                completionOnMain: { [weak self] in
                                    self?.presenter?
                                        .didCompleteAccountImport()
                                    completion?(.success(accountItem))
                                }
                            )
                        case let .failure(error):
                            self?.presenter?
                                .didReceiveAccountImport(error: error)
                            completion?(.failure(error))
                        }
                    }
                }
            } catch {
                try? preparedResult.get().discard()
                try? leaseResult.get().release()
                DispatchQueue.main.async { [weak self] in
                    self?.presenter?
                        .didReceiveAccountImport(error: error)
                    completion?(.failure(error))
                }
            }
        }

        lifecycleCoordinator.enqueueOwnedAcquireOperation(
            lifecycleOperation
        )
        operationManager.enqueue(
            operations: [importOperation],
            in: .sync
        )
    }
    
    override func validateAccountUsingOperation(
        _ importOperation: BaseOperation<PreparedAccount>,
        completion: ((Result<AccountItem?, Error>?) -> Void)?
    ) {
        let lifecycleCoordinator = self.lifecycleCoordinator
        let lifecycleOperation =
            lifecycleCoordinator.makeAcquireOperation()
        importOperation.addDependency(lifecycleOperation)
        importOperation.completionBlock = { [weak self] in
            do {
                let lifecycleLease = try lifecycleOperation
                    .extractNoCancellableResultData()
                let prepared = try importOperation
                    .extractNoCancellableResultData()
                guard let self else {
                    prepared.discard()
                    lifecycleLease.release()
                    return
                }
                let checkOperation = self.accountRepository.fetchOperation(
                    by: prepared.account.address,
                    options: RepositoryFetchOptions()
                )
                checkOperation.completionBlock = {
                    defer {
                        prepared.discard()
                        lifecycleLease.release()
                    }
                    let result: Result<AccountItem?, Error>
                    do {
                        result = .success(try self.existingAccountRequiringRepair(
                            checkOperation.extractNoCancellableResultData(), prepared: prepared, selection: self.settings))
                    } catch {
                        result = .failure(error)
                    }
                    DispatchQueue.main.async {
                        completion?(result)
                    }
                }
                self.operationManager.enqueue(
                    operations: [checkOperation],
                    in: .sync
                )
            } catch {
                (try? importOperation
                    .extractNoCancellableResultData())?.discard()
                (try? lifecycleOperation
                    .extractNoCancellableResultData())?.release()
                DispatchQueue.main.async { [weak self] in
                    self?.presenter?
                        .didReceiveAccountImport(error: error)
                    completion?(.failure(error))
                }
            }
        }
        
        lifecycleCoordinator.enqueueOwnedAcquireOperation(
            lifecycleOperation
        )
        operationManager.enqueue(
            operations: [importOperation],
            in: .sync
        )
    }
}
