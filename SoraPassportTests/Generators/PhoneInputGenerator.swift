import Foundation

func createRandomPhoneInput() -> String {
    return (0..<10).map { _ in
        return String((0..<10).randomElement()!)
    }.joined(separator: "")
}
