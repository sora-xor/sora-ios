// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import SSFUtils

protocol AccountImportJsonFactoryProtocol {
    func createInfo(from definition: KeystoreDefinition) throws -> AccountImportPreferredInfo
}

final class AccountImportJsonFactory {
    func createInfo(from definition: KeystoreDefinition) throws -> AccountImportPreferredInfo {
        let info = try KeystoreInfoFactory().createInfo(from: definition)

        let chain: Chain?
        let networkTypeConfirmed: Bool

        if let definitionGenesisHashString = definition.meta?.genesisHash,
           let definitionGenesisHash = try? Data(hexStringSSF: definitionGenesisHashString),
           let genesisBasedChain = Chain.allCases
            .first(where: { definitionGenesisHash == (try? Data(hexStringSSF: $0.genesisHash())) }) {
            chain = genesisBasedChain
            networkTypeConfirmed = true
        } else {
            chain = .sora
            networkTypeConfirmed = false
        }

        return AccountImportPreferredInfo(username: info.meta?.name,
                                          networkType: chain,
                                          cryptoType: CryptoType(type: info.cryptoType.stringValue),
                                          networkTypeConfirmed: networkTypeConfirmed)
    }
}
