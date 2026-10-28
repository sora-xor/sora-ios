import BigInt
import Foundation
import SSFIndexers
import SSFModels

extension AssetTransactionData {
    static func createTransaction(
        from item: SoraSubsquidHistoryElement,
        address: String,
        chainAsset: ChainAsset
    ) -> AssetTransactionData {
        let assetId = item.data?.anyAssetId ?? ""
        let success = item.execution?.success == true
        let status: AssetTransactionStatus = success ? .commited : .rejected

        let transactionFee = AssetTransactionFee(
            identifier: item.id,
            assetId: assetId,
            amount: SubstrateAmountDecimal(
                string: item.networkFee,
                precision: chainAsset.asset.precision
            ),
            context: nil
        )

        switch (item.module, item.method) {
        case (.staking, .rewarded):
            return createRewardTransaction(
                from: item,
                fee: transactionFee,
                status: status
            )
        case (.assets, .transfer):
            return createTransferTransaction(
                from: item,
                address: address,
                fee: transactionFee,
                status: status
            )
        case (.some(_), .swap):
            return createSwapTransaction(
                from: item,
                fee: transactionFee,
                status: status
            )
        case (.some(_), .transferToSidechain):
            return createBridgeTransaction(
                from: item,
                fee: transactionFee,
                status: status
            )
        default:
            return createExtrinsicTransaction(
                from: item,
                fee: transactionFee,
                status: status
            )
        }
    }

    static func createTransferTransaction(
        from item: SoraSubsquidHistoryElement,
        address: String,
        fee: AssetTransactionFee,
        status: AssetTransactionStatus
    ) -> AssetTransactionData {
        let from = item.data?.from
        let to = item.data?.to
        let assetId = item.data?.assetId ?? ""
        let type: TransactionType = from == address ? .outgoing : .incoming
        let timestamp = item.itemTimestamp
        let peer = from == address ? to : from

        return AssetTransactionData(
            transactionId: item.id,
            status: status,
            assetId: assetId,
            peerId: nil,
            peerFirstName: nil,
            peerLastName: nil,
            peerName: peer,
            details: nil,
            amount: SubstrateAmountDecimal(string: item.data?.amount),
            fees: [fee],
            timestamp: timestamp,
            type: type.rawValue,
            reason: nil,
            context: nil
        )
    }

    static func createRewardTransaction(
        from item: SoraSubsquidHistoryElement,
        fee: AssetTransactionFee,
        status: AssetTransactionStatus
    ) -> AssetTransactionData {
        let type = TransactionType.reward
        let timestamp = item.itemTimestamp
        let stash = item.data?.stash
        let era = item.data?.era.map { "\($0)" }

        return AssetTransactionData(
            transactionId: item.id,
            status: status,
            assetId: nil,
            peerId: nil,
            peerFirstName: nil,
            peerLastName: nil,
            peerName: stash,
            details: era,
            amount: SubstrateAmountDecimal(string: item.data?.amount),
            fees: [fee],
            timestamp: timestamp,
            type: type.rawValue,
            reason: nil,
            context: nil
        )
    }

    static func createSwapTransaction(
        from item: SoraSubsquidHistoryElement,
        fee: AssetTransactionFee,
        status _: AssetTransactionStatus
    ) -> AssetTransactionData {
        let type = TransactionType.swap
        let timestamp = item.itemTimestamp
        let stash = item.data?.stash
        let assetId = item.data?.targetAssetId
        let baseAssetId = item.data?.baseAssetId
        let sendAmount = item.data?.baseAssetAmount
        return AssetTransactionData(
            transactionId: item.id,
            status: .commited,
            assetId: assetId,
            peerId: baseAssetId,
            peerFirstName: nil,
            peerLastName: nil,
            peerName: stash,
            details: sendAmount,
            amount: SubstrateAmountDecimal(string: item.data?.targetAssetAmount),
            fees: [fee],
            timestamp: timestamp,
            type: type.rawValue,
            reason: nil,
            context: nil
        )
    }

    static func createBridgeTransaction(
        from item: SoraSubsquidHistoryElement,
        fee: AssetTransactionFee,
        status _: AssetTransactionStatus
    ) -> AssetTransactionData {
        let type = TransactionType.bridge
        let timestamp = item.itemTimestamp
        let stash = item.data?.stash
        return AssetTransactionData(
            transactionId: item.id,
            status: .commited,
            assetId: nil,
            peerId: nil,
            peerFirstName: nil,
            peerLastName: nil,
            peerName: stash,
            details: nil,
            amount: SubstrateAmountDecimal(string: item.data?.amount),
            fees: [fee],
            timestamp: timestamp,
            type: type.rawValue,
            reason: nil,
            context: nil
        )
    }

    static func createExtrinsicTransaction(
        from item: SoraSubsquidHistoryElement,
        fee: AssetTransactionFee,
        status _: AssetTransactionStatus
    ) -> AssetTransactionData {
        let from = item.address
        let to = item.data?.to
        let assetId = item.data?.assetId
        let timestamp = item.itemTimestamp

        return AssetTransactionData(
            transactionId: item.id,
            status: .commited,
            assetId: assetId,
            peerId: from,
            peerFirstName: item.module?.rawValue,
            peerLastName: item.method?.rawValue,
            peerName: to,
            details: nil,
            amount: fee.amount,
            fees: [fee],
            timestamp: timestamp,
            type: TransactionType.extrinsic.rawValue,
            reason: nil,
            context: nil
        )
    }
}
