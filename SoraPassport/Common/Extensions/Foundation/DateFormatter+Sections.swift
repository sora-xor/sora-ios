/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

extension DateFormatter {
    static var sectionThisYear: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = R.string.localizable.thisYearFormat()

        return dateFormatter
    }

    static var sectionFull: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = R.string.localizable.anyYearFormat()

        return dateFormatter
    }
}
