import UIKit

public final class SoramitsuButtonConfiguration<Type: SoramitsuButton>: SoramitsuBaseButtonConfiguration<Type,
                                                                        SoramitsuButtonConfiguration>, Statable {

    public var type: SoramitsuButtonType = .filled(.primary) {
        didSet {
            owner?.type = type
        }
    }

    public var leftImage: UIImage? {
        didSet {
            owner?.leftImageView.isHidden = leftImage == nil
            owner?.leftImageView.image = leftImage
            owner?.leftImageView.tintColor = owner?.tintColor
        }
    }

    public var title: String? {
        didSet {
            owner?.titleLabel.sora.isHidden = title == nil || (title?.isEmpty ?? true)
            owner?.titleLabel.sora.text = title
        }
    }

    public var attributedText: SoramitsuAttributedText? {
        didSet {
            let isHidden = attributedText == nil || (attributedText?.attributedString.string.isEmpty ?? true)
            owner?.titleLabel.sora.isHidden = isHidden
            owner?.titleLabel.sora.attributedText = attributedText
            owner?.refreshAttributedTitle()
        }
    }
    
    public var imageSize: CGFloat? {
        didSet {
            owner?.rightImageSizeConstaint?.constant = imageSize ?? 24
            owner?.leftImageSizeConstaint?.constant = imageSize ?? 24
        }
    }

    public var rightImage: UIImage? {
        didSet {
            owner?.rightImageView.isHidden = rightImage == nil
            owner?.rightImageView.image = rightImage
            owner?.rightImageView.tintColor = owner?.tintColor
        }
    }
    
    public var horizontalOffset: CGFloat? {
        didSet {
            owner?.horizontalConstaint?.constant = horizontalOffset ?? 16
            owner?.horizontalConstaint?.isActive = true
        }
    }

    public var isHighlited: Bool = false {
        didSet {
            guard isHighlited else { return }
            owner?.pressedAnimation()
        }
    }

	/// The background the caller chose, if any. The type's own colour is
	/// applied by the button and never stored here.
	public private(set) var explicitBackgroundColor: SoramitsuColor?

	public override var backgroundColor: SoramitsuColor {
		didSet {
			guard owner != nil, !isReapplyingBackground else { return }
			explicitBackgroundColor = backgroundColor
			owner?.updateView()
		}
	}

	/// The tint the caller chose for the button's images, if any.
	public private(set) var explicitTintColor: SoramitsuColor?

	public override var tintColor: SoramitsuColor {
		didSet {
			guard owner != nil, !isReapplyingTint else { return }
			explicitTintColor = tintColor
			owner?.updateView()
		}
	}

	public override var clipsToBounds: Bool {
		didSet {
			owner?.applyClipping()
		}
	}

	/// Draws the Neon glow (`glow.primary` / `glow.swap`) behind a primary or
	/// swap CTA. Off by default: turn it on only for the one screen-level CTA
	/// of a screen, never in a list (spec §4.5, §10.3). It is ignored inside
	/// table and collection cells. The gradient fill does not depend on it.
	public var glows: Bool = false {
		didSet {
			guard glows != oldValue else { return }
			owner?.updateView()
		}
	}

	init(style: SoramitsuStyle) {
		super.init(style: style, stater: SoramitsuStateDecorator(state: .default))
		stater.g = self
	}

    public override func styleDidChange(options: UpdateOptions) {
        super.styleDidChange(options: options)

        if options.contains(.palette) || options.contains(.effects) {
            owner?.updateView()
        }
    }
}
