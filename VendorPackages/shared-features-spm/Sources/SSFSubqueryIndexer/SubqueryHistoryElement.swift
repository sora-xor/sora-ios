import Foundation
import SSFIndexers
import SSFModels

struct SubqueryHistoryElement: Decodable, RewardOrSlashData {
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case timestamp
        case address
        case reward
        case extrinsic
        case transfer
    }

    enum SubqueryHistoryElementType {
        case reward(SubqueryRewardOrSlash)
        case extrinsic(SubqueryExtrinsic)
        case transfer(SubqueryTransfer)
    }

    let identifier: String
    let timestamp: String
    let address: String
    let reward: SubqueryRewardOrSlash?
    let extrinsic: SubqueryExtrinsic?
    let transfer: SubqueryTransfer?

    var type: SubqueryHistoryElementType? {
        if let reward {
            return .reward(reward)
        }
        if let extrinsic {
            return .extrinsic(extrinsic)
        }
        if let transfer {
            return .transfer(transfer)
        }
        return nil
    }

    var rewardInfo: RewardOrSlash? {
        reward
    }
}

extension SubqueryHistoryElement: WalletRemoteHistoryItemProtocol {
    var extrinsicHash: String? { nil }
    var itemBlockNumber: UInt64 { 0 }
    var itemExtrinsicIndex: UInt16 { 0 }
    var itemTimestamp: Int64 { Int64(timestamp) ?? 0 }
    var label: WalletRemoteHistorySourceLabel {
        if reward != nil {
            return .rewards
        }

        if extrinsic != nil {
            return .extrinsics
        }

        return .transfers
    }

    func createTransactionForAddress(
        _ address: String,
        chainAsset: ChainAsset
    ) -> AssetTransactionData {
        AssetTransactionData.createTransaction(
            from: self,
            address: address,
            chainAsset: chainAsset
        )
    }
}
