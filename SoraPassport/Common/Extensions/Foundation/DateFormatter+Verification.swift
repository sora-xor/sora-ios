import Foundation

extension DateFormatter {
    static var retryDelay: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "mm:ss"
        return dateFormatter
    }
}
