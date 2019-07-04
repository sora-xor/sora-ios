/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

extension DateFormatter {
    static var finishedProject: DateFormatter {
        let dateFormatterBuilder = CompoundDateFormatterBuilder()
        let dateFormatter = dateFormatterBuilder
            .withToday(title: R.string.localizable.today())
            .withYesterday(title: R.string.localizable.yesterday())
            .withThisYear(dateFormatter: DateFormatter.shortThisYear)
            .build(defaultFormat: "MMM dd, yyyy")

        return dateFormatter
    }
}
