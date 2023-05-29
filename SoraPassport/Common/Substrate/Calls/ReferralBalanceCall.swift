import FearlessUtils
import BigInt

struct ReferralBalanceCall: Codable {
    @StringCodable var balance: BigUInt

    enum CodingKeys: String, CodingKey {
        case balance = "balance"
    }
}
