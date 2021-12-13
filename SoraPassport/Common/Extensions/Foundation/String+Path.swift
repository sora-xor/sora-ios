import Foundation

extension String {
    func appendingPathCompletionRegex() -> String {
        return self + "(/\\S*)?"
    }
}
