/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

struct AccountImportMnemonicRequest {
    let mnemonic: String
    let username: String
    let networkType: Chain
    let derivationPath: String
    let cryptoType: CryptoType
}

struct AccountImportSeedRequest {
    let seed: String
    let username: String
    let networkType: Chain
    let derivationPath: String
    let cryptoType: CryptoType
}

struct AccountImportKeystoreRequest {
    let keystore: String
    let password: String
    let username: String
    let networkType: Chain
    let cryptoType: CryptoType
}
