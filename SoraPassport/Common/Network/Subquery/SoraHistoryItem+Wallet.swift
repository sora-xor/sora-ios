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

import sorawallet
import BigInt
import IrohaCrypto
import SSFUtils

extension TxHistoryItem: WalletRemoteHistoryItemProtocol {
    var identifier: String {
        id
    }

    var itemBlockNumber: UInt64 {
        0
    }
    
    var itemExtrinsicIndex: UInt16 {
        0
    }

    var extrinsicHash: String? {
        id
    }

    var itemTimestamp: Int64 {
        Int64(timestamp) ?? 0
    }

    var label: WalletRemoteHistorySourceLabel {
        .extrinsics
    }
    
    func createTransactionForAddress(_ address: String, networkType: SNAddressType, asset: WalletAsset, addressFactory: SS58AddressFactoryProtocol) -> AssetTransactionData? {
        
        var dict = [String:JSON]()

        for element in data ?? [] {
            // SDK parameters are strings even when the history schema expects
            // a boolean or era number. Keep amounts and identifiers as strings.
            switch element.paramName {
            case "isReward", "success":
                dict[element.paramName] = Bool(element.paramValue).map(JSON.boolValue)
                    ?? .stringValue(element.paramValue)
            case "era":
                dict[element.paramName] = Int64(element.paramValue).map(JSON.signedIntValue)
                    ?? .stringValue(element.paramValue)
            default:
                dict[element.paramName] = .stringValue(element.paramValue)
            }
        }

        let json: JSON = .dictionaryValue(dict)

        if let rewardOrSlash = try? json.map(to: SubqueryRewardOrSlash.self) {
            return createTransactionForRewardOrSlash(rewardOrSlash, asset: asset)
        }

        if let transfer = try? json.map(to: SubqueryTransfer.self) {
            return createTransactionForTransfer(
                transfer,
                address: address,
                networkType: networkType,
                asset: asset,
                addressFactory: addressFactory
            )
        }

        if let swap = try? json.map(to: SubquerySwap.self) {
            return createTransactionForSwap(swap)
        }

        if let liquidity = try? json.map(to: SubqueryLiquidity.self) {
            return createTransactionForLiquidity(
                liquidity,
                address: address,
                networkType: networkType,
                asset: asset,
                addressFactory: addressFactory
            )
        }

        if let referral = try? json.map(to: SubqueryReferral.self) {
            return createTransactionForReferral(
                referral,
                address: address,
                networkType: networkType,
                asset: asset,
                reason: method,
                addressFactory: addressFactory
            )
        }
        
        if let extrinsic = try? json.map(to: SubqueryExtrinsic.self) {
            return createTransactionForExtrinsic(
                extrinsic,
                address: address,
                networkType: networkType,
                asset: asset,
                addressFactory: addressFactory
            )
        }

        if let data = nestedData?.first(where: { $0.module == "poolXYK" && $0.method == "depositLiquidity" }) {

            for element in data.data ?? [] {
                dict[element.paramName] = JSON.stringValue(element.paramValue)
            }

            let json: JSON = .dictionaryValue(dict)

            if let extrinsic = try? json.map(to: SubqueryCreatePoolLiquidity.self) {
                return createTransactionForCreateLiquidityPool(
                    extrinsic,
                    address: address,
                    networkType: networkType,
                    asset: asset,
                    addressFactory: addressFactory
                )
            }
        }

        return nil
    }
    
    private func createTransactionForSwap(
        _ swap: SubquerySwap
    ) -> AssetTransactionData? {
        let status: AssetTransactionStatus = success ? .commited : .rejected
        guard
            let amountDecimal = validatedDecimal(swap.targetAssetAmount),
            validatedDecimal(swap.baseAssetAmount) != nil,
            let feeDecimal = validatedIntegerDecimal(self.networkFee),
            let lpFeeDecimal = validatedDecimal(swap.liquidityProviderFee)
        else {
            return nil
        }
        let fee = AssetTransactionFee(
            identifier: swap.targetAssetId,
            assetId: swap.targetAssetId,
            amount: AmountDecimal(value: feeDecimal),
            context: nil
        )

        let lpFee = AssetTransactionFee(
            identifier: swap.baseAssetId,
            assetId: swap.baseAssetId,
            amount: AmountDecimal(value: lpFeeDecimal),
            context: ["type": TransactionType.swap.rawValue]
        )
        // Selected market: empty: smart; else first?
        return AssetTransactionData(
            transactionId: identifier,
            status: status,
            assetId: swap.targetAssetId,
            peerId: swap.baseAssetId,
            peerFirstName: nil,
            peerLastName: nil,
            peerName: swap.selectedMarket,
            details: swap.baseAssetAmount,
            amount: AmountDecimal(value: amountDecimal),
            fees: [fee, lpFee],
            timestamp: itemTimestamp,
            type: TransactionType.swap.rawValue,
            reason: nil,
            context: nil)
    }

