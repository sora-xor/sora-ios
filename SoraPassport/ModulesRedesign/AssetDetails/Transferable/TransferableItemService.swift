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
    /// The balance could not be read. While this is so nothing above is
    /// published: the amounts would be those of a placeholder.
    @Published private(set) var balanceUnavailable = false
    
    var referralBalance: Decimal?
    var balanceContext: BalanceContext?
    /// `nil` when the price is not known; the fiat texts are then empty.
    var usdPrice: Decimal?
    
    private let assetInfo: AssetInfo
    private var assetsProvider: AssetProviderProtocol
    private let referralFactory: ReferralsOperationFactoryProtocol
    private let stateLock = NSLock()
    /// Each setup has a number. The one that looks up the referral balance
    /// publishes only if no later setup (or "unavailable") came meanwhile.
    private var setupNumber = 0

    private func nextSetup() -> Int {
        stateLock.lock()
        defer { stateLock.unlock() }
        setupNumber += 1
        return setupNumber
    }

    private func isCurrent(_ number: Int) -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return setupNumber == number
    }

    init(assetInfo: AssetInfo,
         eventCenter: EventCenterProtocol,
         assetsProvider: AssetProviderProtocol,
         referralFactory: ReferralsOperationFactoryProtocol) {
        self.assetInfo = assetInfo
        self.assetsProvider = assetsProvider
        self.referralFactory = referralFactory
        self.assetsProvider.add(observer: self)
    }
    
    /// The balance could not be read: say so, and publish no amount, value
    /// or frozen part worked out from a placeholder.
    func setupUnavailable() {
        _ = nextSetup()
        balanceUnavailable = true
    }

    func setup(with balance: BalanceData) {
        let number = nextSetup()
        Task {
            let readReferralBalance = await assetInfo.isFeeAsset ? getReferralBalance() : nil
            guard isCurrent(number) else { return }
            referralBalance = readReferralBalance
            balanceContext = BalanceContext(context: balance.context ?? [:])
            
            balanceUnavailable = false
            balanceAmount = balance.balance.decimalValue
            fiatBalanceText = WalletUX.balanceFiatText(amount: balance.balance.decimalValue, price: usdPrice)
            
            let frozen = balanceContext?.frozen ?? Decimal(0)
            let referral = referralBalance ?? Decimal(0)
            let frozenAmount = Amount(value: frozen + referral)
            
            publishedFrozenAmount = frozenAmount
            frozenFiat = WalletUX.balanceFiatText(amount: frozenAmount.decimalValue, price: usdPrice)
        }
    }
    
    func getReferralBalance() async -> Decimal? {
        return await withCheckedContinuation { continuation in
            guard let operation = referralFactory.createReferrerBalancesOperation() else {
                continuation.resume(returning: nil)
                return
            }
            
            operation.completionBlock = {
                do {
                    guard let data = try operation.extractResultData()?.underlyingValue else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let referralBalance = Decimal.fromSubstrateAmount(data.value, precision: 18) ?? Decimal(0)
                    continuation.resume(returning: referralBalance)
                } catch {
                    Logger.shared.error("Request unsuccessful")
                    continuation.resume(returning: nil)
                }
            }
            OperationManagerFacade.sharedManager.enqueue(operations: [operation], in: .transient)
        }
    }
}

extension TransferableItemService: AssetProviderObserverProtocol {
    func processBalance(data: [BalanceData]) {
        if let assetBalance = data.first(where: { $0.identifier == assetInfo.assetId }) {
            // Also the way back: a balance that could not be read before
            // and is read now replaces "Balance unavailable".
            setup(with: assetBalance)
        } else if assetsProvider
            .unavailableBalanceAssetIds(among: [assetInfo.assetId])
            .contains(assetInfo.assetId) {
            setupUnavailable()
        }
    }
}
