import Foundation
import SoraUIKit
import SoraFoundation

protocol EditViewItemFactoryProtocol: AnyObject {
    func enabledItem(with editViewModel: EditViewModel) -> SoramitsuTableViewItemProtocol
    func disabledItem(with editViewModel: EditViewModel) -> SoramitsuTableViewItemProtocol
}

final class EditViewItemFactory: EditViewItemFactoryProtocol {
    
    func enabledItem(with editViewModel: EditViewModel) -> SoramitsuTableViewItemProtocol {
        
    }
    
    func disabledItem(with editViewModel: EditViewModel) -> SoramitsuTableViewItemProtocol {
        
    }
}
