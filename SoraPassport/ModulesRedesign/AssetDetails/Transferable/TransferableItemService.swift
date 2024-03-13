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
