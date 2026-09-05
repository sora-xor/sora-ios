import UIKit

public class SoramitsuTextFieldConfiguration<Type: SoramitsuTextField>: SoramitsuControlConfiguration<Type> {

	public var text: String? {
		didSet(oldText) {
			guard text != oldText else { return }
			updateTextAttributes()
		}
	}
    
    public var attributedText: SoramitsuTextItem? {
        didSet {
            owner?.attributedText = scaled(attributedText?.attributedString)
        }
    }

    /// Opt in on layouts that can grow with the user's preferred text size.
    public var dynamicTextStyle: UIFont.TextStyle? {
        didSet { updateForContentSizeCategory() }
    }

    public var textColor: SoramitsuColor = .fgPrimary {
		didSet {
			updateTextAttributes()
		}
	}

    public var font: FontData = FontType.textM {
		didSet {
			updateTextAttributes()
		}
	}

	public var placeholder: String? {
		didSet {
			updatePlaceholderAttributes()
		}
	}

    public var placeholderColor: SoramitsuColor = .fgSecondary {
		didSet {
			updatePlaceholderAttributes()
		}
	}

    public var placeholderFont: FontData = FontType.textM {
		didSet {
			updatePlaceholderAttributes()
		}
	}
    
	private var textObservation: NSKeyValueObservation?

	override init(style: SoramitsuStyle) {
		super.init(style: style)
        tintColor = .fgPrimary
	}

	public override func styleDidChange(options: UpdateOptions) {
		super.styleDidChange(options: options)

		if options.contains(.palette) {
			retrigger(self, \.textColor)
			retrigger(self, \.placeholderColor)
			updateKeyboardAppearence()
		}
	}

	override func configureOwner() {
		super.configureOwner()

		retrigger(self, \.textColor)
		retrigger(self, \.tintColor)
		retrigger(self, \.font)
		retrigger(self, \.placeholderColor)
		retrigger(self, \.placeholderFont)

		updateKeyboardAppearence()

		addHandler(for: .editingChanged) { [weak self] in
			self?.text = self?.owner?.text
		}

		textObservation = owner?.observe(\.text, options: .new) { [weak self] _, _ in
			self?.text = self?.owner?.text
		}
	}

    private func updateTextAttributes() {
		guard let owner = owner else { return }
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = owner.textAlignment
        
		var attributes = font.attributes
        if let dynamicTextStyle, let baseFont = attributes[.font] as? UIFont {
            attributes[.font] = UIFontMetrics(forTextStyle: dynamicTextStyle)
                .scaledFont(for: baseFont, compatibleWith: owner.traitCollection)
        }
		attributes[.foregroundColor] = style.palette.color(textColor)
        attributes[.paragraphStyle] = paragraphStyle
        guard let text else {
            if dynamicTextStyle != nil {
                owner.font = attributes[.font] as? UIFont
                owner.defaultTextAttributes = attributes
            }
            return
        }
		let selectedRange = owner.selectedTextRange
		owner.attributedText = NSAttributedString(string: text, attributes: attributes)
		owner.selectedTextRange = selectedRange
		owner.defaultTextAttributes = attributes
	}

    private func updatePlaceholderAttributes() {
		guard let placeholder = placeholder else { return }
		var attributes = placeholderFont.attributes
		attributes[.foregroundColor] = style.palette.color(placeholderColor)
		owner?.attributedPlaceholder = scaled(NSAttributedString(string: placeholder, attributes: attributes))
	}

    func updateForContentSizeCategory() {
        if let attributedText {
            let selection = owner?.selectedTextRange
            owner?.attributedText = scaled(attributedText.attributedString)
            owner?.selectedTextRange = selection
        } else {
            updateTextAttributes()
        }
        updatePlaceholderAttributes()
        owner?.invalidateIntrinsicContentSize()
    }

    private func scaled(_ text: NSAttributedString?) -> NSAttributedString? {
        guard let text, let dynamicTextStyle else { return text }
        let result = NSMutableAttributedString(attributedString: text)
        text.enumerateAttribute(.font, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            guard let font = value as? UIFont else { return }
            result.addAttribute(.font, value: UIFontMetrics(forTextStyle: dynamicTextStyle)
                .scaledFont(for: font, compatibleWith: owner?.traitCollection), range: range)
        }
        return result
    }

    private func updateKeyboardAppearence() {
		switch SoramitsuUI.shared.theme {
		case .light: owner?.keyboardAppearance = .light
		case .dark: owner?.keyboardAppearance = .dark
		}
	}
}
