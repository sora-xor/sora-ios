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
import FearlessUtils

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
}
