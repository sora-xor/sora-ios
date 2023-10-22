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
        let fetchOperation = repository.fetchOperation(by: address,
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
