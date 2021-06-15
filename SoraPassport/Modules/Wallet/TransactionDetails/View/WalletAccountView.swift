import UIKit
import CommonWallet
import SoraUI

final class WalletAccountView: UIControl {
    @IBOutlet var borderedView: BorderedContainerView!
    @IBOutlet var iconImageView: UIImageView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var accessoryImageView: UIImageView!
    @IBOutlet var top: NSLayoutConstraint!
    @IBOutlet var leading: NSLayoutConstraint!
    @IBOutlet var trailing: NSLayoutConstraint!

    private var viewModel: WalletAccountViewModel?

    var opacityWhenHighlighted: CGFloat = 0.5

    var contentInsets = UIEdgeInsets(top: 8.0, left: 0.0, bottom: 11.0, right: 0.0) {
        didSet {
            top.constant = contentInsets.top

            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    private var preferredWidth: CGFloat = 0.0

    override func awakeFromNib() {
        super.awakeFromNib()

        addTarget(self, action: #selector(actionTap(sender:)), for: .touchUpInside)
    }

    override var intrinsicContentSize: CGSize {
        guard preferredWidth > 0.0 else {
            return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
        }

        let mainIconWidth = iconImageView.intrinsicContentSize.width
        let accessoryIconWidth = accessoryImageView.intrinsicContentSize.width

        let boundingWidth = preferredWidth - mainIconWidth - accessoryIconWidth
            - contentInsets.left - contentInsets.right - leading.constant - trailing.constant
        let boundingSize = CGSize(width: max(boundingWidth, 0.0), height: CGFloat.greatestFiniteMagnitude)

        let titleSize = titleLabel.sizeThatFits(boundingSize)
        let height = titleSize.height + contentInsets.top + contentInsets.bottom
        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }

    override var isHighlighted: Bool {
        didSet {
            let opacity = isHighlighted ? opacityWhenHighlighted : 1.0
            iconImageView.alpha = opacity
            titleLabel.alpha = opacity
            accessoryImageView.alpha = opacity
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if abs(bounds.width - preferredWidth) > CGFloat.leastNormalMagnitude {
            preferredWidth = bounds.width
            invalidateIntrinsicContentSize()
        }
    }

    func bind(viewModel: WalletAccountViewModel) {
        self.viewModel = viewModel

        titleLabel.text = viewModel.title

        switch viewModel.type {
        case .soranet:
            iconImageView.image = R.image.assetXor()
        case .ethereum:
            iconImageView.image = R.image.assetValErc()
        case .val:
            iconImageView.image = R.image.assetVal()
        }

        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    @objc private func actionTap(sender: UIControl) {
        try? viewModel?.command.execute()
    }
}

extension WalletAccountView: WalletFormBordering {
    var borderType: BorderType {
        get {
            borderedView.borderType
        }
        set(newValue) {
            borderedView.borderType = newValue
        }
    }
}
