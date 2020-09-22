import Foundation
import CommonWallet

extension SearchData {
    var displayName: String {
        if !firstName.isEmpty, !lastName.isEmpty {
            return "\(firstName) \(lastName)"
        } else if !firstName.isEmpty {
            return firstName
        } else {
            return lastName
        }
    }
}
