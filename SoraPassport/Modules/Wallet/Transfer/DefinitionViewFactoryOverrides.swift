import CommonWallet
import SoraFoundation
import SoraUI
import Foundation

struct TransferDefinitionFactory: OperationDefinitionViewFactoryOverriding {
    func createErrorViewForItem(type: OperationDefinitionType) -> BaseOperationDefinitionErrorView? {
        switch type {
        case .receiver :
            let style = WalletTransferConfigurator.errorStyle
            let view = ContainingErrorView()

            view.titleLabel.textColor = style.inlineErrorStyle.titleColor
            view.titleLabel.font = style.inlineErrorStyle.titleFont

            view.contentInsets = style.contentInsets
            view.horizontalSpacing = style.horizontalSpacing

            view.icon = style.inlineErrorStyle.icon

            return view
        default:
            return nil

        }
    }

    func createAssetView() -> BaseSelectedAssetView? {
        let view = R.nib.soraAssetView.firstView(owner: nil)!

        return view
    }

    func createAmountView() -> BaseAmountInputView? {
        let view = R.nib.soraAmountInputView.firstView(owner: nil)!

        return view
    }

    func createFeeView() -> BaseFeeView? {
        let view = R.nib.soraFeeView.firstView(owner: nil)!

        return view
    }

    func createDescriptionView() -> BaseDescriptionInputView? {
       return EmptyDescriptionInputView()
    }

    func createReceiverView() -> BaseReceiverView? {
        let view = R.nib.soraReceiverView.firstView(owner: nil)!
        
        return view
    }

    func createHeaderViewForItem(type: OperationDefinitionType) -> BaseOperationDefinitionHeaderView? {
        return InvisibleHeaderView()
    }
}


final class ContainingErrorView: MultilineTitleIconView, OperationDefinitionErrorViewProtocol {
    func bind(errorMessage: String) {
        self.title = errorMessage
    }

    override public func bind(viewModel: MultilineTitleIconViewModelProtocol) {
        self.title = viewModel.text
        self.icon = viewModel.icon
    }

    var command: WalletCommandProtocol? {
        didSet {
            if command != nil {
                self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(runCommand)))
                addAccessoryIcon()
            }
        }
    }

    func addAccessoryIcon() {
        let icon = UIImageView(image: R.image.iconSmallArrow())
        icon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(icon)
        icon.widthAnchor.constraint(equalToConstant: 6).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 11).isActive = true
        icon.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -1).isActive = true
        icon.centerYAnchor.constraint(equalTo: self.centerYAnchor, constant: 0).isActive = true
    }

    @objc func runCommand() {
        try? command?.execute()
    }
}

class MultilineTitleIconView: UIView {
    private(set) var titleLabel: UILabel = UILabel()

    private var imageView: UIImageView?

    private var preferredWidth: CGFloat = 0.0

    var title: String? {
        get {
            titleLabel.text
        }

        set {
            titleLabel.text = newValue

            invalidateLayout()
        }
    }

    var icon: UIImage? {
        get {
            imageView?.image
        }

        set {
            if let newIcon = newValue {
                if imageView == nil {
                    let imageView = UIImageView()
                    addSubview(imageView)
                    self.imageView = imageView
                }

                imageView?.image = newIcon
            } else {
                if imageView != nil {
                    imageView?.removeFromSuperview()
                    imageView = nil
                }
            }

            invalidateLayout()
        }
    }

    var horizontalSpacing: CGFloat = 6.0 {
        didSet {
            invalidateLayout()
        }
    }

    var contentInsets: UIEdgeInsets = .zero {
        didSet {
            invalidateLayout()
        }
    }

    public func bind(viewModel: MultilineTitleIconViewModelProtocol) {
        self.title = viewModel.text
        self.icon = viewModel.icon
    }

    // MARK: Overridings

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        titleLabel.numberOfLines = 0
        addSubview(titleLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override var intrinsicContentSize: CGSize {
        guard preferredWidth > 0.0 else {
            return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
        }

        var resultSize = CGSize(width: UIView.noIntrinsicMetric, height: 0.0)

        var imageSize = CGSize.zero

        if let imageView = imageView {
            imageSize = imageView.intrinsicContentSize
            resultSize.height = imageSize.height
        }

        let offsetFromIcon = imageSize.width > 0.0 ? imageSize.width + horizontalSpacing : 0.0
        let boundingWidth = max(preferredWidth - offsetFromIcon - contentInsets.left
            - contentInsets.right, 0.0)
        let boundingSize = CGSize(width: boundingWidth, height: CGFloat.greatestFiniteMagnitude)
        let titleSize = titleLabel.sizeThatFits(boundingSize)

        resultSize.height = max(resultSize.height, titleSize.height)

        if resultSize.height > 0.0 {
            resultSize.height += contentInsets.top + contentInsets.bottom
        }

        return resultSize
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        var horizontalOffset = contentInsets.left

        let inset = (contentInsets.top - contentInsets.bottom) / 2.0

        if let imageView = imageView {
            let imageSize = imageView.image?.size ?? .zero
            imageView.frame = CGRect(x: horizontalOffset,
                                     y: bounds.height / 2.0 - imageSize.height / 2.0 + inset,
                                     width: imageSize.width,
                                     height: imageSize.height)
            horizontalOffset += imageSize.width + horizontalSpacing
        }

        let titleHeight = bounds.size.height - contentInsets.top - contentInsets.bottom

        titleLabel.frame = CGRect(x: horizontalOffset,
                                  y: bounds.height / 2.0 - titleHeight / 2.0 + inset,
                                  width: bounds.width - horizontalOffset - contentInsets.right,
                                  height: titleHeight)

        if abs(bounds.width - preferredWidth) > CGFloat.leastNormalMagnitude {
            preferredWidth = bounds.width
            invalidateIntrinsicContentSize()
        }
    }

    // MARK: Private

    private func invalidateLayout() {
        invalidateIntrinsicContentSize()

        if superview != nil {
            setNeedsLayout()
        }
    }
}
