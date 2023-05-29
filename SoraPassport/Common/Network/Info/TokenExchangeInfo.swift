import Foundation

struct TokenExchangeInfo: Codable {
    enum CodingKeys: String, CodingKey {
        case oldToken
        case newToken
    }

    var oldToken: String?
    var newToken: String

    init(newToken: String, oldToken: String? = nil) {
        self.newToken = newToken
        self.oldToken = oldToken
    }
}
