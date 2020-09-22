/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

enum WalletServiceType: String {
    case balance
    case history
    case search
    case transfer
    case transferMetadata
    case contacts
    case withdraw
    case withdrawalMetadata
    case ethereumRegistration
    case ethereumState
}
