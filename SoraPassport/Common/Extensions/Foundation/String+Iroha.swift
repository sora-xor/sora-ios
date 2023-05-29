import Foundation

extension String {
    func replacingOccurrencesOfIrohaSpecialCharacters() -> String {
        replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "\n", with: "\\n")
    }
}
