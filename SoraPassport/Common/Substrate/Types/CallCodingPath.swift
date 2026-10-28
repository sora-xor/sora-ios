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

enum CallCodingPath: Equatable, Codable, CaseIterable {
    static var allCases: [CallCodingPath] {
        [
            .transfer,
            .transferKeepAlive,
            .swap,
            .migration,
            .depositLiquidity,
            .withdrawLiquidity,
            .setReferral,
            .bondReferralBalance,
            .unbondReferralBalance
        ]
    }

    var isTransfer: Bool {
        [.transfer, .transferKeepAlive].contains(self)
    }

    var isSwap: Bool {
        [.swap].contains(self)
    }

    var isMigration: Bool {
        [.migration].contains(self)
    }

    var isDepositLiquidity: Bool {
        [.depositLiquidity].contains(self)
    }

    var isWithdrawLiquidity: Bool {
        [.withdrawLiquidity].contains(self)
    }

    var isReferral: Bool {
        [.setReferral, .bondReferralBalance, .unbondReferralBalance].contains(self)
    }

    var moduleName: String {
        path.moduleName
    }

    var callName: String {
        path.callName
    }

    var path: (moduleName: String, callName: String) {
        switch self {
        case .transfer:
            return (moduleName: "Assets", callName: "transfer")
        case .transferKeepAlive:
            return (moduleName: "Assets", callName: "transfer_keep_alive")
        case .swap:
            return (moduleName: "LiquidityProxy", callName: "swap")
        case .migration:
            return (moduleName: "IrohaMigration", callName: "migrate")
        case .depositLiquidity:
            return (moduleName: "PoolXYK", callName: "deposit_liquidity")
        case .withdrawLiquidity:
            return (moduleName: "PoolXYK", callName: "withdraw_liquidity")
        case .setReferral:
            return (moduleName: "Referrals", callName: "set_referrer")
        case .bondReferralBalance:
            return (moduleName: "Referrals", callName: "reserve")
        case .unbondReferralBalance:
            return (moduleName: "Referrals", callName: "unreserve")
        case let .fromInit(moduleName, callName):
            return (moduleName: moduleName, callName: callName)
        }
    }
    
    init(moduleName: String, callName: String) {
        self = .fromInit(moduleName: moduleName, callName: callName)
    }
    
    case fromInit(moduleName: String, callName: String)
    case transfer
    case transferKeepAlive
    case swap
    case migration
    case depositLiquidity
    case withdrawLiquidity
    case setReferral
    case bondReferralBalance
    case unbondReferralBalance
}
