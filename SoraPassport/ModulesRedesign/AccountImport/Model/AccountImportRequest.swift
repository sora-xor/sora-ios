import Foundation
import SSFCloudStorage

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

struct AccountImportBackedupRequest {
    let account: OpenBackupAccount
    let password: String
}
