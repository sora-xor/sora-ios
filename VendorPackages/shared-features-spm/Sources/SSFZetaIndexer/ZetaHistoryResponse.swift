import BigInt
import Foundation
import SSFUtils

struct ZetaHistoryResponse: Codable {
    let items: [ZetaItem]
    let nextPageParams: NextPageParams?

    enum CodingKeys: String, CodingKey {
        case items
        case nextPageParams = "next_page_params"
    }
}

struct ZetaItem: Codable {
    let timestamp: String
    let from: ZetaAddress
    let to: ZetaAddress
    let fee: ZetaFee?

    @OptionStringCodable var value: BigUInt?
    let total: ZetaTotal?

    let hash: String?
    let txHash: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        timestamp = try container.decode(String.self, forKey: .timestamp)
        from = try container.decode(ZetaAddress.self, forKey: .from)
        to = try container.decode(ZetaAddress.self, forKey: .to)
        fee = try container.decodeIfPresent(ZetaFee.self, forKey: .fee)

        if let value = try container.decodeIfPresent(String.self, forKey: .value) {
            self.value = BigUInt(value)
        } else {
            value = nil
        }
        total = try container.decodeIfPresent(ZetaTotal.self, forKey: .total)

        hash = try container.decodeIfPresent(String.self, forKey: .hash)
        txHash = try container.decodeIfPresent(String.self, forKey: .txHash)
    }
}

struct ZetaFee: Codable {
    let type: String
    @StringCodable var value: BigUInt
}

struct ZetaAddress: Codable {
    let hash: String
}

struct NextPageParams: Codable {
    let blockNumber, index, itemsCount: Int?

    enum CodingKeys: String, CodingKey {
        case blockNumber = "block_number"
        case index
        case itemsCount = "items_count"
    }
}

struct ZetaTotal: Codable {
    let decimals: String
    @StringCodable var value: BigUInt
}
