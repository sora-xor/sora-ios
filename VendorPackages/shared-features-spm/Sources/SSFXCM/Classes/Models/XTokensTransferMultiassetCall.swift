import BigInt
import Foundation
import SSFUtils

struct XTokensTransferMultiassetCall: Codable {
    let asset: XcmVersionedMultiAsset
    let dest: XcmVersionedMultiLocation
    let destWeightLimit: XcmWeightLimit?

    let destWeightIsPrimitive: Bool?
    let destWeight: BigUInt?

    enum CodingKeys: String, CodingKey {
        case asset
        case dest
        case destWeightLimit
        case destWeight
    }

    init(
        asset: XcmVersionedMultiAsset,
        dest: XcmVersionedMultiLocation,
        destWeightLimit: XcmWeightLimit?,
        destWeightIsPrimitive: Bool?,
        destWeight: BigUInt?
    ) {
        self.asset = asset
        self.dest = dest
        self.destWeightLimit = destWeightLimit
        self.destWeightIsPrimitive = destWeightIsPrimitive
        self.destWeight = destWeight
    }

    init(from _: Decoder) throws {
        fatalError("Decoding unsupported")
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        if destWeightIsPrimitive == true {
            try container.encode(asset, forKey: .asset)
            try container.encode(dest, forKey: .dest)
            try container.encode(String(destWeight ?? .zero), forKey: .destWeight)
        } else {
            try container.encode(asset, forKey: .asset)
            try container.encode(dest, forKey: .dest)
            try container.encode(destWeightLimit, forKey: .destWeightLimit)
        }
    }
}
