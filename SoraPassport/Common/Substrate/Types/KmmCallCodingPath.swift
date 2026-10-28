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

struct KmmCallCodingPath: Equatable, Codable {
    let moduleName: String
    let callName: String
}

extension KmmCallCodingPath {
    static var transfer: KmmCallCodingPath {
        KmmCallCodingPath(moduleName: "assets", callName: "transfer")
    }
    
    static var adarTransfer: KmmCallCodingPath {
        KmmCallCodingPath(moduleName: "assets", callName: "Transfer")
    }

    static var transferKeepAlive: KmmCallCodingPath {
        KmmCallCodingPath(moduleName: "assets", callName: "transferKeepAlive")
    }

    static var swap: KmmCallCodingPath {
        KmmCallCodingPath(moduleName: "liquidityProxy", callName: "swap")
    }

    static var migration: KmmCallCodingPath {
        KmmCallCodingPath(moduleName: "irohaMigration", callName: "migrate")
    }
    static var depositLiquidity: KmmCallCodingPath {
        KmmCallCodingPath(moduleName: "poolXYK", callName: "depositLiquidity")
    }

    static var withdrawLiquidity: KmmCallCodingPath {
        KmmCallCodingPath(moduleName: "poolXYK", callName: "withdrawLiquidity")
    }

    static var setReferral: KmmCallCodingPath {
        KmmCallCodingPath(moduleName: "referrals", callName: "setReferrer")
    }

    static var bondReferralBalance: KmmCallCodingPath {
        KmmCallCodingPath(moduleName: "referrals", callName: "reserve")
    }

    static var unbondReferralBalance: KmmCallCodingPath {
        KmmCallCodingPath(moduleName: "referrals", callName: "unreserve")
    }
    
    static var batchUtility: KmmCallCodingPath {
        KmmCallCodingPath(moduleName: "utility", callName: "batch")
    }
    
    static var batchAllUtility: KmmCallCodingPath {
        KmmCallCodingPath(moduleName: "utility", callName: "batchAll")
    }
    
    static var getRewards: KmmCallCodingPath {
        KmmCallCodingPath(moduleName: "demeterFarmingPlatform", callName: "getRewards")
    }
    
    static var farmDeposit: KmmCallCodingPath {
        KmmCallCodingPath(moduleName: "demeterFarmingPlatform", callName: "deposit")
    }
    
    static var farmWithdraw: KmmCallCodingPath {
        KmmCallCodingPath(moduleName: "demeterFarmingPlatform", callName: "withdraw")
    }


    var isTransfer: Bool {
        [.transfer, .transferKeepAlive, .adarTransfer].contains(self)
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
    
    var isClaimReward: Bool {
        [.getRewards].contains(self)
    }
    
    var isDepositFarmLiquidity: Bool {
        [.farmDeposit].contains(self)
    }

    var isWithdrawFarmLiquidity: Bool {
        [.farmWithdraw].contains(self)
    }
}
