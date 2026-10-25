import Foundation
import SSFIndexers
import SSFModels

extension AssetTransactionData {
    static func createTransaction(
        from item: OklinkTransactionItem,
        address: String,
        chainAsset: ChainAsset
    ) -> AssetTransactionData {
        let peerAddress = item.from == address ? item.to : item.from
        let type: TransactionType = item.from == address ? .outgoing : .incoming

        let timestamp: Int64? = {
            guard let timestamp = Int64(item.transactionTime) else {
                return nil
            }
            return timestamp / 1000
        }()

        let fee = AssetTransactionFee(
            identifier: chainAsset.asset.id,
            assetId: chainAsset.asset.id,
            amount: SubstrateAmountDecimal(string: item.txFee),
            context: nil
        )

        return AssetTransactionData(
            transactionId: item.blockHash,
            status: .commited,
            assetId: item.tokenContractAddress,
            peerId: nil,
            peerFirstName: nil,
            peerLastName: nil,
            peerName: peerAddress,
            details: nil,
            amount: SubstrateAmountDecimal(string: item.amount),
            fees: [fee],
            timestamp: timestamp,
            type: type.rawValue,
            reason: nil,
            context: nil
        )
    }
}
