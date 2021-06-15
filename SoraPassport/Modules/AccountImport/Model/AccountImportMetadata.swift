/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

struct AccountImportMetadata {
    let availableSources: [AccountImportSource]
    let defaultSource: AccountImportSource
    let availableNetworks: [Chain]
    let defaultNetwork: Chain
    let availableCryptoTypes: [CryptoType]
    let defaultCryptoType: CryptoType
}
