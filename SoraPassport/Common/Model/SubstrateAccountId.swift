/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import IrohaCrypto

final class AccountIdWrapper: IRPublicKeyProtocol {
    let data: Data

    init(rawData data: Data) throws {
        self.data = data
    }

    func rawData() -> Data { data }
}
