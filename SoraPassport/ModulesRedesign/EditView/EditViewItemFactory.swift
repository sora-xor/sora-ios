import Foundation
import SoraUIKit
import SoraFoundation

protocol EditViewItemFactoryProtocol: AnyObject {
    func enabledItem(with editViewModel: EditViewModel) -> SoramitsuTableViewItemProtocol
    func disabledItem(with editViewModel: EditViewModel) -> SoramitsuTableViewItemProtocol
}

final class EditViewItemFactory: EditViewItemFactoryProtocol {
    
    func enabledItem(with editViewModel: EditViewModel) -> SoramitsuTableViewItemProtocol {
        let enabledItem = EnabledItem(title: R.string.localizable.commonEnabled(preferredLanguages: .currentLocale))
        
        enabledItem.onTap = { [weak self] in
         
        }
        
        enabledItem.enabledViewModels = [
            EnabledViewModel(title: R.string.localizable.moreMenuSoraCardTitle(preferredLanguages: .currentLocale), isEnabled: true),
            EnabledViewModel(title: R.string.localizable.commonBuyXor(preferredLanguages: .currentLocale), isEnabled: true),
            EnabledViewModel(title: R.string.localizable.liquidAssets(preferredLanguages: .currentLocale), isEnabled: true),
            EnabledViewModel(title: R.string.localizable.pooledAssets(preferredLanguages: .currentLocale), isEnabled: true)
        ]
        
        return enabledItem
    }
    
    func disabledItem(with editViewModel: EditViewModel) -> SoramitsuTableViewItemProtocol {
        let enabledItem = EnabledItem(title: R.string.localizable.commonDisabled(preferredLanguages: .currentLocale))
        return enabledItem
    }
}
