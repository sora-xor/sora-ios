import UIKit

public final class SoramitsuTextView: UITextView, Atom {

	public let sora: SoramitsuTextViewConfiguration<SoramitsuTextView>

	init(style: SoramitsuStyle) {
        sora = SoramitsuTextViewConfiguration(style: style)
		super.init(frame: .zero, textContainer: nil)
        sora.owner = self
		delegate = self
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

extension SoramitsuTextView: UITextViewDelegate {
	public func textView(_ textView: UITextView,
						 shouldInteractWith URL: URL,
						 in characterRange: NSRange,
						 interaction: UITextItemInteraction) -> Bool {
		sora.attributedText?.process(url: URL)
		return sora.isEditable
	}
}

public extension SoramitsuTextView {

	convenience init() {
		self.init(style: SoramitsuUI.shared.style)
	}

	convenience init(configurator: (SoramitsuTextViewConfiguration<SoramitsuTextView>) -> Void) {
		self.init(style: SoramitsuUI.shared.style)
		configurator(sora)
	}
}
