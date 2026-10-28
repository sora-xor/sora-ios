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
import SSFUtils

extension RuntimeCall {
    static func bond(_ args: BondCall) -> RuntimeCall<BondCall> {
        RuntimeCall<BondCall>(moduleName: "Staking", callName: "bond", args: args)
    }

    static func nominate(_ args: NominateCall) -> RuntimeCall<NominateCall> {
        RuntimeCall<NominateCall>(moduleName: "Staking", callName: "nominate", args: args)
    }

    static func migrate(_ args: MigrateCall) -> RuntimeCall<MigrateCall> {
        RuntimeCall<MigrateCall>(moduleName: "IrohaMigration", callName: "migrate", args: args)
    }

    static func transfer(_ args: SoraTransferCall) -> RuntimeCall<SoraTransferCall> {
        RuntimeCall<SoraTransferCall>(moduleName: "Assets", callName: "transfer", args: args)
    }

    static func swap(_ args: SwapCall) -> RuntimeCall<SwapCall> {
        RuntimeCall<SwapCall>(moduleName: "LiquidityProxy", callName: "swap", args: args)
    }

    static func register(_ args: PairRegisterCall) -> RuntimeCall<PairRegisterCall> {
        RuntimeCall<PairRegisterCall>(moduleName: "TradingPair", callName: "register", args: args)
    }

    static func initializePool(_ args: InitializePoolCall) -> RuntimeCall<InitializePoolCall> {
        RuntimeCall<InitializePoolCall>(moduleName: "PoolXYK", callName: "initialize_pool", args: args)
    }

    static func depositLiquidity(_ args: DepositLiquidityCall) -> RuntimeCall<DepositLiquidityCall> {
        RuntimeCall<DepositLiquidityCall>(moduleName: "PoolXYK", callName: "deposit_liquidity", args: args)
    }

    static func withdrawLiquidity(_ args: WithdrawLiquidityCall) -> RuntimeCall<WithdrawLiquidityCall> {
        RuntimeCall<WithdrawLiquidityCall>(moduleName: "PoolXYK", callName: "withdraw_liquidity", args: args)
    }

    static func setReferrer(_ args: SetReferrerCall) -> RuntimeCall<SetReferrerCall> {
        RuntimeCall<SetReferrerCall>(moduleName: "Referrals", callName: "set_referrer", args: args)
    }

    static func reserveReferralBalance(_ args: ReferralBalanceCall) -> RuntimeCall<ReferralBalanceCall> {
        RuntimeCall<ReferralBalanceCall>(moduleName: "Referrals", callName: "reserve", args: args)
    }

    static func unreserveReferralBalance(_ args: ReferralBalanceCall) -> RuntimeCall<ReferralBalanceCall> {
        RuntimeCall<ReferralBalanceCall>(moduleName: "Referrals", callName: "unreserve", args: args)
    }
    
    static func claimRewardDemeter(_ args: DemeterFarmingClaimRewardCall) -> RuntimeCall<DemeterFarmingClaimRewardCall> {
        RuntimeCall<DemeterFarmingClaimRewardCall>(moduleName: "DemeterFarmingPlatform", callName: "get_rewards", args: args)
    }
    
    static func depositLiquidityDemeter(_ args: DemeterFarmingDepositLiquidityCall) -> RuntimeCall<DemeterFarmingDepositLiquidityCall> {
        RuntimeCall<DemeterFarmingDepositLiquidityCall>(moduleName: "DemeterFarmingPlatform", callName: "deposit", args: args)
    }
    
    static func withdrawLiquidityDemeter(_ args: DemeterFarmingWithdrawLiquidityCall) -> RuntimeCall<DemeterFarmingWithdrawLiquidityCall> {
        RuntimeCall<DemeterFarmingWithdrawLiquidityCall>(moduleName: "DemeterFarmingPlatform", callName: "withdraw", args: args)
    }
}
