import UIKit

public class SoramitsuLabelConfiguration<Type: UILabel & Atom>: SoramitsuViewConfiguration<Type> {

	// MARK: Text

	public var text: String? {
		didSet {
			updateAttributedText()
		}
	}

	public var attributedText: SoramitsuAttributedText? {
		didSet {
			updateAttributedText()
		}
	}

	// MARK: Attributes

    public var textColor: SoramitsuColor = .accentPrimary {
		didSet {
			updateAttributedText()
		}
	}

    public var font: FontData = FontType.buttonM {
		didSet {
			updateAttributedText()
		}
	}

	public var alignment: NSTextAlignment = .left {
		didSet {
			updateAttributedText()
		}
	}

	public var lineBreakMode: NSLineBreakMode = .byTruncatingTail {
		didSet {
			updateAttributedText()
		}
	}
    
    public override var supportsPaletteMode: Bool {
        didSet {
            super.supportsPaletteMode = supportsPaletteMode
            updateAttributedText()
        }
    }

    /// Opt in on layouts that can grow with the user's preferred text size.
    public var dynamicTextStyle: UIFont.TextStyle? {
        didSet { updateAttributedText() }
    }

	// MARK: Other

    public var contentInsets: SoramitsuInsets = .zero {
        didSet {
            owner?.rebuildLayout()
        }
    }

	public var numberOfLines: Int = 1 {
		didSet {
			owner?.numberOfLines = numberOfLines
		}
	}

	public var underlineStyle: NSUnderlineStyle? {
		didSet {
			updateAttributedText()
		}
	}

	public override func styleDidChange(options: UpdateOptions) {
		super.styleDidChange(options: options)

		if options.contains(.palette) {
			updateAttributedText()
		}
	}

	func updateAttributedText() {
		guard attributedText == nil else {
			owner?.attributedText = scaled(attributedText?.attributedString)
			return
		}
		guard let text = text else {
			owner?.attributedText = nil
			return
		}

		var attributes = font.attributes
        
        let palette = supportsPaletteMode ? style.palette : LightPalette()
        
		let paragraph = font.paragraph
		paragraph.alignment = alignment
		paragraph.lineBreakMode = lineBreakMode

		attributes[.paragraphStyle] = paragraph
        attributes[.foregroundColor] = palette.color(textColor)
		if let underlineStyle = underlineStyle {
			attributes[.underlineStyle] = underlineStyle.rawValue
		}

		owner?.attributedText = scaled(NSAttributedString(string: text, attributes: attributes))
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
}
