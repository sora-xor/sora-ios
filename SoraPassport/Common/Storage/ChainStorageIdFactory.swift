/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

protocol ChainStorageIdFactoryProtocol {
    func createIdentifier(for key: Data) -> String
}

final class ChainStorageIdFactory: ChainStorageIdFactoryProtocol {
    let genesisData: Data

    init(chain: Chain) throws {
        genesisData = try Data(hexString: chain.genesisHash())
    }

    func createIdentifier(for key: Data) -> String {
        (genesisData.prefix(7) + key).toHex()
    }
}
