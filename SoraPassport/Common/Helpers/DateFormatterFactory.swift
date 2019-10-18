/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

protocol DateFormatterFactoryProtocol {
    static func createDateFormatter() -> DateFormatter
}

struct EventListDateFormatterFactory: DateFormatterFactoryProtocol {
    static func createDateFormatter() -> DateFormatter {
        let dateFormatterBuilder = CompoundDateFormatterBuilder(baseDate: Date())
        return dateFormatterBuilder
            .withToday(title: R.string.localizable.today())
            .withYesterday(title: R.string.localizable.yesterday())
            .withThisYear(dateFormatter: DateFormatter.sectionThisYear)
            .build(defaultFormat: R.string.localizable.anyYearFormat())
    }
}

struct FinishedProjectDateFormatterFactory: DateFormatterFactoryProtocol {
    static func createDateFormatter() -> DateFormatter {
        let dateFormatterBuilder = CompoundDateFormatterBuilder()
        let dateFormatter = dateFormatterBuilder
            .withToday(title: R.string.localizable.today())
            .withYesterday(title: R.string.localizable.yesterday())
            .withThisYear(dateFormatter: DateFormatter.shortThisYear)
            .build(defaultFormat: R.string.localizable.finishedProjectYearFormat())

        return dateFormatter
    }
}
