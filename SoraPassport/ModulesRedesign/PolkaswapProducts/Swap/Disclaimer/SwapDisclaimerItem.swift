import Foundation
import SoraUIKit
import CommonWallet
import RobinHood

final class SwapDisclaimerItem: NSObject {
    
    var closeButtonHandler: (() -> Void)?
}

extension SwapDisclaimerItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { SwapDisclaimerCell.self }

    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }

    var clipsToBounds: Bool { false }
}
