import Foundation
import CommonWallet

class PolkaswapSlippageSelectorViewModel {
    enum Warning {
        case none
        case mayFail
        case mayBeFrontrun
    }

    var title: String
    var warning: String?
    var description: String
    var buttons: [String]
    var amountInputViewModel: AmountInputViewModel

    init(title: String, warning: String?, description: String, buttons: [String], amountInputViewModel: AmountInputViewModel) {
        self.title = title
        self.warning = warning
        self.description = description
        self.buttons = buttons
        self.amountInputViewModel = amountInputViewModel
    }
}
