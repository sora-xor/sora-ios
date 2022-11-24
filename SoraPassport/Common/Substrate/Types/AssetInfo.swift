/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import CoreData
import Foundation
import FearlessUtils
import RobinHood

typealias AssetModel = AssetInfo

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

    init(
        id: String,
        symbol: String,
        chainId: String,
        precision: UInt32,
        icon: String?,
//        priceId: AssetModel.PriceId?,
//        price: Decimal?,
//        transfersEnabled: Bool?,
//        type: ChainAssetType,
//        currencyId: String?,
        displayName: String?,
        visible: Bool
//        existentialDeposit: String?
    ) {
        self.assetId = id
        self.symbol = symbol
//        self.chainId = chainId
        self.precision = precision
        self.icon = icon
//        self.priceId = priceId
//        self.price = price
//        self.transfersEnabled = transfersEnabled
//        self.type = type
//        self.currencyId = currencyId
        self.name = displayName ?? ""
        self.visible = visible
//        self.existentialDeposit = existentialDeposit
    }
}

extension AssetInfo: Identifiable {
    var identifier: String { assetId }
    var id: String { assetId }
}

extension AssetInfo {
    var isFeeAsset: Bool {
        if let asset = WalletAssetId(rawValue: identifier) {
            return asset.isFeeAsset
        } else {
            return false
        }
    }
}

extension AssetModel {
    typealias Id = String
}

extension CDAssetInfo: CoreDataCodable {
    var entityIdentifierFieldName: String { #keyPath(CDAssetInfo.assetId) }

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

extension AssetInfo: Hashable {

    func hash(into hasher: inout Hasher) {
        hasher.combine(assetId)
    }

    static func ==(lhs: AssetInfo, rhs: AssetInfo) -> Bool {
        return lhs.assetId == rhs.assetId
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
