// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import CoreData
import Foundation
import SSFUtils
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
        fiatPrice = nil
        // Saved copies may come from a node an earlier build trusted.
        if let pinned = WalletAssetPrecision.pinned(for: assetId) {
            precision = pinned
        }
        normalizeNativeAssetMetadata()
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
        normalizeNativeAssetMetadata()
    }

    mutating func normalizeNativeAssetMetadata() {
        // Remote and cached display metadata must not rename the native XOR asset.
        guard assetId == WalletAssetId.xor.rawValue else { return }
        name = "XOR"
        symbol = "XOR"
    }
}

/// Asset decimals that no node can change. SORA2 registers its predefined
/// assets with `DEFAULT_BALANCE_PRECISION` (18) at genesis, and its assets
/// pallet refuses any precision above `MAX_ALLOWED_PRECISION` (18). A node
/// that reported more decimals for XOR would turn a confirmed 1 XOR into 100
/// signed, so the app never takes these values from a node.
enum WalletAssetPrecision {
    static let maximum: UInt32 = 18

    private static let predefined: [String: UInt32] = Dictionary(uniqueKeysWithValues: [
        WalletAssetId.xor.rawValue, WalletAssetId.val.rawValue, WalletAssetId.pswap.rawValue,
        WalletAssetId.xst.rawValue, WalletAssetId.xstusd.rawValue, WalletAssetId.tbcd.rawValue,
        WalletAssetId.kusd.rawValue, WalletAssetId.eth, WalletAssetId.kxor
    ].map { ($0, 18) })

    static func pinned(for assetId: String) -> UInt32? {
        predefined[assetId.lowercased()]
    }

    /// False for a precision the runtime cannot hold, so the node lied.
    static func isPossible(_ precision: UInt32) -> Bool {
        precision <= maximum
    }

    /// The decimals a signed amount of this asset is scaled by: the runtime's
    /// fixed value for a predefined asset, the asset's own otherwise. Nil when
    /// the runtime could not hold them.
    static func signing(for asset: WalletAsset) -> Int16? {
        let precision = pinned(for: asset.identifier).map(Int16.init) ?? asset.precision
        guard precision >= 0, isPossible(UInt32(precision)) else { return nil }
        return precision
    }
}

/// The decimals of the two assets of a swap, as the signer scales them.
struct SwapAssetPrecisions: Equatable {
    let source: Int16
    let destination: Int16

    /// Nil unless both assets are among the account's assets, differ, have
    /// decimals the runtime can hold, and those decimals are the ones the
    /// review scaled its amounts by. The account's assets are a snapshot;
    /// if the asset list the screens read has since given a token other
    /// decimals, 10.01 reviewed with 2 decimals must not be signed as
    /// 100100 units of 4.
    init?(info: TransferInfo, assets: [WalletAsset]) {
        guard info.asset != info.destination,
              let sourceAsset = assets.first(where: { $0.identifier == info.asset }),
              let destinationAsset = assets.first(where: { $0.identifier == info.destination }),
              let source = WalletAssetPrecision.signing(for: sourceAsset),
              let destination = WalletAssetPrecision.signing(for: destinationAsset),
              let context = info.context,
              let reviewedSource = context[TransactionContextKeys.sourcePrecision].flatMap({ Int16($0) }),
              let reviewedDestination = context[TransactionContextKeys.destinationPrecision].flatMap({ Int16($0) }),
              reviewedSource == source,
              reviewedDestination == destination else {
            return nil
        }
        self.source = source
        self.destination = destination
    }

    init(source: Int16, destination: Int16) {
        self.source = source
        self.destination = destination
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
