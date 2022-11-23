import UIKit
import SoraUI
import CommonWallet

final class AddConfirmHeaderView: UIView, WalletFormBordering {
    var borderType: BorderType  = .top

    @IBOutlet private(set) var sourceName: UILabel!
    @IBOutlet private(set) var sourceAmount: UILabel!
    @IBOutlet private(set) var sourceIcon: UIImageView!

    @IBOutlet private(set) var targetName: UILabel!
    @IBOutlet private(set) var targetAmount: UILabel!
    @IBOutlet private(set) var targetIcon: UIImageView!

    @IBOutlet private(set) var estimationLabel: UILabel!

    override func awakeFromNib() {
//        self.assetLabel.font = UIFont.styled(for: .display2, isBold: true)
    }
    
    func bind(viewModel: SoraAddLiquidityHeaderViewModel) {
        var poolName:String = ""
        if let concreteViewModel = viewModel.sourceAsset as? WalletTokenViewModel,
           let iconViewModel = concreteViewModel.iconViewModel {
            iconViewModel.loadImage { [weak self] (icon, _) in
                self?.sourceIcon.image = icon
            }
            poolName.append(concreteViewModel.title)
            poolName.append("–")
//            self.sourceName.text = concreteViewModel.title
//            self.sourceAmount.text = concreteViewModel.details
        } else {
//            self.sourceIcon.image = viewModel.icon
        }
        if let concreteViewModel = viewModel.targetAsset as? WalletTokenViewModel,
           let iconViewModel = concreteViewModel.iconViewModel {
            iconViewModel.loadImage { [weak self] (icon, _) in
                self?.targetIcon.image = icon
            }
            poolName.append(concreteViewModel.title)
//            self.targetName.text = concreteViewModel.title
//            self.targetAmount.text = concreteViewModel.details
        } else {
//            self.sourceIcon.image = viewModel.icon
        }
        self.sourceName.text = poolName
        self.sourceAmount.attributedText = viewModel.poolShare
        self.estimationLabel.text = viewModel.estimate

    }
}
