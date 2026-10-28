import Foundation
import SSFIndexers
import SSFModels

struct GiantsquidBond: Decodable {
    let id: String
    let accountId: String
    let amount: String
    let blockNumber: UInt32
    let extrinsicHash: String?
    let success: Bool?
    let timestamp: String
    let type: String?

    var timestampInSeconds: Int64 {
        AssetTransactionData.convertGiantsquid(timestamp: timestamp) ?? 0
    }
}

extension GiantsquidBond: WalletRemoteHistoryItemProtocol {
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
            bond: self,
            address: address,
            chainAsset: chainAsset
        )
    }
}
