import Foundation
import FearlessUtils

struct MigrateCall: Codable {
    var irohaAddress: String
    var irohaPublicKey: String
    var irohaSignature: String

    enum CodingKeys: String, CodingKey {
        case irohaAddress = "irohaAddress"
        case irohaPublicKey = "irohaPublicKey"
        case irohaSignature = "irohaSignature"
    }
}
