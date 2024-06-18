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
    static func createFromTransferInfo(
        _ info: TransferInfo,
        transactionHash: Data,
        networkType: SNAddressType,
        addressFactory: SS58AddressFactoryProtocol
    ) throws -> TransactionHistoryItem {

        let lpFee = String(info.fees.first(where: { $0.feeDescription.type == "lp" })?.value.decimalValue.toSubstrateAmount(precision: 18) ?? BigUInt(0))
        let transactionFee: String = String(info.fees.first(where: { $0.feeDescription.type == "fee" })?.value.decimalValue.toSubstrateAmount(precision: 18) ?? BigUInt(0))

        let timestamp = Int64(Date().timeIntervalSince1970)

        let callPath: CallCodingPath
        let encodedCall: Data
        switch info.type {
        case .swap:
            let sender = info.asset
            let receiver = info.destination
            let amountCall = info.amountCall ?? [:]
            let sourceType: String = info.context?[TransactionContextKeys.marketType] ?? ""
            let dexId: String = info.context?[TransactionContextKeys.dex] ?? "0"
            let marketType: LiquiditySourceType = LiquiditySourceType(rawValue: sourceType) ?? .smart
            let call = try? SubstrateCallFactory().swap(
                from: sender,
                to: receiver,
                dexId: dexId,
                amountCall: amountCall,
                type: marketType.code,
                filter: marketType.filter
            )
            callPath = CallCodingPath(moduleName: call!.moduleName, callName: call!.callName)
            encodedCall = try JSONEncoder.scaleCompatible().encode(call)

        case .liquidityAdd, .liquidityAddNewPool:
            let dexId: String = info.context?[TransactionContextKeys.dex] ?? "0"
            let assetA: String = info.source
            let assetB: String = info.destination
            let desiredA =  AmountDecimal(string: info.context?[TransactionContextKeys.firstAssetAmount] ?? "0")!
            let desiredB =  AmountDecimal(string: info.context?[TransactionContextKeys.secondAssetAmount] ?? "0")!
            let slippage =  AmountDecimal(string: info.context?[TransactionContextKeys.slippage] ?? "0")!
            let minA = desiredA.decimalValue * (1 - slippage.decimalValue / 100)
            let minB = desiredB.decimalValue * (1 - slippage.decimalValue / 100)

            let call = try? SubstrateCallFactory().depositLiquidity(
                dexId: dexId,
                assetA: assetA,
                assetB: assetB,
                desiredA: desiredA.decimalValue.toSubstrateAmount(precision: 18) ?? 0,
                desiredB: desiredB.decimalValue.toSubstrateAmount(precision: 18) ?? 0,
                minA: minA.toSubstrateAmount(precision: 18) ?? 0,
                minB: minB.toSubstrateAmount(precision: 18) ?? 0
            )
            callPath = CallCodingPath(moduleName: call!.moduleName, callName: call!.callName)
            encodedCall = try JSONEncoder.scaleCompatible().encode(call)

        case .liquidityAddToExistingPoolFirstTime:
            //TODO: utility.batchAll with poolXYK.initializePool and poolXYK.depositLiquidity
            callPath = CallCodingPath(moduleName: "Stub", callName: "Stub")
            encodedCall = Data()

        case .liquidityRemoval:
            let dexId: String = info.context?[TransactionContextKeys.dex] ?? "0"
            let assetA: String = info.source
            let assetB: String = info.destination
            let desiredA = AmountDecimal(string: info.context?[TransactionContextKeys.firstAssetAmount] ?? "0")!
            let desiredB = AmountDecimal(string: info.context?[TransactionContextKeys.secondAssetAmount] ?? "0")!
            let slippage =  AmountDecimal(string: info.context?[TransactionContextKeys.slippage] ?? "0")!
            let minA = desiredA.decimalValue * (1 - slippage.decimalValue / 100)
            let minB = desiredB.decimalValue * (1 - slippage.decimalValue / 100)

            let call = try? SubstrateCallFactory().withdrawLiquidityCall(
                dexId: dexId,
                assetA: assetA,
                assetB: assetB,
                assetDesired: desiredA.decimalValue.toSubstrateAmount(precision: 18) ?? 0 ,
                minA: minA.toSubstrateAmount(precision: 18) ?? 0,
                minB: minB.toSubstrateAmount(precision: 18) ?? 0
            )
            callPath = CallCodingPath(moduleName: call!.moduleName, callName: call!.callName)
            encodedCall = try JSONEncoder.scaleCompatible().encode(call)
            
        case .demeterClaimReward:
            let baseAsset: String = info.source
            let poolAsset: String = info.destination
            let rewardAsset: String = info.context?[TransactionContextKeys.rewardAsset] ?? ""
            let isFarm: Bool = info.context?[TransactionContextKeys.isFarm] == "1"

            let call = try? SubstrateCallFactory().claimRewardFromDemeterFarmCall(
                baseAssetId: baseAsset,
                targetAssetId: poolAsset,
                rewardAssetId: rewardAsset,
                isFarm: isFarm
            )
            callPath = CallCodingPath(moduleName: call!.moduleName, callName: call!.callName)
            encodedCall = try JSONEncoder.scaleCompatible().encode(call)
            
        case .demeterDeposit:
            let baseAsset: String = info.source
            let poolAsset: String = info.destination
            let rewardAsset: String = info.context?[TransactionContextKeys.rewardAsset] ?? ""
            let isFarm: Bool = info.context?[TransactionContextKeys.isFarm] == "1"
            let amount = info.amount.decimalValue

            let call = try? SubstrateCallFactory().depositLiquidityToDemeterFarmCall(
                baseAssetId: baseAsset,
                targetAssetId: poolAsset,
                rewardAssetId: rewardAsset,
                isFarm: isFarm,
                amount: amount.toSubstrateAmount(precision: 18) ?? 0
            )
            callPath = CallCodingPath(moduleName: call!.moduleName, callName: call!.callName)
            encodedCall = try JSONEncoder.scaleCompatible().encode(call)
            
        case .demeterWithdraw:
            let baseAsset: String = info.source
            let poolAsset: String = info.destination
            let rewardAsset: String = info.context?[TransactionContextKeys.rewardAsset] ?? ""
            let isFarm: Bool = info.context?[TransactionContextKeys.isFarm] == "1"
            let amount = info.amount.decimalValue

            let call = try? SubstrateCallFactory().withdrawLiquidityFromDemeterFarmCall(
                baseAssetId: baseAsset,
                targetAssetId: poolAsset,
                rewardAssetId: rewardAsset,
                isFarm: isFarm,
                amount: amount.toSubstrateAmount(precision: 18) ?? 0
            )
            callPath = CallCodingPath(moduleName: call!.moduleName, callName: call!.callName)
            encodedCall = try JSONEncoder.scaleCompatible().encode(call)

            
        // TODO: impl
        case .incoming, .outgoing, .migration, .reward, .slash, .extrinsic, .referral:
            let receiverAccountId = try Data(hexStringSSF: info.destination)

            callPath = CallCodingPath.transfer
            let callArgs = SoraTransferCall(receiver: receiverAccountId,
                                            amount: info.amount.decimalValue.toSubstrateAmount(precision: 18) ?? 0,
                                            assetId: AssetId(wrappedValue: info.asset))
            let call = RuntimeCall<SoraTransferCall>(
                moduleName: callPath.moduleName,
                callName: callPath.callName,
                args: callArgs
            )
            encodedCall = try JSONEncoder.scaleCompatible().encode(call)
        }

        return TransactionHistoryItem(
            sender: SelectedWalletSettings.shared.currentAccount!.address,
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
