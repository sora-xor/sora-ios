import BigInt
import Foundation
import SSFCrypto
import SSFIndexers
import SSFModels

extension AssetTransactionData {
    enum AssetTransactionDataType: String {
        case unknown = "UNKNOWN"
    }

    static func createTransaction(
        from item: SubsquidHistoryElement,
        address: String,
        chainAsset: ChainAsset
    ) -> AssetTransactionData {
        if let transfer = item.transfer {
            return createTransaction(
                from: item,
                transfer: transfer,
                address: address,
                chainAsset: chainAsset
            )
        }

        if let reward = item.reward {
            return createTransaction(
                from: item,
                reward: reward,
                address: address,
                chainAsset: chainAsset
            )
        }

        if let extrinsic = item.extrinsic {
            return createTransaction(
                from: item,
                extrinsic: extrinsic,
                asset: chainAsset.asset
            )
        }

        let timestamp = item.timestampInSeconds

        return AssetTransactionData(
            transactionId: item.identifier,
            status: .pending,
            assetId: chainAsset.asset.id,
            peerId: nil,
            peerFirstName: nil,
            peerLastName: nil,
            peerName: nil,
            details: nil,
            amount: nil,
            fees: [],
            timestamp: timestamp,
            type: Self.AssetTransactionDataType.unknown.rawValue,
            reason: nil,
            context: nil
        )
    }

    private static func createTransaction(
        from item: SubsquidHistoryElement,
        transfer: SubsquidTransfer,
        address: String,
        chainAsset: ChainAsset
    ) -> AssetTransactionData {
        let status: AssetTransactionStatus = transfer.success ? .commited : .rejected
        let peerAddress = transfer.sender == address ? transfer.receiver : transfer.sender
        let accountId = try? AddressFactory.accountId(
            from: peerAddress,
            chain: chainAsset.chain
        )
        let peerId = accountId?.toHex() ?? peerAddress

        let amount = SubstrateAmountDecimal(
            string: transfer.amount,
            precision: chainAsset.asset.precision
        )
        let utilityAsset = chainAsset.chain.utilityChainAssets().first?.asset ?? chainAsset.asset
        let feeAmount = SubstrateAmountDecimal(
            string: transfer.fee,
            precision: utilityAsset.precision
        )
        let fee = AssetTransactionFee(
            identifier: chainAsset.asset.id,
            assetId: chainAsset.asset.id,
            amount: feeAmount,
            context: nil
        )

        let type: TransactionType = transfer.sender == address ? .outgoing : .incoming

        return AssetTransactionData(
            transactionId: item.extrinsicHash ?? item.identifier,
            status: status,
            assetId: chainAsset.asset.id,
            peerId: peerId,
            peerFirstName: nil,
            peerLastName: nil,
            peerName: peerAddress,
            details: "",
            amount: amount,
            fees: [fee],
            timestamp: item.timestampInSeconds,
            type: type.rawValue,
            reason: "",
            context: nil
        )
    }

    private static func createTransaction(
        from item: SubsquidHistoryElement,
        reward: SubsquidRewardOrSlash,
        address: String,
        chainAsset: ChainAsset
    ) -> AssetTransactionData {
        let status: AssetTransactionStatus = .commited
        let amount = SubstrateAmountDecimal(
            string: reward.amount,
            precision: chainAsset.asset.precision
        )
        let type: TransactionType = reward.isReward ? .reward : .slash

        let accountId = try? AddressFactory.accountId(
            from: address,
            chain: chainAsset.chain
        )
        let peerId = accountId?.toHex() ?? address

        return AssetTransactionData(
            transactionId: item.identifier,
            status: status,
            assetId: chainAsset.asset.id,
            peerId: peerId,
            peerFirstName: reward.validator,
            peerLastName: nil,
            peerName: type.rawValue,
            details: "#\(reward.era ?? 0)",
            amount: amount,
            fees: [],
            timestamp: item.timestampInSeconds,
            type: type.rawValue,
            reason: item.identifier,
            context: nil
        )
    }

    static func createTransaction(
        from item: SubsquidHistoryElement,
        extrinsic: SubsquidExtrinsic,
        asset: AssetModel
    ) -> AssetTransactionData {
        let amount = SubstrateAmountDecimal(
            string: extrinsic.fee,
            precision: asset.precision
        )
        let peerId = item.address
        let status: AssetTransactionStatus = extrinsic.success ? .commited : .rejected

        return AssetTransactionData(
            transactionId: item.identifier,
            status: status,
            assetId: asset.id,
            peerId: peerId,
            peerFirstName: extrinsic.module,
            peerLastName: extrinsic.call,
            peerName: "\(extrinsic.module) \(extrinsic.call)",
            details: nil,
            amount: amount,
            fees: [],
            timestamp: item.timestampInSeconds,
            type: TransactionType.extrinsic.rawValue,
            reason: extrinsic.hash,
            context: nil
        )
    }
}
