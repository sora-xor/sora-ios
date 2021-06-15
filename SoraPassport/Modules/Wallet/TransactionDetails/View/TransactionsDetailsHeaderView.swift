import UIKit
import SoraUI
import CommonWallet

final class TransactionDetailsHeaderView: UIView, WalletFormBordering {
    var borderType: BorderType  = .top

    @IBOutlet private(set) var dateLabel: UILabel!
    @IBOutlet private(set) var amountLabel: UILabel!

    override func awakeFromNib() {
        self.dateLabel.font = UIFont.styled(for: .paragraph2)
        self.amountLabel.font = UIFont.styled(for: .display1, isBold: true)

    }

    func bind(viewModel: SoraTransactionHeaderViewModel) {
        self.amountLabel.text = viewModel.title
        self.dateLabel.text = viewModel.details
        switch viewModel.direction {
        case .incoming:
            amountLabel.textColor = R.color.statusSuccess()!
        default:
            amountLabel.textColor = R.color.baseContentPrimary()!
        }

    }
}

final class TransactionDetailsStatusView: UIView, WalletFormBordering {
    var borderType: BorderType  = .bottom

    @IBOutlet private(set) var titleLabel: UILabel!
    @IBOutlet private(set) var statusLabel: UILabel!
    @IBOutlet private(set) var statusIcon: UIImageView!

    override func awakeFromNib() {
        self.titleLabel.font = UIFont.styled(for: .paragraph2)
        self.statusLabel.font = UIFont.styled(for: .paragraph2)

    }

    func bind(viewModel: SoraTransactionStatusViewModel) {
        titleLabel.text = viewModel.title
        statusLabel.text = viewModel.details
        statusIcon.image = viewModel.detailsIcon
    }

}
