/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

extension NSPredicate {
    static var email: NSPredicate {
        let emailFormat = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return NSPredicate(format: "SELF MATCHES %@", emailFormat)
    }

    static var phone: NSPredicate {
        let phoneFormat = "\\+?[1-9][0-9]{3,14}"
        return NSPredicate(format: "SELF MATCHES %@", phoneFormat)
    }

    static var notEmpty: NSPredicate {
        return NSPredicate(format: "SELF != ''")
    }
}
