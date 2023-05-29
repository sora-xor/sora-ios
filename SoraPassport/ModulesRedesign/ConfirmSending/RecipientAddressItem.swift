import Foundation
import SoraUIKit
import CommonWallet
import RobinHood

final class RecipientAddressItem: NSObject {
    
    let address: String
    
    init(address: String) {
        self.address = address
    }
}

extension RecipientAddressItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { RecipientAddressCell.self }
    
    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }
    
    var clipsToBounds: Bool { false }
}
