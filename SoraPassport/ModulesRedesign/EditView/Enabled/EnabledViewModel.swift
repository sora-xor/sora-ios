import Foundation
import UIKit
import CommonWallet
import SoraUIKit

struct EnabledViewModel {
    
    let title: String
    let isEnabled: Bool
    
    init(title: String,
         isEnabled: Bool) {
        self.title = title
        self.isEnabled = isEnabled
    }
    
}
