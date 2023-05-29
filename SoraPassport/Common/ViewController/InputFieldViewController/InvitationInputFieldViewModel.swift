import Foundation

final class LowecasedInputFieldViewModel: InputFieldViewModel {
    override func didReceive(replacement: String, in range: NSRange) -> Bool {
        let lowercased = replacement.lowercased()
        let result = super.didReceive(replacement: lowercased, in: range)
        return result && lowercased == replacement
    }
}
