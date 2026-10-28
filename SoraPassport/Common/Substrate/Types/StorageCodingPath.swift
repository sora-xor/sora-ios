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

public enum StorageCodingPath: Equatable, CaseIterable {
    public var moduleName: String {
        path.moduleName
    }

    public var itemName: String {
        path.itemName
    }

    public var path: (moduleName: String, itemName: String) {
        switch self {
        case .account:
            return (moduleName: "System", itemName: "Account")
        case .tokens:
            return (moduleName: "Tokens", itemName: "Accounts")
        case .events:
            return (moduleName: "System", itemName: "Events")
        case .activeEra:
            return (moduleName: "Staking", itemName: "ActiveEra")
        case .erasStakers:
            return (moduleName: "Staking", itemName: "ErasStakers")
        case .erasPrefs:
            return (moduleName: "Staking", itemName: "ErasValidatorPrefs")
        case .validatorPrefs:
            return (moduleName: "Staking", itemName: "Validators")
        case .totalIssuance:
            return (moduleName: "Balances", itemName: "TotalIssuance")
        case .identity:
            return (moduleName: "Identity", itemName: "IdentityOf")
        case .superIdentity:
            return (moduleName: "Identity", itemName: "SuperOf")
        case .slashingSpans:
            return (moduleName: "Staking", itemName: "SlashingSpans")
        case .unappliedSlashes:
            return (moduleName: "Staking", itemName: "UnappliedSlashes")
        case .xstPoolFee:
            return (moduleName: "xstPool", itemName: "baseFee")
        case .demeterFarmingUserInfo:
            return (moduleName: "DemeterFarmingPlatform", itemName: "UserInfos")
        case .demeterFarmingPools:
            return (moduleName: "DemeterFarmingPlatform", itemName: "Pools")
        case .demeterFarmingTokenInfo:
            return (moduleName: "DemeterFarmingPlatform", itemName: "TokenInfos")
        case .userPools:
            return (moduleName: "PoolXYK", itemName: "AccountPools")
        case .polkamarktMarkets:
            return (moduleName: "Polkamarkt", itemName: "Markets")
        }
    }
    
    case account
    case tokens
    case events
    case activeEra
    case erasStakers
    case erasPrefs
    case validatorPrefs
    case totalIssuance
    case identity
    case superIdentity
    case slashingSpans
    case unappliedSlashes
    case xstPoolFee
    case demeterFarmingUserInfo
    case demeterFarmingPools
    case demeterFarmingTokenInfo
    case userPools
    case polkamarktMarkets
}
