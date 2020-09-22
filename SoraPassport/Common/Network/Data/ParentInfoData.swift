import Foundation

struct ParentInfoData: Codable, Equatable {
    var firstName: String
    var lastName: String
}

extension ParentInfoData {
    var fullName: String {
        return "\(firstName) \(lastName)"
    }
}
