import Foundation

protocol ReputationDelayFactoryProtocol {
    func calculateDelay(from date: Date) -> TimeInterval
}

struct ReputationDelayFactory: ReputationDelayFactoryProtocol {
    func calculateDelay(from date: Date) -> TimeInterval {
        var calendar = Calendar(identifier: .gregorian)

        guard let timeZone = TimeZone(secondsFromGMT: 0) else {
            return 0.0
        }

        calendar.timeZone = timeZone

        // reputation is calculated 13:37 JST every day
        guard var nextCalculationDate = calendar
            .date(bySettingHour: 4, minute: 37, second: 0, of: date) else {
                return 0.0
        }

        if date.compare(nextCalculationDate) == .orderedDescending {
            guard let nextDate = calendar.date(byAdding: .day,
                                               value: 1,
                                               to: nextCalculationDate) else {
                return 0.0
            }

            nextCalculationDate = nextDate
        }

        return nextCalculationDate.timeIntervalSince(date)
    }
}
