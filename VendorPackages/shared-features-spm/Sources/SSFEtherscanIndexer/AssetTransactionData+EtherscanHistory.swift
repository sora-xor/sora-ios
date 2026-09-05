import Foundation
import SSFIndexers
import SSFModels

extension AssetTransactionData {
    static func createTransaction(
        from item: EtherscanHistoryElement,
        address: String,
        chainAsset: ChainAsset
    ) -> AssetTransactionData {
        let peerAddress = item.from == address ? item.to : item.from
        let type: TransactionType = item.from == address ? .outgoing : .incoming

        let timestamp: Int64? = {
            guard let timestampValue = item.timeStamp else {
                return nil
            }

            return Int64(timestampValue)
        }()

        let feeValue = item.gasUsed * item.gasPrice

        let utilityAsset = chainAsset.chain.utilityChainAssets().first?.asset ?? chainAsset.asset

        let fee = AssetTransactionFee(
            identifier: chainAsset.asset.id,
            assetId: chainAsset.asset.id,
            amount: SubstrateAmountDecimal(
                big: feeValue,
                precision: utilityAsset.precision
            ),
            context: nil
        )

        return AssetTransactionData(
            transactionId: item.hash ?? "",
            status: .commited,
            assetId: item.contractAddress,
            peerId: nil,
            peerFirstName: nil,
            peerLastName: nil,
            peerName: peerAddress,
            details: nil,
            amount: SubstrateAmountDecimal(
                big: item.value,
                precision: chainAsset.asset.precision
            ),
            fees: [fee],
            timestamp: timestamp,
            type: type.rawValue,
            reason: nil,
            context: nil
        )
    }
}
