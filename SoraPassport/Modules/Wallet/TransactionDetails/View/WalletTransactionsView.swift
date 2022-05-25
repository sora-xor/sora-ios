import UIKit
import SoraUI
import CommonWallet

final class WalletTransactionsView: UIView {
    @IBOutlet private var borderView: BorderedContainerView!
    @IBOutlet private var ethereumButton: RoundedButton!
    @IBOutlet private var soranetButton: RoundedButton!

    @IBOutlet private var top: NSLayoutConstraint!
    @IBOutlet private var bottom: NSLayoutConstraint!

    @IBOutlet private var leadingWhenEthereumExists: NSLayoutConstraint!
    @IBOutlet private var leadingWhenOnlySoranet: NSLayoutConstraint!

    private(set) var viewModel: WalletTransactionsViewModel?

    func bind(viewModel: WalletTransactionsViewModel) {
        self.viewModel = viewModel

        ethereumButton.isHidden = viewModel.ethereumCommand == nil
        soranetButton.isHidden = viewModel.soranetCommand == nil

        setNeedsLayout()
    }

    // MARK: Action

    @IBAction private func actionEthereum() {
        try? viewModel?.ethereumCommand?.execute()
    }

    @IBAction private func actionSoranet() {
        try? viewModel?.soranetCommand?.execute()
    }
}

extension WalletTransactionsView: WalletFormBordering {
    var borderType: BorderType {
        get {
            borderView.borderType
        }
        set(newValue) {
            borderView.borderType = newValue
        }
    }
}
