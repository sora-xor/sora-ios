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
