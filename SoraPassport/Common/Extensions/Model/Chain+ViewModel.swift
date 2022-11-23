import UIKit

extension Chain {
    func titleForLocale(_ locale: Locale) -> String {
        switch self {
        case .polkadot:
            return "Polkadot"
//        case .kusama:
//            return "Kusama"
        case .sora:
            return "Sora"
        }
    }

    var icon: UIImage? {
        switch self {
        case .polkadot:
            return R.image.iconSora()//iconPolkadotSmallBg()
//        case .kusama:
//            return R.image.iconKsmSmallBg()
        case .sora:
            return R.image.iconSora()
        }
    }
}
