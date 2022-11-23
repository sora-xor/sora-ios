import UIKit
import SoraUI
import CommonWallet

final class TransactionDetailsHeaderView: UIView, WalletFormBordering {
    var borderType: BorderType  = [.top, .bottom]

    @IBOutlet private(set) var assetLabel: UILabel!
    @IBOutlet private(set) var assetNameLabel: UILabel!
    @IBOutlet private(set) var assetIcon: UIImageView!

    override func awakeFromNib() {
        self.assetLabel.font = UIFont.styled(for: .display2, isBold: true)
    }

    func bind(viewModel: SoraTransactionHeaderViewModel) {

    }
    
    func bind(viewModel: AssetSelectionViewModelProtocol) {
        if let concreteViewModel = viewModel as? WalletTokenViewModel,
           let iconViewModel = concreteViewModel.iconViewModel {
            iconViewModel.loadImage { [weak self] (icon, _) in
                self?.assetIcon.image = icon
            }
            self.assetNameLabel.text = concreteViewModel.header
        } else {
            self.assetIcon.image = viewModel.icon
        }
        self.assetLabel.text = viewModel.details
    }
}

final class TransactionDetailsStatusView: UIView, WalletFormBordering {
    var borderType: BorderType  = .bottom

    @IBOutlet private(set) var titleLabel: UILabel!
    @IBOutlet private(set) var statusLabel: UILabel!
    @IBOutlet private(set) var statusIcon: UIImageView!

    override func awakeFromNib() {
        self.titleLabel.font = UIFont.styled(for: .paragraph1)
        self.statusLabel.font = UIFont.styled(for: .paragraph1, isBold:true)

    }

    func bind(viewModel: SoraTransactionStatusViewModel) {
        titleLabel.text = viewModel.title
        statusLabel.text = viewModel.details
        statusIcon.image = viewModel.detailsIcon
    }

}
