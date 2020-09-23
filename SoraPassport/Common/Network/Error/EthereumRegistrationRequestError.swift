/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

enum EthereumInitDataError: Error {
    case notFound

    static func error(from status: StatusData) -> EthereumInitDataError? {
        switch status.code {
        case "BOUND_ETH_ADDRESS_NOT_FOUND":
            return notFound
        default:
            return nil
        }
    }
}
