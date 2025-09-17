import UIKit

public final class SoramitsuScrollView: UIScrollView, Atom {

	public let sora: SoramitsuScrollViewConfiguration<SoramitsuScrollView>

	init(style: SoramitsuStyle) {
		sora = SoramitsuScrollViewConfiguration(style: style)
		super.init(frame: .zero)
        sora.owner = self
	}
    
    public override func touchesShouldCancel(in view: UIView) -> Bool {
        if sora.cancelsTouchesOnDragging && view is UIControl {
            return true
        }
        return super.touchesShouldCancel(in: view)
    }

	@available(*, unavailable)
	required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
	@available(*, unavailable)
	public override init(frame: CGRect) { fatalError("init(coder:) has not been implemented") }
}

public extension SoramitsuScrollView {

	convenience init() {
		self.init(style: SoramitsuUI.shared.style)
	}

	convenience init(configurator: (SoramitsuScrollViewConfiguration<SoramitsuScrollView>) -> Void) {
		self.init(style: SoramitsuUI.shared.style)
		configurator(sora)
	}
}
