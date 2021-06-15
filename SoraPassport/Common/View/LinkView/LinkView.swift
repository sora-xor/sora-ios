import Foundation
import Anchorage
import SoraUI
import Then

@IBDesignable
final class LinkView: BackgroundedContentControl {

    private lazy var descriptionTitleLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .paragraph2)
            $0.textColor = R.color.baseContentPrimary()
            $0.lineBreakMode = .byTruncatingTail
        }
    }()

    private lazy var linkTitleLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .paragraph3)
            $0.textColor = R.color.themeAccent()
            $0.lineBreakMode = .byTruncatingTail
        }
    }()

    private lazy var iconImageView: UIImageView = {
        UIImageView(image: nil).then {
            $0.widthAnchor == 24
            $0.contentMode = .center
        }
    }()

    private lazy var arrowImageView: UIImageView = {
        UIImageView(image: R.image.arrowTopRight()).then {
            $0.widthAnchor == 16
            $0.contentMode = .center
        }
    }()

    var separatorIsVisible = false

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
                alpha = 0.5
            }

            if oldValue, !newValue {
                layer.removeAllAnimations()
                alpha = 1.0
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        guard let currentContentView = contentView else { return }

        let contentSize = CGSize(
            width: bounds.size.width, height: bounds.size.height
        )

        currentContentView.frame = CGRect(
            origin: .zero, size: contentSize
        )
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        configure()

        iconImage = R.image.assetVal()
        titleAttributedText = R.string.localizable.comingSoon()
        linkTitleAttributedText = R.string.localizable.stakingComingSoon()
    }
}

private extension LinkView {

    func configure() {
        backgroundColor = .white

        changesContentOpacityWhenHighlighted = true

        contentView = contentView ?? createContentStackView()

        contentView?.do {
            $0.isUserInteractionEnabled = false
            $0.edgeAnchors == edgeAnchors
        }
    }

    func createContentStackView() -> UIView {
        UIStackView(arrangedSubviews: [
            UIStackView(arrangedSubviews: [
                // icon image
                iconImageView,
                // labels
                UIView().then {
                    let labelsStackView = UIStackView(arrangedSubviews: [
                        descriptionTitleLabel,
                        linkTitleLabel
                    ]).then {
                        $0.axis = .vertical
                    }

                    $0.backgroundColor = .clear
                    $0.addSubview(labelsStackView)
                    labelsStackView.horizontalAnchors == $0.horizontalAnchors
                    labelsStackView.centerYAnchor == $0.centerYAnchor
                },
                // arrow image
                arrowImageView
            ]).then {
                $0.axis = .horizontal
                $0.spacing = 20
            },
            // separator
            UIView().then {
                $0.isHidden = !separatorIsVisible
                $0.backgroundColor = .listSeparator
                $0.heightAnchor == 0.5
            }
        ]).then {
            $0.axis = .vertical
            $0.spacing = 0
            $0.heightAnchor == 56
        }
    }
}

extension LinkView {

    @IBInspectable
    var iconImage: UIImage? {
        get { iconImageView.image }
        set { iconImageView.image = newValue }
    }

    @IBInspectable
    var iconTintColor: UIColor! {
        get { iconImageView.tintColor }
        set { iconImageView.tintColor = newValue }
    }

    @IBInspectable
    var titleText: String? {
        get { descriptionTitleLabel.text }
        set { descriptionTitleLabel.text = newValue }
    }

    @IBInspectable
    var linkTitleText: String? {
        get { linkTitleLabel.text }
        set { linkTitleLabel.text = newValue }
    }

    @IBInspectable
    var titleAttributedText: String? {
        get { descriptionTitleLabel.attributedText?.string }
        set { descriptionTitleLabel.attributedText = newValue?.styled(.paragraph2) }
    }

    @IBInspectable
    var linkTitleAttributedText: String? {
        get { linkTitleLabel.attributedText?.string }
        set { linkTitleLabel.attributedText = newValue?.styled(.paragraph3) }
    }
}
