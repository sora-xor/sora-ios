import CommonWallet
import SoraKeystore
import SoraFoundation

extension WalletAsset {

    var isFeeAsset: Bool {
        if let asset = WalletAssetId(rawValue: identifier) {
            return asset.isFeeAsset
        } else {
            return false
        }
    }

    var chain: Chain {
        return .sora
    }

    static var dummyAsset: WalletAsset {
        WalletAsset(identifier: "0xF2F0000000000000000000000000000000000000000000000000000000000000",
                           name: LocalizableResource<String> { _ in "info.symbol" },
                           platform: LocalizableResource<String> { _ in "info.name" },
                           symbol: "info.symbol",
                           precision: Int16(18),
                           modes: .transfer)
    }
}
