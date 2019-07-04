/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

extension RegistrationDataError: ErrorContentConvertible {
    func toErrorContent() -> ErrorContent {
        switch self {
        case .applicationFormNotFound:
            return ErrorContent(title: R.string.localizable.errorTitle(),
                                message: R.string.localizable.registrationApplicationNotFoundErrorMessage())
        case .invitationCodeNotFound:
            return ErrorContent(title: R.string.localizable.errorTitle(),
                                message: R.string.localizable.invitationCodeNotFoundErrorMessage())
        }
    }
}
