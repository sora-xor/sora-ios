import BigInt
import CommonWallet
import Foundation
import IrohaCrypto

extension SubqueryHistoryElement: WalletRemoteHistoryItemProtocol {
    var itemBlockNumber: UInt64 {
        0
    }

    var itemExtrinsicIndex: UInt16 {
        0
    }

    var itemTimestamp: Int64 {
        Int64(timestamp.value)
    }

    var extrinsicHash: String? {
        return identifier
    }

    var label: WalletRemoteHistorySourceLabel {
        return .extrinsics
    }

    func createTransactionForAddress(
        _ address: String,
        networkType: SNAddressType,
        asset: WalletAsset,
        addressFactory: SS58AddressFactoryProtocol
    ) -> AssetTransactionData? {
        if let rewardOrSlash = try? data.map(to: SubqueryRewardOrSlash.self) {
            return createTransactionForRewardOrSlash(rewardOrSlash, asset: asset)
        }

        if let transfer = try? data.map(to: SubqueryTransfer.self) {
            return createTransactionForTransfer(
                transfer,
                address: address,
                networkType: networkType,
                asset: asset,
                addressFactory: addressFactory
            )
        }

        if let swap = try? data.map(to: SubquerySwap.self) {
            return createTransactionForSwap(swap)
        }

        if let extrinsic = try? data.map(to: SubqueryExtrinsic.self) {
            return createTransactionForExtrinsic(
                extrinsic,
                address: address,
                networkType: networkType,
                asset: asset,
                addressFactory: addressFactory
            )
        }

        if let liquidity = try? data.map(to: SubqueryLiquidity.self) {
            return createTransactionForLiquidity(
                liquidity,
                address: address,
                networkType: networkType,
                asset: asset,
                addressFactory: addressFactory
            )
        }

        print("Error: No tx type for: \(data)")
        return nil
    }

    private func createTransactionForSwap(
        _ swap: SubquerySwap
    ) -> AssetTransactionData {
        let status: AssetTransactionStatus = execution.success ? .commited : .rejected
        let amountDecimal = Decimal(string: swap.targetAssetAmount) ?? .zero

        let feeDecimal = Decimal(string: self.fee) ?? .zero
        let fee = AssetTransactionFee(
            identifier: swap.targetAssetId,
            assetId: swap.targetAssetId,
            amount: AmountDecimal(value: feeDecimal),
            context: nil
        )

        let lpFeeDecimal = Decimal(string: swap.liquidityProviderFee) ?? .zero
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

    // never works yet
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
        let status = execution.success ? AssetTransactionStatus.commited : AssetTransactionStatus.rejected

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

    private func createTransactionForLiquidity(
        _ liquidity: SubqueryLiquidity,
        address: String,
        networkType: SNAddressType,
        asset: WalletAsset,
        addressFactory: SS58AddressFactoryProtocol
    ) -> AssetTransactionData {
        let status: AssetTransactionStatus = execution.success ? .commited : .rejected
        let amountDecimal = Decimal(string: liquidity.targetAssetAmount) ?? .zero
        let fee = AssetTransactionFee(
            identifier: asset.identifier,
            assetId: asset.identifier,
            amount: AmountDecimal(value: Decimal(string: self.fee) ?? .zero),
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
}
