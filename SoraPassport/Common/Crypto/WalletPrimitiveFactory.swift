/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet
import SoraKeystore
import SoraFoundation
import IrohaCrypto

protocol WalletPrimitiveFactoryProtocol {
    func createAccountSettings() throws -> WalletAccountSettingsProtocol
}

enum WalletPrimitiveFactoryError: Error {
    case missingAccountId
    case undefinedConnection
}

final class WalletPrimitiveFactory: WalletPrimitiveFactoryProtocol {
    let keystore: KeystoreProtocol
    let settings: SettingsManagerProtocol

    init(keystore: KeystoreProtocol,
         settings: SettingsManagerProtocol) {
        self.keystore = keystore
        self.settings = settings
    }

    private func createAssetForId(_ id: WalletAssetId) -> WalletAsset {
        let localizableName: LocalizableResource<String>
        let platformName: LocalizableResource<String>
        let symbol: String
        let identifier: String
//TODO: asset name online
        switch id {
        case .xor:
            identifier = WalletAssetId.xor.rawValue
            localizableName = LocalizableResource<String> { _ in "XOR" }
            platformName = LocalizableResource<String> { _ in "SORA" }
            symbol = "XOR"
        case .val:
            identifier = WalletAssetId.val.rawValue
            localizableName = LocalizableResource<String> { _ in "VAL" }
            platformName = LocalizableResource<String> { _ in "SORA Validator Token" }
            symbol = "VAL"
        case .pswap:
            identifier = WalletAssetId.pswap.rawValue
            localizableName = LocalizableResource<String> { _ in "PSWAP" }
            platformName = LocalizableResource<String> { _ in "Polkaswap" }
            symbol = "PSWAP"
        }

        return WalletAsset(identifier: identifier,
                           name: localizableName,
                           platform: platformName,
                           symbol: symbol,
                           precision: 18,
                           modes: .all)
    }

    func createAccountSettings() throws -> WalletAccountSettingsProtocol {
        guard let selectedAccount = settings.selectedAccount else {
            throw WalletPrimitiveFactoryError.missingAccountId
        }

        let selectedConnectionType = settings.selectedConnection.type

        let xorAsset = createAssetForId(.xor)
        let valAsset = createAssetForId(.val)
        let pswapAsset = createAssetForId(.pswap)

//        let totalPriceAsset = WalletAsset(identifier: WalletAssetId.usd.rawValue,
//                                          name: LocalizableResource { _ in "" },
//                                          platform: LocalizableResource { _ in "" },
//                                          symbol: "$",
//                                          precision: 2,
//                                          modes: .view)

        let accountId = try SS58AddressFactory().accountId(fromAddress: selectedAccount.address,
                                                           type: selectedConnectionType)

        return WalletAccountSettings(accountId: accountId.toHex(),
                                     assets: [xorAsset, valAsset, pswapAsset])
    }
}
