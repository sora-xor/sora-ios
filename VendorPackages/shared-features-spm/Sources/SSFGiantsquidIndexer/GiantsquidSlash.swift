import Foundation
import SSFIndexers
import SSFModels

struct GiantsquidSlash: Decodable {
    let id: String
    let accountId: String
    let amount: String
    let blockNumber: UInt32
    let era: UInt32
    let timestamp: String

    var timestampInSeconds: Int64 {
        AssetTransactionData.convertGiantsquid(timestamp: timestamp) ?? 0
    }
}

extension GiantsquidSlash: WalletRemoteHistoryItemProtocol {
    var identifier: String {
        id
    }

    var itemBlockNumber: UInt64 { 0 }
    var itemExtrinsicIndex: UInt16 { 0 }
    var itemTimestamp: Int64 { timestampInSeconds }
    var label: WalletRemoteHistorySourceLabel {
        .extrinsics
    }

    func createTransactionForAddress(
        _ address: String,
        chainAsset: ChainAsset
    ) -> AssetTransactionData {
        AssetTransactionData.createTransaction(
            slash: self,
            address: address,
            chainAsset: chainAsset
        )
    }
}
