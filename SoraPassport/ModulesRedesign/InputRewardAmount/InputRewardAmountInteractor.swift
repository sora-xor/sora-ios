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

import BigInt

protocol InputRewardAmountInteractorInputProtocol: AnyObject {
    func getBalance()

    func sendReferralBalanceRequest(with type: InputRewardAmountType, decimalBalance: Decimal)
}

protocol InputRewardAmountInteractorOutputProtocol: AnyObject {
    func received(_ balance: Decimal)
    func referralBalanceOperationReceived(with result: Result<String, Error>)
}

final class InputRewardAmountInteractor {
    weak var presenter: InputRewardAmountInteractorOutputProtocol?

    private var networkFacade: WalletNetworkOperationFactoryProtocol?
    private let operationFactory: ReferralsOperationFactoryProtocol
    private var feeAsset: AssetInfo

    init(networkFacade: WalletNetworkOperationFactoryProtocol,
         operationFactory: ReferralsOperationFactoryProtocol,
         feeAsset: AssetInfo) {
        self.networkFacade = networkFacade
        self.operationFactory = operationFactory
        self.feeAsset = feeAsset
    }
}

extension InputRewardAmountInteractor: InputRewardAmountInteractorInputProtocol {
    func getBalance() {
        if let operation = networkFacade?.fetchBalanceOperation([feeAsset.identifier]) {
            operation.targetOperation.completionBlock = { [weak self] in
                if let balance = try? operation.targetOperation.extractResultData(), let balance = balance?.first {
                    self?.presenter?.received(balance.balance.decimalValue)
                }
            }
            OperationManagerFacade.sharedManager.enqueue(operations: operation.allOperations, in: .transient)
        }
    }

    func sendReferralBalanceRequest(with type: InputRewardAmountType, decimalBalance: Decimal) {
        let balance = decimalBalance.toSubstrateAmount(precision: 18) ?? 0

        var operation = operationFactory.createExtrinsicReserveReferralBalanceOperation(with: balance)

        if type == .unbond {
            operation = operationFactory.createExtrinsicUnreserveReferralBalanceOperation(with: balance)
        }

        operation.completionBlock = { [weak self] in
            guard let result = operation.result else { return }
            self?.presenter?.referralBalanceOperationReceived(with: result)
        }

        OperationManagerFacade.sharedManager.enqueue(operations: [operation], in: .transient)
    }
}
