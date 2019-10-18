import Foundation

struct UserCreationInfo: Codable {
    var phone: String

    init(phone: String) {
        self.phone = phone
    }

    init(dialCode: String, localPhone: String) {
        phone = dialCode + localPhone
    }
}
