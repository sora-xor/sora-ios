/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

enum NetworkUnitError: Error {
    case serviceUnavailable
    case brokenServiceEndpoint
    case typeMappingMissing
}
