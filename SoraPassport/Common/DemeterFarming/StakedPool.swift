import Foundation
import FearlessUtils
import BigInt

struct StakedPool: Codable {
    var baseAsset: AssetId
    var poolAsset: AssetId
    var rewardAsset: AssetId
    var isFarm: Bool
    @StringCodable var pooledTokens: BigUInt
    @StringCodable var rewards: BigUInt
}