    private func createTransactionForExtrinsic(
        _ extrinsic: SubqueryExtrinsic,
        address: String,
        networkType: SNAddressType,
        asset: WalletAsset,
        addressFactory: SS58AddressFactoryProtocol
    ) -> AssetTransactionData? {
        guard
            let rawFee = BigUInt(extrinsic.fee),
            let amount = Decimal.fromSubstrateAmount(
            rawFee,
            precision: asset.precision
            )
        else {
            return nil
        }

        let accountId = try? addressFactory.accountId(
            fromAddress: address,
            type: networkType
        )

        let peerId = accountId?.toHex() ?? address

        let status: AssetTransactionStatus = extrinsic.success ? .commited : .rejected

        return AssetTransactionData(
            transactionId: identifier,
            status: status,
            assetId: asset.identifier,
            peerId: peerId,
            peerFirstName: extrinsic.module,
            peerLastName: extrinsic.call,
            peerName: "\(extrinsic.module) \(extrinsic.call)",
            details: "",
            amount: AmountDecimal(value: amount),
            fees: [],
            timestamp: itemTimestamp,
            type: TransactionType.extrinsic.rawValue,
            reason: nil,
            context: [TransactionContextKeys.extrinsicHash: extrinsic.hash]
        )
    }

    private func createTransactionForTransfer(
        _ transfer: SubqueryTransfer,
        address: String,
        networkType: SNAddressType,
        asset: WalletAsset,
        addressFactory: SS58AddressFactoryProtocol
    ) -> AssetTransactionData? {
        let status = success ? AssetTransactionStatus.commited : AssetTransactionStatus.rejected

        let peerAddress = transfer.sender == address ? transfer.receiver : transfer.sender

        let peerAccountId = try? addressFactory.accountId(
            fromAddress: peerAddress,
            type: networkType
        )

        guard
            let amountDecimal = validatedDecimal(transfer.amount),
            let feeDecimal = validatedIntegerDecimal(self.networkFee)
        else {
            return nil
        }

        let fee = AssetTransactionFee(
            identifier: asset.identifier,
            assetId: asset.identifier,
            amount: AmountDecimal(value: feeDecimal),
            context: nil
        )

        let type = transfer.sender == address ? TransactionType.outgoing : TransactionType.incoming

        let context: [String: String]?

        if let extrinsicHash = self.extrinsicHash {
            context = [TransactionContextKeys.extrinsicHash: extrinsicHash]
        } else {
            context = nil
        }

        return AssetTransactionData(
            transactionId: identifier,
            status: status,
            assetId: transfer.assetId,
            peerId: peerAccountId?.toHex() ?? "",
            peerFirstName: nil,
            peerLastName: nil,
            peerName: peerAddress,
            details: "",
            amount: AmountDecimal(value: amountDecimal),
            fees: [fee],
            timestamp: itemTimestamp,
            type: type.rawValue,
            reason: nil,
            context: context
        )
    }

    private func createTransactionForRewardOrSlash(
        _ rewardOrSlash: SubqueryRewardOrSlash,
        asset: WalletAsset
    ) -> AssetTransactionData? {
        guard
            let rawAmount = BigUInt(rewardOrSlash.amount),
            let amount = Decimal.fromSubstrateAmount(
            rawAmount,
            precision: asset.precision
            )
        else {
            return nil
        }

        let type = rewardOrSlash.isReward ? TransactionType.reward.rawValue : TransactionType.slash.rawValue

        let validatorAddress = rewardOrSlash.validator ?? ""

        let context: [String: String]?

        if let era = rewardOrSlash.era {
            context = [TransactionContextKeys.era: String(era)]
        } else {
            context = nil
        }

        return AssetTransactionData(
            transactionId: identifier,
            status: .commited,
            assetId: asset.identifier,
            peerId: validatorAddress,
            peerFirstName: nil,
            peerLastName: nil,
            peerName: validatorAddress,
            details: "",
            amount: AmountDecimal(value: amount),
            fees: [],
            timestamp: itemTimestamp,
            type: type,
            reason: nil,
            context: context
        )
    }

