/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

enum AccountOperationFactoryError: Error {
    case invalidKeystore
    case unsupportedNetwork
    case decryption
    case missingUsername
}
