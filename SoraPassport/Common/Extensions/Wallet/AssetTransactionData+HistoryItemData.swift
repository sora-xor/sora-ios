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
//
import BigInt
import IrohaCrypto
import SSFUtils

extension AssetTransactionData {
    static func createTransaction(
        from item: TransactionHistoryItem,
        address: String,
        networkType: SNAddressType,
        asset: WalletAsset,
        addressFactory: SS58AddressFactoryProtocol
    ) -> AssetTransactionData {
        if item.callPath.isTransfer {
            return createLocalTransfer(
                from: item,
                address: address,
                networkType: networkType,
                asset: asset,
                addressFactory: addressFactory
            )
        }

        if item.callPath.isMigration {
            return createMigration(from: item)
        }

        if item.callPath.isSwap {
            return createLocalSwap(
                from: item,
                address: address,
                asset: asset
            )
        }

        if item.callPath.isDepositLiquidity {
            return createTransactionForDepositLiquidity(
                from: item,
                address: address,
                networkType: networkType,
                asset: asset,
                addressFactory: addressFactory
            )
        }

        if item.callPath.isWithdrawLiquidity {
            return createTransactionForWithdrawLiquidity(
                from: item,
                address: address,
                networkType: networkType,
                asset: asset,
                addressFactory: addressFactory
            )
        }

        if item.callPath.isReferral {
            return createTransactionForReferral(
                from: item,
                address: address,
                networkType: networkType,
                asset: asset,
                addressFactory: addressFactory
            )
        }

        // TODO: add other types of transactions
        return createLocalExtrinsic(
            from: item,
            address: address,
            networkType: networkType,
            asset: asset,
            addressFactory: addressFactory
        )
    }

    private static func createTransactionForDepositLiquidity(
        from item: TransactionHistoryItem,
        address: String,
        networkType: SNAddressType,
        asset: WalletAsset,
        addressFactory: SS58AddressFactoryProtocol
    ) -> AssetTransactionData {

        let deposit = try? JSONDecoder.scaleCompatible().decode(RuntimeCall<DepositLiquidityCall>.self, from: item.call).args

        let desiredA = deposit?.desiredA ?? 0
        let desiredB = deposit?.desiredB ?? 0

        let desiredADecimal = Decimal.fromSubstrateAmount(desiredA, precision: asset.precision) ?? .zero
        let desiredBDecimal = Decimal.fromSubstrateAmount(desiredB, precision: asset.precision) ?? .zero

        let feeDecimal: Decimal = {
            guard let feeValue = BigUInt(item.fee) else {
                return Decimal(string: item.fee) ?? .zero
            }
            return Decimal.fromSubstrateAmount(feeValue, precision: asset.precision) ?? .zero
        }()
        let fee = AssetTransactionFee(
            identifier: asset.identifier,
            assetId: asset.identifier,
            amount: AmountDecimal(value: feeDecimal),
            context: nil
        )

        return AssetTransactionData(
            transactionId: item.txHash,
            status: item.status.walletValue,
            assetId: deposit?.assetB.value ?? "?",
            peerId: deposit?.assetA.value ?? "??",
            peerFirstName: nil,
            peerLastName: nil,
            peerName: deposit?.assetA.value,
            details: desiredADecimal.description,
            amount: AmountDecimal(value: desiredBDecimal),
            fees: [fee],
            timestamp: item.timestamp,
            type: TransactionType.liquidityAdd.rawValue,
            reason: nil,
            context: nil
        )
    }

    private static func createTransactionForWithdrawLiquidity(
        from item: TransactionHistoryItem,
        address: String,
        networkType: SNAddressType,
        asset: WalletAsset,
        addressFactory: SS58AddressFactoryProtocol
    ) -> AssetTransactionData {
        
        let withdraw = try? JSONDecoder.scaleCompatible().decode(RuntimeCall<WithdrawLiquidityCall>.self, from: item.call).args

        let desiredA = withdraw?.assetDesired ?? 0
        let desiredB = withdraw?.minB ?? 0

        let desiredADecimal = Decimal.fromSubstrateAmount(desiredA, precision: asset.precision) ?? .zero
        let desiredBDecimal = Decimal.fromSubstrateAmount(desiredB, precision: asset.precision) ?? .zero

        let feeDecimal: Decimal = {
            guard let feeValue = BigUInt(item.fee) else {
                return Decimal(string: item.fee) ?? .zero
            }
            return Decimal.fromSubstrateAmount(feeValue, precision: asset.precision) ?? .zero
        }()
        let fee = AssetTransactionFee(
            identifier: asset.identifier,
            assetId: asset.identifier,
            amount: AmountDecimal(value: feeDecimal),
            context: nil
        )

        let assetId: String = withdraw?.assetB.value ?? "?"
        let peerId: String = withdraw?.assetA.value ?? "??"

        return AssetTransactionData(
            transactionId: item.txHash,
            status: item.status.walletValue,
            assetId: assetId,
            peerId: peerId,
            peerFirstName: nil,
            peerLastName: nil,
            peerName: assetId,
            details: desiredADecimal.description,
            amount: AmountDecimal(value: desiredBDecimal),
            fees: [fee],
            timestamp: item.timestamp,
            type: TransactionType.liquidityRemoval.rawValue,
            reason: nil,
            context: nil
        )
    }

