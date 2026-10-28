import BigInt
import Foundation
import SSFIndexers
import SSFModels
import SSFUtils

struct GiantsquidDestination: Decodable {
    let id: String
}

struct GiantsquidTransferResponse: Decodable {
    let id: String
    let transfer: GiantsquidTransfer
}

struct GiantsquidTransfer: Decodable {
    let id: String?
    let amount: String
    let to: GiantsquidDestination?
    let from: GiantsquidDestination?
    let success: Bool?
    let extrinsicHash: String?
    let timestamp: String
    let blockNumber: UInt32?
    let type: String?
    let feeAmount: String?
    let signedData: GiantsquidSignedData?

    var timestampInSeconds: Int64 {
        AssetTransactionData.convertGiantsquid(timestamp: timestamp) ?? 0
    }
}

struct GiantsquidSignedData: Decodable {
    let fee: GiantsquidSignedDataFee?
}

struct GiantsquidSignedDataFee: Decodable {
    let `class`: String?
    let weight: UInt32?
    @OptionStringCodable var partialFee: BigUInt?
}

extension GiantsquidTransfer: WalletRemoteHistoryItemProtocol {
    var identifier: String {
        id.or(extrinsicHash.or(timestamp + amount))
    }

    var itemBlockNumber: UInt64 { 0 }
    var itemExtrinsicIndex: UInt16 { 0 }
    var itemTimestamp: Int64 { timestampInSeconds }
    var label: WalletRemoteHistorySourceLabel {
        .transfers
    }

    func createTransactionForAddress(
        _ address: String,
        chainAsset: ChainAsset
    ) -> AssetTransactionData {
        AssetTransactionData.createTransaction(
            transfer: self,
            address: address,
            asset: chainAsset.asset
        )
    }
}
