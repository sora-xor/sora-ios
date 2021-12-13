/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import IrohaCrypto
import CommonWallet
import BigInt

extension SubqueryHistoryElement: WalletRemoteHistoryItemProtocol {
    var itemBlockNumber: UInt64 {
        0
    }

    var itemExtrinsicIndex: UInt16 {
        0
    }

    var itemTimestamp: Int64 {
        Int64(timestamp.value) ?? 0
    }

    var extrinsicHash: String? {
        return self.identifier
    }

    var label: WalletRemoteHistorySourceLabel {
//        if reward != nil {
//            return .rewards
//        }
//
//        if transfer != nil {
//            return .transfers
//        }

        return .extrinsics
    }

    func createTransactionForAddress(
        _ address: String,
        networkType: SNAddressType,
        asset: WalletAsset,
        addressFactory: SS58AddressFactoryProtocol
    ) -> AssetTransactionData? {
        if let rewardOrSlash = try? self.data.map(to: SubqueryRewardOrSlash.self) {
            return createTransactionForRewardOrSlash(rewardOrSlash, asset: asset)
        }

        if let transfer = try? self.data.map(to: SubqueryTransfer.self) {
            return createTransactionForTransfer(
                transfer,
                address: address,
                networkType: networkType,
                asset: asset,
                addressFactory: addressFactory
            )
        }
// no swap in 2.2
//        if let swap = swap {
//            return createTransactionForSwap(swap)
//        }

        guard let extrinsic = try? self.data.map(to: SubqueryExtrinsic.self) else { return nil }

        return createTransactionForExtrinsic(
            extrinsic,
            address: address,
            networkType: networkType,
            asset: asset,
            addressFactory: addressFactory
        )
    }

    private func createTransactionForSwap(
        _ swap: SubquerySwap
    ) -> AssetTransactionData {

        let status: AssetTransactionStatus = self.execution.success ? .commited : .rejected
        let amountDecimal = Decimal(string: swap.targetAssetAmount) ?? .zero
        let feeDecimal = Decimal(string: self.fee) ?? .zero

        let fee = AssetTransactionFee(
            identifier: swap.targetAssetId,
            assetId: swap.targetAssetId,
            amount: AmountDecimal(value: feeDecimal),
            context: nil
        )

        return AssetTransactionData(
            transactionId: identifier,
            status: status,
            assetId: swap.baseAssetId,
            peerId: swap.targetAssetId,
            peerFirstName: nil,
            peerLastName: nil,
            peerName: nil,
            details: "",
            amount: AmountDecimal(value: amountDecimal),
            fees: [fee],
            timestamp: itemTimestamp,
            type: TransactionType.swap.rawValue,
            reason: nil,
            context: nil)
    }
//never works yet
    private func createTransactionForExtrinsic(
        _ extrinsic: SubqueryExtrinsic,
        address: String,
        networkType: SNAddressType,
        asset: WalletAsset,
        addressFactory: SS58AddressFactoryProtocol
    ) -> AssetTransactionData {
        let amount = Decimal.fromSubstrateAmount(
            BigUInt(extrinsic.fee) ?? 0,
            precision: asset.precision
        ) ?? 0.0

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
    ) -> AssetTransactionData {

        let status = self.execution.success ? AssetTransactionStatus.commited : AssetTransactionStatus.rejected

        let peerAddress = transfer.sender == address ? transfer.receiver : transfer.sender

        let peerAccountId = try? addressFactory.accountId(
            fromAddress: peerAddress,
            type: networkType
        )

        let amountDecimal = Decimal(string: transfer.amount) ?? .zero
        let feeDecimal = Decimal(string: self.fee) ?? .zero

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
    ) -> AssetTransactionData {
        let amount = Decimal.fromSubstrateAmount(
            BigUInt(rewardOrSlash.amount) ?? 0,
            precision: asset.precision
        ) ?? 0.0

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
}
