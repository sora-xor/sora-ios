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

enum TransactionType: String, CaseIterable {
    case incoming = "INCOMING"
    case outgoing = "OUTGOING"
    case reward = "REWARD"
    case slash = "SLASH"
    case swap = "SWAP"
    case migration = "MIGRATION"
    case extrinsic = "EXTRINSIC"
    case liquidityAdd = "Deposit"
    case liquidityAddToExistingPoolFirstTime = "DepositToExistingPoolFirstTime"
    case liquidityAddNewPool = "DepositCreatePair"
    case liquidityRemoval = "Removal"
    case referral = "Referral Program"
    case demeterClaimReward = "claim_reward"
    case demeterDeposit = "demeter_deposit"
    case demeterWithdraw = "demeter_withdraw"
}

extension TransactionLiquidityType {
    var transactionType: TransactionType {
        switch self {
        case .deposit:
            return .liquidityAdd
        case .removal:
            return .liquidityRemoval
        }
    }
}

import SoraFoundation
extension TransactionType {
    var localizedName: String {
       let locale = LocalizationManager.shared.selectedLocale
       switch self {
       case .incoming:
           return R.string.localizable.historyReceive(preferredLanguages: locale.rLanguages).uppercased()
       case .outgoing:
           return R.string.localizable.historySend(preferredLanguages: locale.rLanguages).uppercased()
       case .swap:
           return R.string.localizable.historySwap(preferredLanguages: locale.rLanguages).uppercased()
       case .liquidityAdd, .liquidityAddToExistingPoolFirstTime, .liquidityAddNewPool:
           return R.string.localizable.commonDeposit(preferredLanguages: locale.rLanguages).uppercased()
       case .liquidityRemoval:
           return R.string.localizable.commonRemove(preferredLanguages: locale.rLanguages).uppercased()
       case .referral:
           return R.string.localizable.referralToolbarTitle(preferredLanguages: locale.rLanguages).uppercased()
       case .reward, .slash, .extrinsic, .demeterDeposit, .demeterWithdraw, .demeterClaimReward:
           return self.rawValue
       case .migration:
           return self.rawValue
       }
    }
}
