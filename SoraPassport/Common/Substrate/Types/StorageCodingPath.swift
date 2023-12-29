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
}
