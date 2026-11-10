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

import Foundation
import RobinHood
import IrohaCrypto

protocol WalletContactOperationFactoryProtocol {
    func saveByAddressOperation(_ address: String) -> CompoundOperationWrapper<Void>
    func fetchContactsOperation() -> CompoundOperationWrapper<[ContactItem]>
}

final class WalletContactOperationFactory {
    let repository: AnyDataProviderRepository<ContactItem>
    let targetAddress: String

    init(storageFacade: StorageFacadeProtocol, targetAddress: String) {
        let filter = NSPredicate.filterContactsByTarget(address: targetAddress)
        let repository: CoreDataRepository<ContactItem, CDContactItem> =
            storageFacade.createRepository(filter: filter,
                                           sortDescriptors: [NSSortDescriptor.contactsByTime])

        self.repository = AnyDataProviderRepository(repository)
        self.targetAddress = targetAddress
    }
}

extension WalletContactOperationFactory: WalletContactOperationFactoryProtocol {
    func saveByAddressOperation(_ address: String) -> CompoundOperationWrapper<Void> {
        let identifier = ContactItem(peerAddress: address, peerName: nil,
                                     targetAddress: targetAddress, updatedAt: 0).identifier
        let fetchOperation = repository.fetchOperation(by: identifier,
                                                       options: RepositoryFetchOptions())

        let currentTargetAddress = targetAddress
        let saveOperation = repository.saveOperation({
            let existingContact = try fetchOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            let contactItem = ContactItem(peerAddress: address,
                                          peerName: existingContact?.peerName,
                                          targetAddress: currentTargetAddress,
                                          updatedAt: Int64(Date().timeIntervalSince1970))

            return [contactItem]
        }, { [] })

        saveOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: saveOperation,
                                        dependencies: [fetchOperation])
    }

    func fetchContactsOperation() -> CompoundOperationWrapper<[ContactItem]> {
        let operation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        return CompoundOperationWrapper(targetOperation: operation)
    }
}
