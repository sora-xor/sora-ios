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

import BigInt
import SSFUtils
import Foundation
import IrohaCrypto

protocol SubstrateCallFactoryProtocol {
    func migrate(irohaAddress: String, irohaKey: String, signature: String) throws -> RuntimeCall<MigrateCall>
}

final class SubstrateCallFactory: SubstrateCallFactoryProtocol {
    private let addressFactory = SS58AddressFactory()

    func migrate(irohaAddress: String, irohaKey: String, signature: String) throws -> RuntimeCall<MigrateCall> {
        let call = MigrateCall(irohaAddress: irohaAddress, irohaPublicKey: irohaKey, irohaSignature: signature)
        return RuntimeCall<MigrateCall>.migrate(call)
    }

    func transfer(to receiverAccountId: String,
                  asset: String,
                  amount: BigUInt) throws -> RuntimeCall<SoraTransferCall> {

        let data = try Data(hexStringSSF: receiverAccountId)

        let call = SoraTransferCall(receiver: data,
                                    amount: amount,
                                    assetId: AssetId(wrappedValue:asset))
        return RuntimeCall<SoraTransferCall>.transfer(call)
    }

    func swap(from asset: String,
              to targetAsset: String,
              dexId: String,
              amountCall: [SwapVariant: SwapAmount],
              type: [[String?]], filter: UInt) throws -> RuntimeCall<SwapCall> {
        let filterMode = FilterMode.allCases[Int(filter)].rawValue
        let call = SwapCall(dexId: dexId,
                            inputAssetId: AssetId(wrappedValue:asset),
                            outputAssetId: AssetId(wrappedValue:targetAsset),
                            amount: amountCall,
                            liquiditySourceType: type,
                            filterMode: FilterModeType(wrappedName: filterMode, wrappedValue: filter))
        return RuntimeCall<SwapCall>.swap(call)
    }
    
    func register(dexId: String, baseAssetId: String, targetAssetId: String) throws -> RuntimeCall<PairRegisterCall> {
        let call = PairRegisterCall(dexId: dexId, baseAssetId: AssetId(wrappedValue:baseAssetId), targetAssetId: AssetId(wrappedValue:targetAssetId))
        return RuntimeCall<PairRegisterCall>.register(call)
    }
    
    func initializePool(dexId: String, baseAssetId: String, targetAssetId: String) throws -> RuntimeCall<InitializePoolCall> {
        let call = InitializePoolCall(dexId: dexId, assetA: AssetId.init(wrappedValue: baseAssetId), assetB: AssetId(wrappedValue: targetAssetId))
        return RuntimeCall<InitializePoolCall>.initializePool(call)
    }
    
    func depositLiquidity(
        dexId: String,
        assetA: String,
        assetB: String,
        desiredA: BigUInt,
        desiredB: BigUInt,
        minA: BigUInt,
        minB: BigUInt
    ) throws -> RuntimeCall<DepositLiquidityCall> {
        let call = DepositLiquidityCall(
            dexId: dexId,
            assetA: AssetId.init(wrappedValue: assetA),
            assetB: AssetId.init(wrappedValue: assetB),
            desiredA: desiredA,
            desiredB: desiredB,
            minA: minA,
            minB: minB
        )
        return RuntimeCall<DepositLiquidityCall>.depositLiquidity(call)
    }
    
    func withdrawLiquidityCall(
        dexId: String,
        assetA: String,
        assetB: String,
        assetDesired: BigUInt,
        minA: BigUInt,
        minB: BigUInt
    ) throws -> RuntimeCall<WithdrawLiquidityCall> {
        let call = WithdrawLiquidityCall(
            dexId: dexId,
            assetA: AssetId.init(wrappedValue: assetA),
            assetB: AssetId.init(wrappedValue: assetB),
            assetDesired: assetDesired,
            minA: minA,
            minB: minB
        )
        return RuntimeCall<WithdrawLiquidityCall>.withdrawLiquidity(call)
    }

    func setReferrer(referrer: String) throws -> RuntimeCall<SetReferrerCall> {
        let referrerData = try Data(hexStringSSF: referrer)
        let call = SetReferrerCall(referrer: referrerData)
        return RuntimeCall<SetReferrerCall>.setReferrer(call)
    }

    func reserveReferralBalance(balance: BigUInt) throws -> RuntimeCall<ReferralBalanceCall> {
        let call = ReferralBalanceCall(balance: balance)
        return RuntimeCall<ReferralBalanceCall>.reserveReferralBalance(call)
    }

    func unreserveReferralBalance(balance: BigUInt) throws -> RuntimeCall<ReferralBalanceCall> {
        let call = ReferralBalanceCall(balance: balance)
        return RuntimeCall<ReferralBalanceCall>.unreserveReferralBalance(call)
    }
    
    func claimRewardFromDemeterFarmCall(
        baseAssetId: String,
        targetAssetId: String,
        rewardAssetId: String,
        isFarm: Bool
    ) throws -> RuntimeCall<DemeterFarmingClaimRewardCall> {
        let call = DemeterFarmingClaimRewardCall(
            baseAssetId: AssetId.init(wrappedValue: baseAssetId),
            targetAssetId: AssetId.init(wrappedValue: targetAssetId),
            rewardAssetId: AssetId.init(wrappedValue: rewardAssetId),
            isFarm: isFarm
        )
        return RuntimeCall<DemeterFarmingClaimRewardCall>.claimRewardDemeter(call)
    }

    func depositLiquidityToDemeterFarmCall(
        baseAssetId: String,
        targetAssetId: String,
        rewardAssetId: String,
        isFarm: Bool,
        amount: BigUInt
    ) throws -> RuntimeCall<DemeterFarmingDepositLiquidityCall> {
        let call = DemeterFarmingDepositLiquidityCall(
            baseAssetId: AssetId.init(wrappedValue: baseAssetId),
            targetAssetId: AssetId.init(wrappedValue: targetAssetId),
            rewardAssetId: AssetId.init(wrappedValue: rewardAssetId),
            isFarm: isFarm,
            amount: amount
        )
        return RuntimeCall<DemeterFarmingDepositLiquidityCall>.depositLiquidityDemeter(call)
    }
    
    func withdrawLiquidityFromDemeterFarmCall(
        baseAssetId: String,
        targetAssetId: String,
        rewardAssetId: String,
        isFarm: Bool,
        amount: BigUInt
    ) throws -> RuntimeCall<DemeterFarmingWithdrawLiquidityCall> {
        let call = DemeterFarmingWithdrawLiquidityCall(
            baseAssetId: AssetId.init(wrappedValue: baseAssetId),
            targetAssetId: AssetId.init(wrappedValue: targetAssetId),
            rewardAssetId: AssetId.init(wrappedValue: rewardAssetId),
            isFarm: isFarm,
            amount: amount
        )
        return RuntimeCall<DemeterFarmingWithdrawLiquidityCall>.withdrawLiquidityDemeter(call)
    }
}
