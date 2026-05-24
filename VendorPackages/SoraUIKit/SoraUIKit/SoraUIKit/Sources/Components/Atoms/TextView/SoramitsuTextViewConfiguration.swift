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
			owner?.attributedText = attributedText.attributedString
			owner?.linkTextAttributes = attributedText.linkAttributes
			return
		}

		guard let text = text else {
			owner?.attributedText = nil
			return
		}

		var attributes = font.attributes

		let paragraph = font.paragraph
		paragraph.alignment = textAlignment

		attributes[.foregroundColor] = style.palette.color(textColor)
		attributes[.paragraphStyle] = paragraph

		let attributedText = NSMutableAttributedString(string: text, attributes: attributes)

		owner?.attributedText = attributedText
		owner?.linkTextAttributes = nil
	}

	private func updateKeyboardAppearence() {
        switch SoramitsuUI.shared.theme {
		case .light: owner?.keyboardAppearance = .light
		case .dark: owner?.keyboardAppearance = .dark
		}
	}
}
