import Foundation

struct VerificationCodeData: Decodable {
    enum CodingKeys: String, CodingKey {
        case status
        case delay = "blockingTime"
    }

    var status: StatusData
    var delay: Int?
}
