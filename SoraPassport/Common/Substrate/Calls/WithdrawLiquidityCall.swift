import FearlessUtils
import BigInt

struct WithdrawLiquidityCall: Codable {
    let dexId: String
    var assetA: AssetId
    var assetB: AssetId
    @StringCodable var assetDesired: BigUInt
    @StringCodable var minA: BigUInt
    @StringCodable var minB: BigUInt

    enum CodingKeys: String, CodingKey {
        case dexId = "dexId"
        case assetA = "outputAssetA"
        case assetB = "outputAssetB"
        case assetDesired = "markerAssetDesired"
        case minA = "outputAMin"
        case minB = "outputBMin"
    }
}
