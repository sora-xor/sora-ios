import Foundation

extension DateFormatter {
    static var sectionThisYear: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = R.string.localizable.thisYearFormat()

        return dateFormatter
    }
}