    private static func createTransactionForReferral(
        from item: TransactionHistoryItem,
        address: String,
        networkType: SNAddressType,
        asset: WalletAsset,
        addressFactory: SS58AddressFactoryProtocol
    ) -> AssetTransactionData {
        let status: AssetTransactionStatus = .commited

        var type: ReferralMethodType = .setReferrer

        if item.callPath == .bondReferralBalance {
            type = .bond
        }

        if item.callPath == .unbondReferralBalance {
            type = .unbond
        }

        let setReferrerCall = try? JSONDecoder.scaleCompatible().decode(RuntimeCall<SetReferrerCall>.self, from: item.call).args

        let bondUnbondCall = try? JSONDecoder.scaleCompatible().decode(RuntimeCall<ReferralBalanceCall>.self, from: item.call).args

        let amount = Decimal.fromSubstrateAmount(bondUnbondCall?.balance ?? .zero, precision: asset.precision) ?? 0.0

        let feeAmount: Decimal = {
            guard let amountValue = BigUInt(item.fee) else { return 0.0 }
            return Decimal.fromSubstrateAmount(amountValue, precision: asset.precision) ?? 0.0
        }()

        let fee = AssetTransactionFee(
            identifier: asset.identifier,
            assetId: asset.identifier,
            amount: AmountDecimal(value: feeAmount),
            context: nil
        )

        let referrer: String = (try? addressFactory.address(fromAccountId: setReferrerCall?.referrer ?? Data(), type: 69)) ?? ""

        let context: [String: String]? = [TransactionContextKeys.blockHash: item.txHash,
                                          TransactionContextKeys.sender: address,
                                          TransactionContextKeys.referrer: referrer,
                                          TransactionContextKeys.referralTransactionType: type.rawValue]

        return AssetTransactionData(
            transactionId: item.identifier,
            status: status,
            assetId: asset.identifier,
            peerId: address,
            peerFirstName: nil,
            peerLastName: nil,
            peerName: nil,
            details: "",
            amount: AmountDecimal(value: amount),
            fees: [fee],
            timestamp: item.timestamp,
            type: TransactionType.referral.rawValue,
            reason: nil,
            context: context
        )
    }

    private static func createLocalSwap(
        from item: TransactionHistoryItem,
        address: String,
        asset: WalletAsset
    ) -> AssetTransactionData {

        let swap = try? JSONDecoder.scaleCompatible().decode(RuntimeCall<SwapCall>.self, from: item.call).args
        let sourceType: UInt? = swap?.liquiditySourceType.first as? UInt
        let marketType: LiquiditySourceType = LiquiditySourceType(networkValue: sourceType)
        let amountStruct = swap?.amount.values.first
        let desired = amountStruct?.desired ?? 0
        let slip = amountStruct?.slip ?? 0

        let amountDecimal = Decimal.fromSubstrateAmount(slip, precision: asset.precision) ?? .zero
        let fromAmountDecimal = Decimal.fromSubstrateAmount(desired, precision: asset.precision) ?? .zero

        let feeDecimal: Decimal = {
            guard let feeValue = BigUInt(item.fee) else {
                return Decimal(string: item.fee) ?? .zero
            }

            return Decimal.fromSubstrateAmount(feeValue, precision: asset.precision) ?? .zero
        }()
        let fee = AssetTransactionFee(
            identifier: asset.identifier,
            assetId: asset.identifier,
            amount: AmountDecimal(value: feeDecimal),
            context: nil
        )

        return AssetTransactionData(
            transactionId: item.txHash,
            status: item.status.walletValue,
            assetId: swap?.outputAssetId.value ?? "?",
            peerId: swap?.inputAssetId.value ?? "??",
            peerFirstName: nil,
            peerLastName: nil,
            peerName: marketType.rawValue,
            details: fromAmountDecimal.description,
            amount: AmountDecimal(value: amountDecimal),
            fees: [fee],
            timestamp: item.timestamp,
            type: TransactionType.swap.rawValue,
            reason: nil,
            context: nil)
    }

