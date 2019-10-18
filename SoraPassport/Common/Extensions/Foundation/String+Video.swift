import Foundation

extension String {
    static func displayDuration(from seconds: Int) -> String {
        let remainedSeconds = seconds % 60
        let minutes = (seconds / 60) % 60
        let hours = (seconds / 60) / 60

        let result = [minutes, remainedSeconds].map { (value: Int) -> String in
            if value > 9 {
                return String(value)
            } else {
                return "0\(value)"
            }
        }.joined(separator: ":")

        if hours > 0 {
            return "\(hours):\(result)"
        } else {
            return result
        }
    }
}
