/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

enum RemoteEnviroment: String, CaseIterable {
    case development = "dev"
    case test = "tst"
    case staging = "stg"
    case release = ""
}
