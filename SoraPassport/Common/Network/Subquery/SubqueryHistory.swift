import Foundation
import FearlessUtils

struct SubqueryPageInfo: Decodable {
    let startCursor: String?
    let endCursor: String?
}

struct SubqueryTransfer: Decodable {
    enum CodingKeys: String, CodingKey {
        case amount
        case receiver = "to"
        case sender = "from"
        case assetId
        case extrinsicId
        case extrinsicHash
    }

    let amount: String
    let receiver: String
    let sender: String
    let assetId: String
    let extrinsicId: String?
    let extrinsicHash: String?
}

struct SubqueryRewardOrSlash: Decodable {
    let amount: String
    let isReward: Bool
    let era: Int?
    let validator: String?
}

struct SubqueryExtrinsic: Decodable {
    let hash: String
    let module: String
    let call: String
    let fee: String
    let success: Bool
}

struct SubquerySwap: Decodable {
    let baseAssetId: String
    let targetAssetId: String
    let baseAssetAmount: String
    let targetAssetAmount: String
    let liquidityProviderFee: String
    let selectedMarket: String
}

struct SubqueryHistoryElement: Decodable {
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case timestamp
        case blockHash
        case address
        case fee = "networkFee"
        case data
        case execution
    }

    let identifier: String
    let timestamp: SubqueryTimestamp
    let blockHash: String
    let address: String
    let fee: String
    let data: JSON
    let execution: SubqueryExecution
}

struct SubqueryTimestamp: Decodable {
    let value: Int
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let val = try? container.decode(Int.self) {
            value = val
        } else if let val1 = try? container.decode(String.self) {
            value = Int(val1) ?? 0
        } else {
            value = 0
        }
    }
}

struct SubqueryError: Decodable {
    let moduleErrorId: Int
    let moduleErrorIndex: Int
    let nonModuleErrorMessage: String?
}

struct SubqueryExecution: Decodable {
    let error: SubqueryError?
    let success: Bool
}

struct SubqueryHistoryData: Decodable {
    struct HistoryElements: Decodable {
        let pageInfo: SubqueryPageInfo
        let nodes: [SubqueryHistoryElement]
    }

    let historyElements: HistoryElements
}

struct SubqueryRewardOrSlashData: Decodable {
    struct HistoryElements: Decodable {
        let nodes: [SubqueryHistoryElement]
    }

    let historyElements: HistoryElements
}
