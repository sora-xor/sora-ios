/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import IrohaCrypto

enum AccessRestoreInteractorError: Error {
    case userMissing
    case documentMissing
    case documentSignerCreationFailed
    case keystoreMissing
    case invalidPassphrase
}
