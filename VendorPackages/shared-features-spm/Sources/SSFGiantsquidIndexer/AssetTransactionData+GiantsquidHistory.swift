import BigInt
import Foundation
import SSFCrypto
import SSFIndexers
import SSFModels

extension AssetTransactionData {
    static func createTransaction(
        transfer: GiantsquidTransfer,
        address: String,
        asset: AssetModel
    ) -> AssetTransactionData {
        let peerAddress = transfer.from?.id == address ? transfer.to?.id : transfer.from?.id
        let amount = SubstrateAmountDecimal(
            string: transfer.amount,
            precision: asset.precision
        )
        let status: AssetTransactionStatus = transfer.success == true ? .commited : .rejected
        let type: TransactionType = transfer.from?.id == address ? .outgoing : .incoming

        var fees: [AssetTransactionFee] = []
        if let feeAmountString = transfer.feeAmount,
           let amount = SubstrateAmountDecimal(
               string: feeAmountString,
               precision: asset.precision
           )
        {
            let fee = AssetTransactionFee(
                identifier: asset.id,
                assetId: asset.id,
                amount: amount,
                context: nil
            )
            fees.append(fee)
        }

        if let signedData = transfer.signedData,
           let fee = signedData.fee,
           let partialFee = fee.partialFee,
           let amount = SubstrateAmountDecimal(big: partialFee, precision: asset.precision)
        {
            let fee = AssetTransactionFee(
                identifier: asset.id,
                assetId: asset.id,
                amount: amount,
                context: nil
            )
            fees.append(fee)
        }

        return AssetTransactionData(
            transactionId: transfer.identifier,
            status: status,
            assetId: asset.id,
            peerId: nil,
            peerFirstName: nil,
            peerLastName: nil,
            peerName: peerAddress,
            details: nil,
            amount: amount,
            fees: fees,
            timestamp: Self.convertGiantsquid(timestamp: transfer.timestamp),
            type: type.rawValue,
            reason: nil,
            context: nil
        )
    }

    static func createTransaction(
        reward: GiantsquidReward,
        address: String,
        chainAsset: ChainAsset
    ) -> AssetTransactionData {
        let amount = SubstrateAmountDecimal(
            string: reward.amount,
            precision: chainAsset.asset.precision
        )

        let accountId = try? AddressFactory.accountId(
            from: address,
            chain: chainAsset.chain
        )
        let peerId = accountId?.toHex() ?? address

        return AssetTransactionData(
            transactionId: reward.identifier,
            status: .commited,
            assetId: chainAsset.asset.id,
            peerId: peerId,
            peerFirstName: reward.validator,
            peerLastName: nil,
            peerName: TransactionType.reward.rawValue,
            details: "#\(reward.era ?? 0)",
            amount: amount,
            fees: [],
            timestamp: Self.convertGiantsquid(timestamp: reward.timestamp),
            type: TransactionType.reward.rawValue,
            reason: reward.identifier,
            context: nil
        )
    }

    static func createTransaction(
        bond: GiantsquidBond,
        address: String,
        chainAsset: ChainAsset
    ) -> AssetTransactionData {
        let amount = SubstrateAmountDecimal(
            string: bond.amount,
            precision: chainAsset.asset.precision
        )

        let accountId = try? AddressFactory.accountId(
            from: address,
            chain: chainAsset.chain
        )
        let peerId = accountId?.toHex() ?? address

        return AssetTransactionData(
            transactionId: bond.id,
            status: .commited,
            assetId: chainAsset.asset.id,
            peerId: peerId,
            peerFirstName: bond.accountId,
            peerLastName: nil,
            peerName: TransactionType.extrinsic.rawValue,
            details: "#\(bond.blockNumber)",
            amount: amount,
            fees: [],
            timestamp: Self.convertGiantsquid(timestamp: bond.timestamp),
            type: TransactionType.extrinsic.rawValue,
            reason: bond.identifier,
            context: nil
        )
    }

    static func createTransaction(
        slash: GiantsquidSlash,
        address: String,
        chainAsset: ChainAsset
    ) -> AssetTransactionData {
        let amount = SubstrateAmountDecimal(
            string: slash.amount,
            precision: chainAsset.asset.precision
        )

        let accountId = try? AddressFactory.accountId(
            from: address,
            chain: chainAsset.chain
        )
        let peerId = accountId?.toHex() ?? address

        return AssetTransactionData(
            transactionId: slash.id,
            status: .commited,
            assetId: "",
            peerId: peerId,
            peerFirstName: slash.accountId,
            peerLastName: nil,
            peerName: TransactionType.extrinsic.rawValue,
            details: "#\(slash.blockNumber)",
            amount: amount,
            fees: [],
            timestamp: Self.convertGiantsquid(timestamp: slash.timestamp),
            type: TransactionType.extrinsic.rawValue,
            reason: slash.identifier,
            context: nil
        )
    }

    static func convertGiantsquid(timestamp: String) -> Int64? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
        let date = dateFormatter.date(from: timestamp)
        guard let dateStamp = date?.timeIntervalSince1970 else {
            return nil
        }
        let timestamp = Int64(dateStamp)
        return timestamp
    }
}
