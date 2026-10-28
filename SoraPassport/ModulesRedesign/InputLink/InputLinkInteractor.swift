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

protocol InputLinkInteractorInputProtocol: AnyObject {
    func sendSetReferrerRequest(with referrerAddress: String)
    func isCurrentUserAddress(with address: String) -> Bool
    func getAccountId(from address: String) -> Data?
}

protocol InputLinkInteractorOutputProtocol: AnyObject {
    func setReferralRequestReceived(with result: Result<String, Swift.Error>)
}

final class InputLinkInteractor {
    weak var presenter: InputLinkInteractorOutputProtocol?

    private let operationManager: OperationManager
    private let operationFactory: ReferralsOperationFactoryProtocol
    private let addressFactory: SS58AddressFactory
    private let selectedAccountAddress: String

    init(operationManager: OperationManager,
         operationFactory: ReferralsOperationFactoryProtocol,
         addressFactory: SS58AddressFactory,
         selectedAccountAddress: String) {
        self.operationManager = operationManager
        self.operationFactory = operationFactory
        self.addressFactory = addressFactory
        self.selectedAccountAddress = selectedAccountAddress
    }
}

extension InputLinkInteractor: InputLinkInteractorInputProtocol {
    func sendSetReferrerRequest(with referrerAddress: String) {

        let operation = operationFactory.createExtrinsicSetReferrerOperation(with: referrerAddress)

        operation.completionBlock = { [weak self] in
            guard let result = operation.result else {
                self?.presenter?.setReferralRequestReceived(with: .failure(BaseOperationError.parentOperationCancelled))
                return
            }
            self?.presenter?.setReferralRequestReceived(with: result)
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }

    func getAccountId(from address: String) -> Data? {
        guard let addressType = try? addressFactory.extractAddressType(from: address),
              let accountId = try? addressFactory.accountId(fromAddress: address, type: addressType) else {
            return nil
        }

        return accountId
    }

    func isCurrentUserAddress(with address: String) -> Bool {
        guard let selectedId = getAccountId(from: selectedAccountAddress),
              let candidateId = getAccountId(from: address) else { return false }
        return selectedId == candidateId
    }
}
