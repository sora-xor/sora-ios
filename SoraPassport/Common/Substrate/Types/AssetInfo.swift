// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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
    var fiatPrice: Decimal?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        symbol = try container.decode(String.self, forKey: .symbol)
        name = try container.decode(String.self, forKey: .name)
        assetId = try container.decode(String.self, forKey: .assetId)
        precision = try container.decode(StringCodable<UInt32>.self, forKey: .precision).wrappedValue
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        visible = try container.decodeIfPresent(Bool.self, forKey: .visible) ?? false
        fiatPrice = try container.decodeIfPresent(Decimal.self, forKey: .visible)
    }

    init(
        id: String,
        symbol: String,
        chainId: String,
        precision: UInt32,
        icon: String?,
        displayName: String?,
        visible: Bool
    ) {
        self.assetId = id
        self.symbol = symbol
        self.precision = precision
        self.icon = icon
        self.name = displayName ?? ""
        self.visible = visible
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

extension AssetInfo {
    static let xor = AssetInfo(
        id: WalletAssetId.xor.rawValue,
        symbol: "XOR",
        chainId: "",
        precision: 18,
        icon: nil,
        displayName: nil,
        visible: true
    )
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
