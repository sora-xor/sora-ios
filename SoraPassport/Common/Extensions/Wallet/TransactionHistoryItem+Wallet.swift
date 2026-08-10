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

import SoraKeystore
import IrohaCrypto
import SSFUtils
import BigInt

extension TransactionHistoryItem {
    /// Creates the pending overlay from the call JSON captured from the exact
    /// signed extrinsic. No amount, precision, slippage, or batch ordering is
    /// reconstructed after signing.
    static func createFromPreparedLiquidity(
        _ info: TransferInfo,
        transactionHash: Data,
        senderAddress: String,
        rawFee: String,
        exactCall: JSON
    ) throws -> TransactionHistoryItem {
        guard
            !senderAddress.isEmpty,
            let fee = BigUInt(rawFee),
            fee > 0,
            info.type == .liquidityAdd ||
                info.type == .liquidityAddNewPool ||
                info.type == .liquidityAddToExistingPoolFirstTime ||
                info.type == .liquidityRemoval
        else {
            throw WalletNetworkOperationFactoryError.invalidContext
        }

        let runtimeCall = try exactCall.map(to: RuntimeCall<JSON>.self)
        let callPath = CallCodingPath(
            moduleName: runtimeCall.moduleName,
            callName: runtimeCall.callName
        )
        let expectedPath: CallCodingPath
        switch info.type {
        case .liquidityAdd:
            expectedPath = .depositLiquidity
        case .liquidityAddNewPool,
             .liquidityAddToExistingPoolFirstTime:
            expectedPath = .utilityBatchAll
        case .liquidityRemoval:
            expectedPath = .withdrawLiquidity
        default:
            throw WalletNetworkOperationFactoryError.invalidContext
        }
        guard
            callPath.moduleName == expectedPath.moduleName,
            callPath.callName == expectedPath.callName
        else {
            throw WalletNetworkOperationFactoryError.invalidContext
        }

        return TransactionHistoryItem(
            sender: senderAddress,
            receiver: info.destination,
            status: .pending,
            txHash: transactionHash.toHex(includePrefix: true),
            timestamp: Int64(Date().timeIntervalSince1970),
            fee: rawFee,
            blockNumber: nil,
            txIndex: nil,
            callPath: callPath,
            call: try JSONEncoder.scaleCompatible().encode(runtimeCall)
        )
    }

    static func createFromTransferInfo(
        _ info: TransferInfo,
        transactionHash: Data,
        senderAddress: String,
        networkType: SNAddressType,
        addressFactory: SS58AddressFactoryProtocol
    ) throws -> TransactionHistoryItem {

        let transactionFee: String = String(info.fees.first(where: { $0.feeDescription.type == "fee" })?.value.decimalValue.toSubstrateAmount(precision: 18) ?? BigUInt(0))

        let timestamp = Int64(Date().timeIntervalSince1970)

        let callPath: CallCodingPath
        let encodedCall: Data
        switch info.type {
        case .swap:
            let sender = info.asset
            let receiver = info.destination
            guard let context = info.context,
                  let amountCall = info.amountCall,
                  let sourceType = context[TransactionContextKeys.marketType],
                  let marketType = LiquiditySourceType(rawValue: sourceType),
                  let dexId = context[TransactionContextKeys.dex] else {
                throw WalletNetworkOperationFactoryError.invalidContext
            }
            let call = try SubstrateCallFactory().swap(
                from: sender,
                to: receiver,
                dexId: dexId,
                amountCall: amountCall,
                type: marketType.code,
                filter: marketType.filter
            )
            callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)
            encodedCall = try JSONEncoder.scaleCompatible().encode(call)

        case .liquidityAdd,
             .liquidityAddNewPool,
             .liquidityAddToExistingPoolFirstTime,
             .liquidityRemoval:
            // Liquidity history must come from the exact prepared call above.
            // Reconstructing it here can diverge in precision or batch shape.
            throw WalletNetworkOperationFactoryError.invalidContext
            
        case .demeterClaimReward:
            let baseAsset: String = info.source
            let poolAsset: String = info.destination
            guard let demeterContext = validatedDemeterContext(info) else {
                throw WalletNetworkOperationFactoryError.invalidContext
            }

            let call = try SubstrateCallFactory().claimRewardFromDemeterFarmCall(
                baseAssetId: baseAsset,
                targetAssetId: poolAsset,
                rewardAssetId: demeterContext.rewardAsset,
                isFarm: demeterContext.isFarm
            )
            callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)
            encodedCall = try JSONEncoder.scaleCompatible().encode(call)
            
