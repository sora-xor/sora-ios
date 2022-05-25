import UIKit
import SoraUI
import Then
import Anchorage

final class RoundedNavigationButton: BackgroundedContentControl {

    private lazy var titleLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .paragraph2, isBold: true)
            $0.textColor = R.color.baseContentPrimary()
            $0.lineBreakMode = .byTruncatingTail
        }
    }()

    private lazy var descriptionLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .paragraph3)
            $0.textColor = R.color.baseContentTertiary()
            $0.lineBreakMode = .byTruncatingTail
        }
    }()

    private lazy var descriptionImageView: UIImageView = {
        UIImageView(image: R.image.circleChevronRight()).then {
            $0.widthAnchor == 16
            $0.contentMode = .center
        }
    }()

    private var roundedBackgroundView: RoundedView? {
        backgroundView as? RoundedView
    }

    private lazy var highlightedOnAnimation: ViewAnimatorProtocol = TransformAnimator.highlightedOn
    private lazy var highlightedOffAnimation: ViewAnimatorProtocol = TransformAnimator.highlightedOff

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    override var isHighlighted: Bool {
        get {
            return super.isHighlighted
        }

        set {
            let oldValue = super.isHighlighted
            super.isHighlighted = newValue

            if !oldValue, newValue {
                layer.removeAllAnimations()
                highlightedOnAnimation.animate(view: self, completionBlock: nil)
            }

            if oldValue, !newValue {
                layer.removeAllAnimations()
                highlightedOffAnimation.animate(view: self, completionBlock: nil)
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        guard let currentContentView = contentView else { return }

        let insets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        let contentSize = CGSize(
            width: bounds.size.width - insets.left - insets.right,
            height: bounds.size.height - insets.top - insets.bottom
        )

        currentContentView.frame = CGRect(
            origin: CGPoint(x: insets.left, y: insets.top),
            size: contentSize
        )
    }
}

private extension RoundedNavigationButton {

    func configure() {
        backgroundColor = .clear
        heightAnchor == 88

        changesContentOpacityWhenHighlighted = false

        if self.backgroundView == nil {
            self.backgroundView = RoundedView().then {
                $0.isUserInteractionEnabled = false

                $0.fillColor = .white
                $0.highlightedFillColor = .white

                $0.cornerRadius = cornerRadius
                $0.roundingCorners = .allCorners

                $0.shadowColor = UIColor.black
                $0.shadowOffset = CGSize(width: 0, height: 2)
                $0.shadowOpacity = 0.3
                $0.shadowRadius = 3
            }
        }

        contentView = contentView ?? createContentStackView()

        contentView?.do {
            $0.isUserInteractionEnabled = false
            let insets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
            $0.edgeAnchors == edgeAnchors + insets
        }
    }

    func createContentStackView() -> UIView {
        UIStackView(arrangedSubviews: [
            titleLabel,
            UIStackView(arrangedSubviews: [
                descriptionLabel,
                descriptionImageView
            ]).then {
                $0.axis = .horizontal
                $0.distribution = .fillProportionally
                $0.spacing = 20
            }
        ]).then {
            $0.axis = .vertical
            $0.distribution = .equalSpacing
            $0.spacing = 8
        }
    }
}

extension RoundedNavigationButton {

    var cornerRadius: CGFloat {
        get { roundedBackgroundView?.cornerRadius ?? .zero }
        set { roundedBackgroundView?.cornerRadius = newValue; setNeedsDisplay() }
    }

    var titleText: String? {
        get { titleLabel.text }
        set { titleLabel.text = newValue }
    }

    var descriptionText: String? {
        get { descriptionLabel.text }
        set { descriptionLabel.text = newValue }
    }

    var titleAttributedText: String? {
        get { titleLabel.attributedText?.string }
        set { titleLabel.attributedText = newValue?.styled(.paragraph2) }
    }

    var descriptionAttributedText: String? {
        get { descriptionLabel.attributedText?.string }
        set { descriptionLabel.attributedText = newValue?.styled(.paragraph3) }
    }

    /// Show `circle-chevron-right` by default
    var descriptionImage: UIImage? {
        get { descriptionImageView.image }
        set { descriptionImageView.image = newValue }
    }
}
