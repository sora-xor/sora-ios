import UIKit

public final class InputAssetFieldConfiguration<Type: InputAssetField>: SoramitsuControlConfiguration<Type> {
    public var state: InputFieldState = .default {
        didSet {
            updateView()
        }
    }

    public var assetImage: UIImage? {
        didSet {
            owner?.assetImageView.image = assetImage
        }
    }
    
    public var assetSymbol: String? {
        didSet {
            owner?.choiceButton.sora.attributedText = SoramitsuTextItem(text: assetSymbol ?? "",
                                                                        fontData: FontType.displayS,
                                                                        textColor: .fgPrimary,
                                                                        alignment: .left)
        }
    }
    
    public var assetArrow: UIImage? {
        didSet {
            owner?.choiceButton.sora.rightImage = assetArrow
        }
    }
    
    public var fullFiatText: String? {
        didSet {
            owner?.fullFiatAmountLabel.sora.text = fullFiatText
        }
    }

    public var text: String? {
        didSet {
            owner?.textField.sora.attributedText = SoramitsuTextItem(text: text ?? "",
                                                                     fontData: FontType.displayS,
                                                                     textColor: .fgPrimary,
                                                                     alignment: .right)
        }
    }
    
    public var inputedFiatAmountText: String? {
        didSet {
            owner?.inputedFiatAmountLabel.sora.text = inputedFiatAmountText
        }
    }
    
    /// Tapping the balance (to use all of it). Setting it shows the wallet glyph before the balance.
    public var balanceTapHandler: (() -> Void)? {
        didSet {
            guard let owner else { return }
            let on = balanceTapHandler != nil
            owner.balanceGlyph.isHidden = !on
            owner.balanceGlyphWidth?.constant = on ? 16 : 0
            owner.fullFiatAmountLabel.isUserInteractionEnabled = on
            owner.fullFiatAmountLabel.accessibilityTraits = on ? .button : .staticText
            if on, owner.fullFiatAmountLabel.gestureRecognizers?.isEmpty ?? true {
                owner.fullFiatAmountLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(balanceTapped)))
            }
        }
    }

    public var assetChoiceHandler: (() -> Void)? {
        didSet {
            owner?.choiceButton.sora.addHandler(for: .touchUpInside, handler: assetChoiceHandler)
            owner?.assetImageView.isUserInteractionEnabled = true
            owner?.assetImageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(choice)))
        }
    }

    private var textObservation: NSKeyValueObservation?

    init(style: SoramitsuStyle, state: InputFieldState) {
        self.state = state
        super.init(style: style)
    }

    public override func styleDidChange(options: UpdateOptions) {
        super.styleDidChange(options: options)

        if options.contains(.palette) {
            updateView()
        }
    }
    
    @objc private func balanceTapped() {
        guard let label = owner?.fullFiatAmountLabel else { return }
        UIView.animate(withDuration: 0.12, animations: { label.transform = CGAffineTransform(scaleX: 1.08, y: 1.08) }) { _ in
            UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0) {
                label.transform = .identity
            }
        }
        balanceTapHandler?()
    }

    @objc private func choice() {
        assetChoiceHandler?()
    }

    func updateView() {
        owner?.containerView.layer.borderColor = style.palette.color(state.borderColor).cgColor
        owner?.containerView.backgroundColor = style.palette.color(.bgSurface)
    }
}