        case .demeterDeposit:
            let baseAsset: String = info.source
            let poolAsset: String = info.destination
            guard let demeterContext = validatedDemeterContext(info),
                  info.amount.decimalValue > 0,
                  let amount = info.amount.decimalValue.toSubstrateAmount(precision: 18),
                  amount > 0 else {
                throw WalletNetworkOperationFactoryError.invalidContext
            }

            let call = try SubstrateCallFactory().depositLiquidityToDemeterFarmCall(
                baseAssetId: baseAsset,
                targetAssetId: poolAsset,
                rewardAssetId: demeterContext.rewardAsset,
                isFarm: demeterContext.isFarm,
                amount: amount
            )
            callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)
            encodedCall = try JSONEncoder.scaleCompatible().encode(call)
            
        case .demeterWithdraw:
            let baseAsset: String = info.source
            let poolAsset: String = info.destination
            guard let demeterContext = validatedDemeterContext(info),
                  info.amount.decimalValue > 0,
                  let amount = info.amount.decimalValue.toSubstrateAmount(precision: 18),
                  amount > 0 else {
                throw WalletNetworkOperationFactoryError.invalidContext
            }

            let call = try SubstrateCallFactory().withdrawLiquidityFromDemeterFarmCall(
                baseAssetId: baseAsset,
                targetAssetId: poolAsset,
                rewardAssetId: demeterContext.rewardAsset,
                isFarm: demeterContext.isFarm,
                amount: amount
            )
            callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)
            encodedCall = try JSONEncoder.scaleCompatible().encode(call)

            
        // TODO: impl
        case .incoming, .outgoing, .migration, .reward, .slash, .extrinsic, .referral:
            let receiverAccountId = try Data(hexStringSSF: info.destination)
            guard !info.asset.isEmpty,
                  info.amount.decimalValue > 0,
                  let amount = info.amount.decimalValue.toSubstrateAmount(precision: 18),
                  amount > 0 else {
                throw WalletNetworkOperationFactoryError.invalidAmount
            }

            callPath = CallCodingPath.transfer
            let callArgs = SoraTransferCall(receiver: receiverAccountId,
                                            amount: amount,
                                            assetId: AssetId(wrappedValue: info.asset))
            let call = RuntimeCall<SoraTransferCall>(
                moduleName: callPath.moduleName,
                callName: callPath.callName,
                args: callArgs
            )
            encodedCall = try JSONEncoder.scaleCompatible().encode(call)
        }

        guard !senderAddress.isEmpty else {
            throw WalletNetworkOperationFactoryError.invalidContext
        }
        return TransactionHistoryItem(
            sender: senderAddress,
            receiver: info.destination,
            status: .pending,
            txHash: transactionHash.toHex(includePrefix: true),
            timestamp: timestamp,
            fee: transactionFee,
            blockNumber: nil,
            txIndex: nil,
            callPath: callPath,
            call: encodedCall
        )
    }

    private static func validatedDemeterContext(
        _ info: TransferInfo
    ) -> (rewardAsset: String, isFarm: Bool)? {
        guard !info.source.isEmpty,
              !info.destination.isEmpty,
              let context = info.context,
              let rewardAsset = context[TransactionContextKeys.rewardAsset],
              !rewardAsset.isEmpty,
              let rawIsFarm = context[TransactionContextKeys.isFarm],
              rawIsFarm == "0" || rawIsFarm == "1" else {
            return nil
        }
        return (rewardAsset, rawIsFarm == "1")
    }
}

extension TransactionHistoryItem.Status {
    var walletValue: AssetTransactionStatus {
        switch self {
        case .success:
            return .commited
        case .failed:
            return .rejected
        case .pending:
            return .pending
        }
    }
}
