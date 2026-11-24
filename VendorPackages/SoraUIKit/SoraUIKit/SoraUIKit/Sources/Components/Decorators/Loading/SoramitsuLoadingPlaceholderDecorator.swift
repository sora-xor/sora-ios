import UIKit

public enum SoramitsuLoadingPlaceholderType: CaseIterable {
	case none
	case activity
	case shimmer
	case retry
}

public final class SoramitsuLoadingPlaceholderDecorator {

	/// Тип заглушки
	public var type: SoramitsuLoadingPlaceholderType = .none {
		didSet {
			guard type != oldValue else { return }
			DispatchQueue.main.async { [weak self] in
				self?.updatePlaceholder()
			}
		}
	}

	// Each overlay is made the first time it is shown. Taking one away never makes it: a view that only
	// ever shimmered used to get a retry button (and its cut glass, following the light) made just to be
	// removed, and that button kept itself alive through its own handler.
	private var madeShimmer = false
	private var madeActivity = false
	private var madeRetry = false

	public private(set) lazy var shimmerview: SoramitsuShimmerView = {
		madeShimmer = true
		return SoramitsuShimmerView(style: style)
	}()

	public private(set) lazy var activityView: SoramitsuActivityIndicatorView = {
		madeActivity = true
		return SoramitsuActivityIndicatorView(style: style)
	}()

	public var retryHandler: (() -> Void)?

	private(set) lazy var retryButton: SoramitsuButton = {
		madeRetry = true
        let button = SoramitsuButton(style: style, size: .large)
		button.sora.stater.animationDuration = 0.4
		let rotation: CGFloat = -1 * .pi
		button.sora.associate(states: .pressed) { sora in
            sora.transform = sora.transform.rotated(by: rotation)
            sora.transform = sora.transform.rotated(by: rotation)
		}
		let delay = button.sora.stater.animationDuration
		button.sora.addHandler(for: .touchUpInside) { [weak self] in
			DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
				self?.retryHandler?()
			}
		}
		return button
	}()

	weak var view: UIView?

	private let style: SoramitsuStyle

	init(style: SoramitsuStyle) {
		self.style = style
	}

	private func updatePlaceholder() {
		guard let view = view else { return }
		// Animate the shimmer itself, not a snapshot of the entire decorated
		// view. Cross-dissolving loaded content makes tab changes flash.
		UIView.performWithoutAnimation {
			switch self.type {
			case .none:
				self.stopAll()
			case .activity:
				self.removeRetry()
				self.stopShimmer()
				self.add(self.activityView, on: view)
				self.activityView.pinToSuperView(respectingSafeArea: false)
				self.activityView.startAnimating()
			case .shimmer:
				self.removeRetry()
				self.stopActivity()
				self.add(self.shimmerview, on: view)
				self.shimmerview.pinToSuperView(respectingSafeArea: false)
				self.shimmerview.sora.startShimmering()
			case .retry:
				self.stopAll()
				view.isUserInteractionEnabled = true
				self.add(self.retryButton, on: view)
				self.retryButton.makeSquare()
				NSLayoutConstraint.activate([
					self.retryButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
					self.retryButton.centerYAnchor.constraint(equalTo: view.centerYAnchor)
				])
			}
		}
	}

	private func add(_ subview: UIView, on view: UIView) {
		if let navigationBar = view.subviews.first(where: { $0 is UINavigationBar }) {
			view.insertSubview(subview, belowSubview: navigationBar)
		} else {
			view.addSubview(subview)
		}
	}

	private func stopAll() {
		removeRetry()
		stopActivity()
		stopShimmer()
	}

	private func removeRetry() {
		guard madeRetry else { return }
		retryButton.removeFromSuperview()
	}

	private func stopActivity() {
		guard madeActivity else { return }
		self.activityView.removeFromSuperview()
		self.activityView.stopAnimating()
	}

	private func stopShimmer() {
		guard madeShimmer else { return }
		self.shimmerview.removeFromSuperview()
		self.shimmerview.sora.stopShimmering()
	}
}
