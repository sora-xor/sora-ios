import Foundation
import SSFUtils

struct PoolPropertiesParams: Codable {
    var baseAsset: AssetId
    var targetAsset: AssetId
}

//extension PoolPropertiesParams: ScaleDecodable {
//    init(scaleDecoder: ScaleDecoding) throws {
//        baseAsset = try AssetId(scaleDecoder: scaleDecoder)
//        targetAsset = try AssetId(scaleDecoder: scaleDecoder)
//    }
//}
