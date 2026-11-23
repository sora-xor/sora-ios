import UIKit

public final class InputAssetField: UIControl, Molecule {
    
    private struct Constants {
        static let assetImageSize: CGFloat = 40
    }

    public let sora: InputAssetFieldConfiguration<InputAssetField>

    let containerView: SoramitsuView = {
        let view = SoramitsuView()
        view.sora.cornerRadius = .max
        view.sora.backgroundColor = .bgSurface
        view.sora.borderWidth = 1
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let assetImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.tintColor = .fgSecondary
        return view
    }()

    public let choiceButton: SoramitsuButton = {
        let button = SoramitsuButton()
        button.sora.backgroundColor = .custom(uiColor: .clear)
        button.sora.horizontalOffset = 0
        button.sora.imageSize = 16
        button.sora.tintColor = .fgSecondary
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    /// A small wallet before the balance: the number is what you hold. Shown once tapping it does something.
    let balanceGlyph: UIImageView = {
        let view = UIImageView(image: UIImage(systemName: "wallet.bifold.fill")
            ?? UIImage(systemName: "creditcard.fill"))
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        view.tintColor = SoramitsuUI.shared.theme.palette.color(.fgSecondary)
        view.isHidden = true
        return view
    }()

    var balanceGlyphWidth: NSLayoutConstraint?

    let fullFiatAmountLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.sora.textColor = .fgSecondary
        label.sora.font = FontType.textBoldXS
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        // A long balance beside a long fiat value gets smaller before it is cut: what is held matters.
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.75
        return label
    }()
    
    public lazy var textField: SoramitsuTextField = {
        let textField = SoramitsuTextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.sora.textColor = .fgPrimary
        textField.sora.font = FontType.displayS
        textField.textAlignment = .right

        textField.sora.addHandler(for: .editingDidBegin) { [weak self] in
            self?.sora.state = .focused
        }
        textField.sora.addHandler(for: .editingDidEnd) { [weak self] in
            self?.sora.state = .default
        }
        return textField
    }()

    public let inputedFiatAmountLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.sora.textColor = .fgSecondary
        label.sora.font = FontType.textBoldXS
        label.sora.alignment = .right
        return label
    }()

    init(style: SoramitsuStyle) {
        sora = InputAssetFieldConfiguration(style: style, state: .default)
        super.init(frame: .zero)
        sora.owner = self
        setup()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @available(*, unavailable)
    public override init(frame: CGRect) { fatalError("init(coder:) has not been implemented") }
}

private extension InputAssetField {
    func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        
        sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.textField.becomeFirstResponder()
        }

        addSubview(containerView)
        containerView.addSubview(assetImageView)
        containerView.addSubview(choiceButton)
        containerView.addSubview(balanceGlyph)
        containerView.addSubview(fullFiatAmountLabel)
        containerView.addSubview(textField)
        containerView.addSubview(inputedFiatAmountLabel)

        let glyphWidth = balanceGlyph.widthAnchor.constraint(equalToConstant: 0)
        balanceGlyphWidth = glyphWidth
        glyphWidth.isActive = true

        // The amount keeps room to be typed and read whatever stands beside it: a long token name gets
        // smaller, then is cut, before the amount is squeezed to a lone digit.
        let amountRoom = textField.widthAnchor.constraint(greaterThanOrEqualToConstant: LayoutCanvas.minimumFieldWidth)
        amountRoom.priority = UILayoutPriority(995)
        amountRoom.isActive = true

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            assetImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            assetImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            assetImageView.heightAnchor.constraint(equalToConstant: Constants.assetImageSize),
            assetImageView.widthAnchor.constraint(equalToConstant: Constants.assetImageSize),
            assetImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),

            choiceButton.leadingAnchor.constraint(equalTo: assetImageView.trailingAnchor, constant: 8),
            choiceButton.topAnchor.constraint(equalTo: assetImageView.topAnchor),
            choiceButton.heightAnchor.constraint(equalToConstant: 24),
            
            balanceGlyph.leadingAnchor.constraint(equalTo: assetImageView.trailingAnchor, constant: 8),
            balanceGlyph.centerYAnchor.constraint(equalTo: fullFiatAmountLabel.centerYAnchor),
            balanceGlyph.heightAnchor.constraint(equalToConstant: 12),

            fullFiatAmountLabel.leadingAnchor.constraint(equalTo: balanceGlyph.trailingAnchor),
            fullFiatAmountLabel.bottomAnchor.constraint(equalTo: assetImageView.bottomAnchor),
            
            textField.leadingAnchor.constraint(equalTo: choiceButton.trailingAnchor, constant: 8),
            textField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            textField.topAnchor.constraint(equalTo: assetImageView.topAnchor),
            
            inputedFiatAmountLabel.leadingAnchor.constraint(equalTo: fullFiatAmountLabel.trailingAnchor, constant: 8),
            inputedFiatAmountLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            inputedFiatAmountLabel.bottomAnchor.constraint(equalTo: assetImageView.bottomAnchor),
        ])
    }
}


public extension InputAssetField {

    convenience init() {
        let sora = SoramitsuUI.shared
        self.init(style: sora.style)
    }
}
