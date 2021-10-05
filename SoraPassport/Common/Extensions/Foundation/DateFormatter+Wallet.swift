/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraFoundation

extension DateFormatter {
    static var history: LocalizableResource<DateFormatter> {
        LocalizableResource { locale in
            let format = DateFormatter.dateFormat(fromTemplate: "ddMMyyyyHHmmss", options: 0, locale: locale)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = format
            dateFormatter.locale = locale
            return dateFormatter
        }
    }

    static var transactionDetails: LocalizableResource<DateFormatter> {
        LocalizableResource { locale in
            let format = DateFormatter.dateFormat(fromTemplate: "ddMMMyyyyHHmmss", options: 0, locale: locale)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = format
            dateFormatter.locale = locale
            return dateFormatter
        }
    }
}
