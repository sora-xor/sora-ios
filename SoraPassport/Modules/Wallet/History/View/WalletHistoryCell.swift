import Anchorage
import CommonWallet
import SoraFoundation
import SoraUI
import UIKit

class WalletHistoryCell: UITableViewCell {
    @IBOutlet private var iconImageView: UIImageView!
    @IBOutlet private var pendingImageView: UIImageView!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var noteLabel: UILabel!
    @IBOutlet private var amountLabel: UILabel!
    @IBOutlet private var dateLabel: UILabel!
    @IBOutlet private var directionLabel: UILabel!
    @IBOutlet private var stackView: UIStackView!

    private(set) var viewModel: WalletViewModelProtocol?

    override func awakeFromNib() {
        super.awakeFromNib()

        contentView.backgroundColor = R.color.neumorphism.base()
    }
}

extension WalletHistoryCell: WalletViewProtocol {

    func addImageView() -> UIImageView {
        let imageView = UIImageView(frame: .zero)
        imageView.widthAnchor == 14
        imageView.heightAnchor == 14
        stackView.addArrangedSubview(imageView)
        return imageView
    }

    func bind(viewModel: WalletViewModelProtocol) {
        if let transactionViewModel = viewModel as? HistoryItemViewModel {
            self.viewModel = transactionViewModel

            iconImageView.image = transactionViewModel.imageViewModel?.image
            titleLabel.text = transactionViewModel.title
            amountLabel.attributedText = transactionViewModel.amount
            dateLabel.text = transactionViewModel.details
            directionLabel.text = transactionViewModel.type.localizedName

            dateLabel.font = UIFont.styled(for: .paragraph2, isBold: false).withSize(15)

            directionLabel.font = UIFont.styled(for: .uppercase2, isBold: false).withSize(15)
            if transactionViewModel.type == .swap {
                titleLabel.font = UIFont.styled(for: .paragraph2, isBold: true)
            } else {
                titleLabel.font = UIFont.styled(for: .paragraph3, isBold: false)
            }

            for subview in stackView.arrangedSubviews {
                stackView.removeArrangedSubview(subview)
                subview.removeFromSuperview()
            }

            if let assetViewModel = transactionViewModel.assetImageViewModel {
                let imageView = addImageView()
                assetViewModel.loadImage { [weak imageView] image, error in
                    if error == nil {
                        imageView?.image = image
                    } else {
                        print(error!.localizedDescription)
                    }
                }
            }

            if let peerViewModel = transactionViewModel.peerImageViewModel {
                let arrowImageView = addImageView()
                arrowImageView.image = R.image.assetArrow()

                let imageView = addImageView()
                peerViewModel.loadImage { [weak imageView] image, error in
                    if error == nil {
                        imageView?.image = image
                    } else {
                        print(error!.localizedDescription)
                    }
                }
            }

        } else

        if let transactionViewModel = viewModel as? HistorySwapViewModel {  self.viewModel = transactionViewModel

            iconImageView.image = transactionViewModel.imageViewModel?.image
            titleLabel.attributedText = transactionViewModel.title
            amountLabel.attributedText = transactionViewModel.amount
            dateLabel.text = transactionViewModel.details
            directionLabel.text = transactionViewModel.type.localizedName

            dateLabel.font = UIFont.styled(for: .paragraph2, isBold: false).withSize(15)

            directionLabel.font = UIFont.styled(for: .uppercase2, isBold: false).withSize(15)


            for subview in stackView.arrangedSubviews {
                stackView.removeArrangedSubview(subview)
                subview.removeFromSuperview()
            }

            if let assetViewModel = transactionViewModel.assetImageViewModel {
                let imageView = addImageView()
                assetViewModel.loadImage { [weak imageView] image, error in
                    if error == nil {
                        imageView?.image = image
                    } else {
                        print(error!.localizedDescription)
                    }
                }
            }

            if let peerViewModel = transactionViewModel.peerImageViewModel {
                let arrowImageView = addImageView()
                arrowImageView.image = R.image.assetArrow()

                let imageView = addImageView()
                peerViewModel.loadImage { [weak imageView] image, error in
                    if error == nil {
                        imageView?.image = image
                    } else {
                        print(error!.localizedDescription)
                    }
                }
            }

        }
        preservesSuperviewLayoutMargins = false
        separatorInset = UIEdgeInsets.zero
        layoutMargins = UIEdgeInsets.zero

        setNeedsLayout()
    }
}
