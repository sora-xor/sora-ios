import FearlessUtils

struct SetReferrerCall: Codable {
    let referrer: MultiAddress

    enum CodingKeys: String, CodingKey {
        case referrer = "referrer"
    }
}
