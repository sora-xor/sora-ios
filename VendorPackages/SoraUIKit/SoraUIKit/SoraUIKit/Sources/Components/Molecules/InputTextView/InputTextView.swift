import UIKit

public protocol InputTextViewDelegate {
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool
    func textViewDidChange(_ textView: UITextView)
}

public final class InputTextView: UIView, Molecule {
    
    public var delegate: InputTextViewDelegate?
    
    private var heightConstant: NSLayoutConstraint?

    public let sora: InputTextViewConfiguration<InputTextView>

    let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        stackView.isLayoutMarginsRelativeArrangement = true
        return stackView
    }()

    public lazy var textView: SoramitsuTextView = {
        let textField = SoramitsuTextView()
        textField.sora.font = FontType.textM
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.setContentCompressionResistancePriority(.required, for: .vertical)
        textField.delegate = self
        return textField
    }()

    public let descriptionLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.isHidden = true
        label.sora.numberOfLines = 0
        label.sora.textColor = .fgSecondary
        label.sora.font = FontType.textXS
        return label
    }()

    init(style: SoramitsuStyle) {
        sora = InputTextViewConfiguration(style: style, state: .default)
        super.init(frame: .zero)
        sora.owner = self
        setup()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @available(*, unavailable)
    public override init(frame: CGRect) { fatalError("init(coder:) has not been implemented") }
}

private extension InputTextView {
    func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        stackView.layer.cornerRadius = 28
        stackView.layer.borderWidth = 1

        addSubview(stackView)
        stackView.addArrangedSubviews([textView])
        addSubview(descriptionLabel)
        
        let heightConstant = textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 32)
        self.heightConstant = heightConstant
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            
            heightConstant,

            descriptionLabel.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 4),
            descriptionLabel.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: 16),
            descriptionLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            descriptionLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}

extension InputTextView: UITextViewDelegate {
    public func textViewDidBeginEditing(_ textView: UITextView) {
        sora.state = .focused
    }

    public func textViewDidEndEditing(_ textView: UITextView) {
        sora.state = .default
    }
    
    public func textViewDidChange(_ textView: UITextView) {
        self.textView.sora.text = textView.text
        delegate?.textViewDidChange(textView)
        let fixedWidth = textView.frame.size.width
        let newSize = textView.sizeThatFits(CGSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude))
        heightConstant?.constant = newSize.height > 32 ? newSize.height : 32
        rebuildLayout(animated: true)
    }
    
    public func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if(text == "\n") {
            textView.resignFirstResponder()
            return false
        }
        return delegate?.textView(textView, shouldChangeTextIn: range, replacementText: text) ?? true
    }

    
    public func textView(textView: UITextView, shouldChangeTextInRange range: NSRange, replacementText text: String) -> Bool {
        if(text == "\n") {
            textView.resignFirstResponder()
            return false
        }
        return true
    }
}


public extension InputTextView {

    convenience init() {
        let sora = SoramitsuUI.shared
        self.init(style: sora.style)
    }
}
