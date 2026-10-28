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
import Combine
import BigInt


final class TransferableItemService {
    @Published var balanceAmount: Decimal?
    @Published var fiatBalanceText: String?
    
    @Published var publishedFrozenAmount: Amount?
    @Published var frozenFiat: String?
    
    var referralBalance: Decimal?
    var balanceContext: BalanceContext?
    var usdPrice: Decimal = Decimal(0)
    
    private let assetInfo: AssetInfo
    private var assetsProvider: AssetProviderProtocol
    private let referralFactory: ReferralsOperationFactoryProtocol

    init(assetInfo: AssetInfo,
         eventCenter: EventCenterProtocol,
         assetsProvider: AssetProviderProtocol,
         referralFactory: ReferralsOperationFactoryProtocol) {
        self.assetInfo = assetInfo
        self.assetsProvider = assetsProvider
        self.referralFactory = referralFactory
        self.assetsProvider.add(observer: self)
    }
    
    func setup(with balance: BalanceData) {
        Task {
            referralBalance = await assetInfo.isFeeAsset ? getReferralBalance() : nil
            balanceContext = BalanceContext(context: balance.context ?? [:])
            
            balanceAmount = balance.balance.decimalValue
            fiatBalanceText = (balance.balance.decimalValue * usdPrice).priceText()
            
            let frozen = balanceContext?.frozen ?? Decimal(0)
            let referral = referralBalance ?? Decimal(0)
            let frozenAmount = Amount(value: frozen + referral)
            
            publishedFrozenAmount = frozenAmount
            frozenFiat = (frozenAmount.decimalValue * usdPrice).priceText()
        }
    }
    
    func getReferralBalance() async -> Decimal? {
        return await withCheckedContinuation { continuation in
            guard let operation = referralFactory.createReferrerBalancesOperation() else { return }
            OperationManagerFacade.sharedManager.enqueue(operations: [operation], in: .transient)
            
            operation.completionBlock = {
                do {
                    guard let data = try operation.extractResultData()?.underlyingValue else {
                        continuation.resume(with: .success(nil))
                        return
                    }
                    let referralBalance = Decimal.fromSubstrateAmount(data.value, precision: 18) ?? Decimal(0)
                    continuation.resume(with: .success(referralBalance))
                } catch {
                    Logger.shared.error("Request unsuccessful")
                }
            }
        }
    }
}

extension TransferableItemService: AssetProviderObserverProtocol {
    func processBalance(data: [BalanceData]) {
        print("balancedata = \(data)")
        guard let assetBalance = data.first(where: { $0.identifier == assetInfo.assetId }) else { return }
        print("balancedata = \(data)")
        setup(with: assetBalance)
    }
}