    private static func createMigration(from item: TransactionHistoryItem ) -> AssetTransactionData {
        let call = try? JSONDecoder.scaleCompatible().decode(RuntimeCall<MigrateCall>.self, from: item.call).args

        return AssetTransactionData(
            transactionId: item.txHash,
            status: item.status.walletValue,
            assetId: "",
            peerId: "",
            peerFirstName: nil,
            peerLastName: nil,
            peerName: call?.irohaAddress,
            details: "",
            amount: AmountDecimal(value: 0),
            fees: [],
            timestamp: item.timestamp,
            type: TransactionType.migration.rawValue,
            reason: nil,
            context: nil)


    }

    private static func createLocalTransfer(
        from item: TransactionHistoryItem,
        address: String,
        networkType: SNAddressType,
        asset: WalletAsset,
        addressFactory: SS58AddressFactoryProtocol
    ) -> AssetTransactionData {
        let peerAddress = (item.sender == address ? item.receiver : item.sender) ?? item.sender

        let accountId = try? addressFactory.accountId(
            fromAddress: peerAddress,
            type: networkType
        )

        let call = try? JSONDecoder.scaleCompatible().decode(RuntimeCall<SoraTransferCall>.self, from: item.call).args

        let assetId = call?.assetId.value ?? asset.identifier

        let peerId = accountId?.toHex() ?? peerAddress
        let feeDecimal: Decimal = {
            guard let feeValue = BigUInt(item.fee) else {
                return Decimal(string: item.fee) ?? .zero
            }

            return Decimal.fromSubstrateAmount(feeValue, precision: asset.precision) ?? .zero
        }()

        let fee = AssetTransactionFee(
            identifier: asset.identifier,
            assetId: asset.identifier,
            amount: AmountDecimal(value: feeDecimal),
            context: nil
        )

        let amount: Decimal = {
            if let call = call {
                return Decimal.fromSubstrateAmount(call.amount, precision: asset.precision) ?? .zero
            } else {
                return .zero
            }
        }()

        let type = item.sender == address ? TransactionType.outgoing :
            TransactionType.incoming

        return AssetTransactionData(
            transactionId: item.txHash,
            status: item.status.walletValue,
            assetId: assetId,
            peerId: peerId,
            peerFirstName: nil,
            peerLastName: nil,
            peerName: peerAddress,
            details: "",
            amount: AmountDecimal(value: amount),
            fees: [fee],
            timestamp: item.timestamp,
            type: type.rawValue,
            reason: nil,
            context: [TransactionContextKeys.extrinsicHash: item.txHash]
        )
    }

    private static func createLocalExtrinsic(
        from item: TransactionHistoryItem,
        address: String,
        networkType: SNAddressType,
        asset: WalletAsset,
        addressFactory: SS58AddressFactoryProtocol
    ) -> AssetTransactionData {
        let amount: Decimal = {
            guard let amountValue = BigUInt(item.fee) else {
                return 0.0
            }

            return Decimal.fromSubstrateAmount(amountValue, precision: asset.precision) ?? 0.0
        }()

        let accountId = try? addressFactory.accountId(
            fromAddress: item.sender,
            type: networkType
        )

        let cfff = try? JSONDecoder.scaleCompatible().decode(RuntimeCall<SwapCall>.self, from: item.call)
        let peerId = accountId?.toHex() ?? address

        return AssetTransactionData(
            transactionId: item.identifier,
            status: item.status.walletValue,
            assetId: asset.identifier,
            peerId: peerId,
            peerFirstName: item.callPath.moduleName,
            peerLastName: item.callPath.callName,
            peerName: "\(item.callPath.moduleName) \(item.callPath.callName)",
            details: "",
            amount: AmountDecimal(value: amount),
            fees: [],
            timestamp: item.timestamp,
            type: TransactionType.extrinsic.rawValue,
            reason: nil,
            context: [TransactionContextKeys.extrinsicHash: item.txHash]
        )
    }
}
