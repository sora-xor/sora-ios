import FearlessUtils
import BigInt

struct DepositLiquidityCall: Codable {
    let dexId: String
    var assetA: AssetId
    var assetB: AssetId
    @StringCodable var desiredA: BigUInt
    @StringCodable var desiredB: BigUInt
    @StringCodable var minA: BigUInt
    @StringCodable var minB: BigUInt

    enum CodingKeys: String, CodingKey {
        case dexId = "dexId"
        case assetA = "inputAssetA"
        case assetB = "inputAssetB"
        case desiredA = "inputADesired"
        case desiredB = "inputBDesired"
        case minA = "inputAMin"
        case minB = "inputBMin"
    }
}
