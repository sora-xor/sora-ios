import FearlessUtils

struct InitializePoolCall: Codable {
    let dexId: String
    var assetA: AssetId
    var assetB: AssetId

    enum CodingKeys: String, CodingKey {
        case dexId = "dexId"
        case assetA = "assetA"
        case assetB = "assetB"
    }
}
