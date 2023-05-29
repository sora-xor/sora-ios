import Foundation
import SoraFoundation

final class MneminicProcessor: TextProcessing {
    func process(text: String) -> String {
        return text.condensed
    }
}

extension String {
    /// Returns a condensed string, with no extra whitespaces and no new lines.
    var condensed: String {
        return replacingOccurrences(of: "[\\s\n\t]+", with: " ", options: .regularExpression, range: nil)
    }
}
