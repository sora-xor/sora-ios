/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

typealias CompoundDateFormatterItemBlock = (Date) -> Bool

protocol CompoundDateFormatterItemProtocol {
    func canApply(to date: Date) -> Bool
    func apply(to date: Date) -> String
}

final class CompoundDateFormatterConstantItem: CompoundDateFormatterItemProtocol {
    private(set) var title: String
    private(set) var checkBlock: CompoundDateFormatterItemBlock

    init(title: String, checkBlock: @escaping CompoundDateFormatterItemBlock) {
        self.title = title
        self.checkBlock = checkBlock
    }

    func canApply(to date: Date) -> Bool {
        return checkBlock(date)
    }

    func apply(to date: Date) -> String {
        return title
    }
}

final class CompoundDateFormatterItem: CompoundDateFormatterItemProtocol {
    private(set) var dateFormatter: DateFormatter
    private(set) var checkBlock: CompoundDateFormatterItemBlock

    init(dateFormatter: DateFormatter, checkBlock: @escaping CompoundDateFormatterItemBlock) {
        self.dateFormatter = dateFormatter
        self.checkBlock = checkBlock
    }

    func canApply(to date: Date) -> Bool {
        return checkBlock(date)
    }

    func apply(to date: Date) -> String {
        return dateFormatter.string(from: date)
    }
}

final class CompoundDateFormatter: DateFormatter {
    private(set) var items: [CompoundDateFormatterItemProtocol] = []

    init(items: [CompoundDateFormatterItemProtocol]) {
        self.items = items

        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func string(from date: Date) -> String {
        for item in items {
            if item.canApply(to: date) {
                return item.apply(to: date)
            }
        }

        return super.string(from: date)
    }
}

protocol CompoundDateFormatterBuilderProtocol {
    func withToday(title: String) -> Self
    func withYesterday(title: String) -> Self
    func withThisYear(dateFormatter: DateFormatter) -> Self
    func build(defaultFormat: String?) -> CompoundDateFormatter
}

final class CompoundDateFormatterBuilder: CompoundDateFormatterBuilderProtocol {
    private(set) var baseDate: Date
    private(set) var calendar: Calendar

    private var items: [CompoundDateFormatterItemProtocol] = []

    init(baseDate: Date = Date(), calendar: Calendar = Calendar.current) {
        self.baseDate = baseDate
        self.calendar = calendar
    }

    func withToday(title: String) -> Self {
        let currentCalendar = calendar
        let baseBaseDate = baseDate

        let checkBlock: CompoundDateFormatterItemBlock = { (date) in
            return currentCalendar.compare(baseBaseDate, to: date, toGranularity: .day) == .orderedSame
        }

        let item = CompoundDateFormatterConstantItem(title: title,
                                                     checkBlock: checkBlock)
        items.append(item)

        return self
    }

    func withYesterday(title: String) -> Self {
        let currentCalendar = calendar
        let baseBaseDate = baseDate

        let checkBlock: CompoundDateFormatterItemBlock = { (date) in
            guard let nextDate = currentCalendar.date(byAdding: .day, value: 1, to: date) else {
                return false
            }

            return currentCalendar.compare(baseBaseDate, to: nextDate, toGranularity: .day) == .orderedSame
        }

        let item = CompoundDateFormatterConstantItem(title: title,
                                                     checkBlock: checkBlock)
        items.append(item)

        return self
    }

    func withThisYear(dateFormatter: DateFormatter) -> Self {
        let currentCalendar = calendar
        let baseYear = currentCalendar.component(.year, from: baseDate)

        let checkBlock: CompoundDateFormatterItemBlock = { (date) in
            let year = currentCalendar.component(.year, from: date)
            return baseYear == year
        }

        let item = CompoundDateFormatterItem(dateFormatter: dateFormatter,
                                             checkBlock: checkBlock)
        items.append(item)

        return self
    }

    func build(defaultFormat: String?) -> CompoundDateFormatter {
        let formatter = CompoundDateFormatter(items: items)
        formatter.timeZone = calendar.timeZone

        if let dateFormat = defaultFormat {
            formatter.dateFormat = dateFormat
        }

        return formatter
    }
}
