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
    case undefinedAssets
}

final class WalletPrimitiveFactory: WalletPrimitiveFactoryProtocol {
    let keystore: KeystoreProtocol
    let settings: SettingsManagerProtocol

    init(keystore: KeystoreProtocol,
         settings: SettingsManagerProtocol) {
        self.keystore = keystore
        self.settings = settings
    }

    private func createAssetForInfo(_ info: AssetInfo) -> WalletAsset {

        return WalletAsset(identifier: info.assetId,
                           name: LocalizableResource<String> { _ in info.symbol },
                           platform: LocalizableResource<String> { _ in info.name },
                           symbol: info.symbol,
                           precision: Int16(info.precision),
                           modes: .all)
    }

    func createAccountSettings() throws -> WalletAccountSettingsProtocol {
        guard let selectedAccount = settings.selectedAccount else {
            throw WalletPrimitiveFactoryError.missingAccountId
        }

        let assets = AssetManager.shared.getAssetList()?
            .map {createAssetForInfo($0)}

        guard let assetList = assets else {
            throw WalletPrimitiveFactoryError.undefinedAssets
        }

        let selectedConnectionType = settings.selectedConnection.type

//        let totalPriceAsset = WalletAsset(identifier: WalletAssetId.usd.rawValue,
//                                          name: LocalizableResource { _ in "" },
//                                          platform: LocalizableResource { _ in "" },
//                                          symbol: "$",
//                                          precision: 2,
//                                          modes: .view)

        let accountId = try SS58AddressFactory().accountId(fromAddress: selectedAccount.address,
                                                           type: selectedConnectionType)

        return WalletAccountSettings(accountId: accountId.toHex(),
                                     assets: assetList)
    }
}
