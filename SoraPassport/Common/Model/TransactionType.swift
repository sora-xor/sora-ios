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
       case .reward, .slash, .extrinsic:
           return self.rawValue
       case .migration:
           return self.rawValue
       }
    }
}
