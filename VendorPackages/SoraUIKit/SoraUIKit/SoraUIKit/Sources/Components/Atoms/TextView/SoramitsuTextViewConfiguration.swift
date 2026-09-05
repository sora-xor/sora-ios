import UIKit

public final class SoramitsuTextViewConfiguration<Type: SoramitsuTextView>: SoramitsuViewConfiguration<Type> {

	// MARK: Text

	public var text: String? {
		didSet {
			updateAttributedText()
		}
	}

	public var attributedText: SoramitsuTextItem? {
		didSet {
			updateAttributedText()
		}
	}

	// MARK: Attributes

	public var textColor: SoramitsuColor = .fgPrimary {
		didSet {
			updateAttributedText()
		}
	}

	public var font: FontData = FontType.textM {
		didSet {
			updateAttributedText()
		}
	}

    /// Opt in on layouts that can grow with the user's preferred text size.
    public var dynamicTextStyle: UIFont.TextStyle? {
        didSet { updateForContentSizeCategory() }
    }

	public var textAlignment: NSTextAlignment = .left {
		didSet {
			updateAttributedText()
		}
	}

	// MARK: Other properties

	public var textInsets: SoramitsuInsets = .zero {
		didSet {
			owner?.textContainerInset = textInsets.uiEdgeInsets
		}
	}

	public var isEditable: Bool = true {
		didSet {
			owner?.isEditable = isEditable
		}
	}

	public var isSelectable: Bool = true {
		didSet {
			owner?.isSelectable = isSelectable
		}
	}

	public var showVerticalScrollIndicator = true {
		didSet {
			owner?.showsVerticalScrollIndicator = showVerticalScrollIndicator
		}
	}

	public var showHorizontalScrollIndicator = true {
		didSet {
			owner?.showsHorizontalScrollIndicator = showHorizontalScrollIndicator
		}
	}

	public var isScrollEnabled: Bool = true {
		didSet {
			owner?.isScrollEnabled = isScrollEnabled
		}
	}

	public var maximumNumberOfLines: Int = 0 {
		didSet {
			owner?.textContainer.maximumNumberOfLines = maximumNumberOfLines
		}
	}

	public override func styleDidChange(options: UpdateOptions) {
		super.styleDidChange(options: options)

		if options.contains(.palette) {
			updateAttributedText()
		}
	}

	override func configureOwner() {
		super.configureOwner()
        retrigger(self, \.text)
        retrigger(self, \.attributedText)
		retrigger(self, \.textInsets)
		retrigger(self, \.isEditable)
		retrigger(self, \.isSelectable)
		retrigger(self, \.showVerticalScrollIndicator)
		retrigger(self, \.showHorizontalScrollIndicator)
		retrigger(self, \.isScrollEnabled)

		updateKeyboardAppearence()
        updateAttributedText()
	}

	private func updateAttributedText() {
		if let attributedText = attributedText {
			owner?.attributedText = scaled(attributedText.attributedString)
			owner?.linkTextAttributes = attributedText.linkAttributes
			return
		}

		guard let text = text else {
			owner?.attributedText = nil
            if let dynamicTextStyle, let baseFont = font.attributes[.font] as? UIFont {
                let scaledFont = UIFontMetrics(forTextStyle: dynamicTextStyle)
                    .scaledFont(for: baseFont, compatibleWith: owner?.traitCollection)
                owner?.font = scaledFont
                owner?.typingAttributes[.font] = scaledFont
            }
			return
		}

		var attributes = font.attributes
        if let dynamicTextStyle, let baseFont = attributes[.font] as? UIFont {
            attributes[.font] = UIFontMetrics(forTextStyle: dynamicTextStyle)
                .scaledFont(for: baseFont, compatibleWith: owner?.traitCollection)
        }

		let paragraph = font.paragraph
		paragraph.alignment = textAlignment

		attributes[.foregroundColor] = style.palette.color(textColor)
		attributes[.paragraphStyle] = paragraph

		let attributedText = NSMutableAttributedString(string: text, attributes: attributes)

		owner?.attributedText = attributedText
        if dynamicTextStyle != nil {
            owner?.font = attributes[.font] as? UIFont
            owner?.typingAttributes = attributes
        }
		owner?.linkTextAttributes = nil
	}

    func updateForContentSizeCategory() {
        let selection = owner?.selectedRange
        updateAttributedText()
        if let selection { owner?.selectedRange = selection }
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
