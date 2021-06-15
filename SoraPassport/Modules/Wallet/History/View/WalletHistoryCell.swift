import UIKit
import CommonWallet
import SoraUI

final class WalletHistoryCell: UITableViewCell {
    @IBOutlet private var iconImageView: UIImageView!
    @IBOutlet private var pendingImageView: UIImageView!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var noteLabel: UILabel!
    @IBOutlet private var amountLabel: UILabel!
    @IBOutlet private var dateLabel: UILabel!

    @IBOutlet private var titleLabelCenterConstraints: NSLayoutConstraint!
    @IBOutlet private var titleLabelTopConstraints: NSLayoutConstraint!

    private(set) var viewModel: WalletViewModelProtocol?

    override func awakeFromNib() {
        super.awakeFromNib()
        titleLabel.font = UIFont.styled(for: .paragraph3, isBold: false)
        noteLabel.font = UIFont.styled(for: .paragraph4)
        amountLabel.font = UIFont.styled(for: .paragraph2, isBold: true)
        dateLabel.font = UIFont.styled(for: .paragraph4)
        pendingImageView.isHidden = true
    }

    private struct Constants {
        static let animationPath = "transform.rotation.z"
        static let animationKey = "loading.animation.key"
        static let animationDuration = 1.0
    }

    private func createAnimation() -> CAAnimation {
        let animation = CAKeyframeAnimation(keyPath: Constants.animationPath)
        animation.values = [0.0, CGFloat.pi, 2.0 * CGFloat.pi]
        animation.timingFunctions = [CAMediaTimingFunction(name: .easeIn), CAMediaTimingFunction(name: .easeOut)]
        animation.calculationMode = .linear
        animation.keyTimes = [0.0, 0.5, 1.0]
        animation.repeatDuration = TimeInterval.infinity
        animation.duration = Constants.animationDuration
        animation.isCumulative = false
        return animation
    }
}

extension WalletHistoryCell: WalletViewProtocol {
    func bind(viewModel: WalletViewModelProtocol) {
        if let transactionViewModel = viewModel as? HistoryItemViewModel {
            self.viewModel = transactionViewModel
            pendingImageView.isHidden = true
            pendingImageView.layer.removeAnimation(forKey: Constants.animationKey)

            iconImageView.image = transactionViewModel.imageViewModel?.image
            titleLabel.text = transactionViewModel.title
            noteLabel.text = ""
            amountLabel.text = transactionViewModel.amount
            dateLabel.text = transactionViewModel.details

            amountLabel.textColor = transactionViewModel.direction == .incoming ?
                R.color.statusSuccess()! :
                R.color.baseContentPrimary()!
            amountLabel.font = transactionViewModel.status == .rejected ?
                UIFont.styled(for: .paragraph2, isBold: false) :
                UIFont.styled(for: .paragraph2, isBold: true)

            if transactionViewModel.status == .rejected {
                amountLabel.textColor = R.color.statusError()!
            } else if transactionViewModel.status == .pending {
                pendingImageView.isHidden = false
                let animation = createAnimation()
                pendingImageView.layer.add(animation, forKey: Constants.animationKey)
            }

            titleLabelCenterConstraints.isActive = true
            titleLabelTopConstraints.isActive = false

            setNeedsLayout()
        }
    }
}
