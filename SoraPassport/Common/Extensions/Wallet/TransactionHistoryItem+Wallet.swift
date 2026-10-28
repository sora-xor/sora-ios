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
