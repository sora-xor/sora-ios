import UIKit

final class ViewObserver: NSObject {

	var viewSizeDidChangeHandler: (() -> Void)?

	private var observation: NSKeyValueObservation?
	private var size: CGSize?

	/// Tells the handler when the view's size has changed. The bounds are set on every pass of layout and on
	/// every scrolled row, far more often than the size changes; each call used to re-make the view's corner
	/// radius and its plate twice over.
	func observe(_ view: UIView) {
		size = view.bounds.size
		observation = view.observe(\.bounds, options: .new) { [weak self] view, _ in
			guard let self, view.bounds.size != self.size else { return }
			self.size = view.bounds.size
			self.viewSizeDidChangeHandler?()
		}
	}
}
