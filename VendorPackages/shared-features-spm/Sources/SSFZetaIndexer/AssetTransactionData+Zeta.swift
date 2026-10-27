import Foundation
import SSFIndexers
import SSFModels

extension AssetTransactionData {
    static func createTransaction(
        from item: ZetaItem,
        address: String,
        chainAsset: ChainAsset
    ) -> AssetTransactionData {
        let peerAddress = item.from.hash == address ? item.to.hash : item.from.hash
        let type: TransactionType = item.from.hash == address ? .outgoing : .incoming
        let utilityAsset = chainAsset.chain.utilityChainAssets().first?.asset ?? chainAsset.asset

        let feeAmount = SubstrateAmountDecimal(
            big: item.fee?.value,
            precision: utilityAsset.precision
        )
        let fee = AssetTransactionFee(
            identifier: chainAsset.asset.id,
            assetId: chainAsset.asset.id,
            amount: feeAmount,
            context: nil
        )

        let amountValue = item.value ?? item.total?.value
        let amount = SubstrateAmountDecimal(
            big: amountValue,
            precision: chainAsset.asset.precision
        )
        return AssetTransactionData(
            transactionId: item.hash ?? item.txHash ?? "",
            status: .commited,
            assetId: chainAsset.asset.id,
            peerId: nil,
            peerFirstName: nil,
            peerLastName: nil,
            peerName: peerAddress,
            details: nil,
            amount: amount,
            fees: [fee],
            timestamp: Self.convertZeta(timestamp: item.timestamp),
            type: type.rawValue,
            reason: nil,
            context: nil
        )
    }

    static func convertZeta(timestamp: String) -> Int64? {
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