    private func createTransactionForLiquidity(
        _ liquidity: SubqueryLiquidity,
        address: String,
        networkType: SNAddressType,
        asset: WalletAsset,
        addressFactory: SS58AddressFactoryProtocol
    ) -> AssetTransactionData? {
        let status: AssetTransactionStatus = success ? .commited : .rejected
        guard
            let amountDecimal = validatedDecimal(liquidity.targetAssetAmount),
            validatedDecimal(liquidity.baseAssetAmount) != nil,
            let feeDecimal = validatedIntegerDecimal(self.networkFee)
        else {
            return nil
        }
        let fee = AssetTransactionFee(
            identifier: asset.identifier,
            assetId: asset.identifier,
            amount: AmountDecimal(value: feeDecimal),
            context: nil
        )

        return AssetTransactionData(
            transactionId: identifier,
            status: status,
            assetId: liquidity.targetAssetId,
            peerId: liquidity.baseAssetId,
            peerFirstName: nil,
            peerLastName: nil,
            peerName: liquidity.baseAssetId,
            details: liquidity.baseAssetAmount,
            amount: AmountDecimal(value: amountDecimal),
            fees: [fee],
            timestamp: itemTimestamp,
            type: liquidity.type.transactionType.rawValue,
            reason: nil,
            context: nil
        )
    }

    private func createTransactionForCreateLiquidityPool(
        _ liquidity: SubqueryCreatePoolLiquidity,
        address: String,
        networkType: SNAddressType,
        asset: WalletAsset,
        addressFactory: SS58AddressFactoryProtocol
    ) -> AssetTransactionData? {
        let status: AssetTransactionStatus = success ? .commited : .rejected
        guard
            let amountDecimal = validatedDecimal(liquidity.inputADesired),
            validatedDecimal(liquidity.inputBDesired) != nil,
            let feeDecimal = validatedIntegerDecimal(self.networkFee)
        else {
            return nil
        }
        let fee = AssetTransactionFee(
            identifier: asset.identifier,
            assetId: asset.identifier,
            amount: AmountDecimal(value: feeDecimal),
            context: nil
        )

        return AssetTransactionData(
            transactionId: identifier,
            status: status,
            assetId: liquidity.inputAssetA,
            peerId: liquidity.inputAssetB,
            peerFirstName: nil,
            peerLastName: nil,
            peerName: liquidity.inputAssetB,
            details: liquidity.inputBDesired,
            amount: AmountDecimal(value: amountDecimal),
            fees: [fee],
            timestamp: itemTimestamp,
            type: "Deposit",
            reason: nil,
            context: nil
        )
    }

    private func createTransactionForReferral(
        _ referral: SubqueryReferral,
        address: String,
        networkType: SNAddressType,
        asset: WalletAsset,
        reason: String,
        addressFactory: SS58AddressFactoryProtocol
    ) -> AssetTransactionData? {
        let status: AssetTransactionStatus = success ? .commited : .rejected
        guard let feeDecimal = validatedIntegerDecimal(networkFee) else {
            return nil
        }
        let amountDecimal: Decimal
        if let rawAmount = referral.amount {
            guard let value = validatedDecimal(rawAmount) else {
                return nil
            }
            amountDecimal = value
        } else {
            amountDecimal = .zero
        }
        let fee = AssetTransactionFee(
            identifier: asset.identifier,
            assetId: asset.identifier,
            amount: AmountDecimal(value: feeDecimal),
            context: nil
        )

        var type = ReferralMethodType(fromRawValue: method)

        if type == .setReferrer, referral.to == address {
            type = .setReferral
        }

        let context: [String: String]? = [TransactionContextKeys.blockHash: blockHash,
                                          TransactionContextKeys.sender: referral.from,
                                          TransactionContextKeys.referral: referral.from,
                                          TransactionContextKeys.referrer: referral.to,
                                          TransactionContextKeys.referralTransactionType: type.rawValue]

        return AssetTransactionData(
            transactionId: identifier,
            status: status,
            assetId: asset.identifier,
            peerId: referral.to,
            peerFirstName: nil,
            peerLastName: nil,
            peerName: nil,
            details: "",
            amount: AmountDecimal(value: amountDecimal),
            fees: [fee],
            timestamp: itemTimestamp,
            type: TransactionType.referral.rawValue,
            reason: nil,
            context: context
        )
    }

    private func validatedDecimal(_ rawValue: String) -> Decimal? {
        try? HistoryTransactionMapper.validatedAmount(rawValue).decimalValue
    }

    private func validatedIntegerDecimal(_ rawValue: String) -> Decimal? {
        try? HistoryTransactionMapper.validatedFee(rawValue).decimalValue
    }
}
