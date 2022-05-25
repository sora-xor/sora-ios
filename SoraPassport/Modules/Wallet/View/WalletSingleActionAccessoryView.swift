import UIKit
import CommonWallet
import SoraUI

final class WalletSingleActionAccessoryView: UIView {
    @IBOutlet private(set) var actionButton: NeumorphismButton!
}

extension WalletSingleActionAccessoryView: CommonWallet.AccessoryViewProtocol {
    var contentView: UIView {
        self
    }

    var isActionEnabled: Bool {
        get {
            actionButton.isEnabled
        }
        set(newValue) {
            actionButton.isEnabled = newValue
        }
    }

    var extendsUnderSafeArea: Bool { true }

    func bind(viewModel: AccessoryViewModelProtocol) {
        actionButton.setTitle(viewModel.action, for: .normal)
//        actionButton.color
    }
}
