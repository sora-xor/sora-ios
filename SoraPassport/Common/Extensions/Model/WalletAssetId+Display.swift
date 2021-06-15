import UIKit

extension WalletAssetId {
    var icon: UIImage? {
        switch self {
        case .xor:
            return R.image.assetXor()
        case .val:
            return R.image.assetVal()
        case .pswap:
            return R.image.assetPSWAP()
        }
    }

    var assetIcon: UIImage? {
        switch self {
        case .xor:
            return R.image.assetXor()
        case .val:
            return R.image.assetVal()
        case .pswap:
            return R.image.assetPSWAP()
        }
    }

    func titleForLocale(_ locale: Locale) -> String {
        switch self {
        case .xor:
            return "Xor"
        case .val:
            return "Val"
        case .pswap:
            return "Pswap"
        }
    }
}
