import Foundation
import IrohaCrypto

extension SNAddressType {
    func titleForLocale(_ locale: Locale) -> String {
        return "Sora"
    }
//
    var icon: UIImage? {
        return R.image.iconSora()
    }

//    static var supported: [SNAddressType] {
//        [/*.kusamaMain, .polkadotMain, */.genericSubstrate, .soraMain]
//    }
}
