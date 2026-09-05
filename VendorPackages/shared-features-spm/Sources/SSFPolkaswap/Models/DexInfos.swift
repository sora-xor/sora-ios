import Foundation
import SSFUtils

struct DexInfos: Decodable {
    var baseAssetId: PolkaswapDexInfoAssetId
    var syntheticBaseAssetId: PolkaswapDexInfoAssetId
    var isPublic: Bool
}

struct PolkaswapDexInfoAssetId: Codable {
    @StringCodable var code: String
}
