import CoreData
import Foundation
import FearlessUtils
import RobinHood

struct AssetInfo: Codable {
    enum CodingKeys: String, CodingKey {
        case symbol
        case name
        case assetId = "asset_id"
        case precision
        case icon
        case visible
    }

    var symbol: String
    var name: String
    let assetId: String
    @StringCodable var precision: UInt32
    var icon: String?
    var visible: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        symbol = try container.decode(String.self, forKey: .symbol)
        name = try container.decode(String.self, forKey: .name)
        assetId = try container.decode(String.self, forKey: .assetId)
        precision = try container.decode(StringCodable<UInt32>.self, forKey: .precision).wrappedValue
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        visible = try container.decodeIfPresent(Bool.self, forKey: .visible) ?? false
    }
}

extension AssetInfo: Identifiable {
    var identifier: String { assetId }
}

extension CDAssetInfo: CoreDataCodable {
    public func populate(from decoder: Decoder, using context: NSManagedObjectContext) throws {
        let assetInfo = try AssetInfo(from: decoder)

        identifier = assetInfo.assetId
        assetId = assetInfo.assetId
        name = assetInfo.name
        symbol = assetInfo.symbol
        icon = assetInfo.icon
        precision = assetInfo.precision.description
        visible = assetInfo.visible
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: AssetInfo.CodingKeys.self)

        try container.encode(assetId, forKey: .assetId)
        try container.encode(name, forKey: .name)
        try container.encode(symbol, forKey: .symbol)
        try container.encode(icon, forKey: .icon)
        try container.encode(precision, forKey: .precision)
        try container.encode(visible, forKey: .visible)
    }
}

struct Whitelist: Codable {
    enum CodingKeys: String, CodingKey {
        case symbol
        case name
        case assetId = "address"
        case precision = "decimals"
        case icon
    }
    let symbol: String
    let name: String
    let assetId: String
    let precision: Int
    let icon: String
}
