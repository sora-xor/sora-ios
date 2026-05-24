import UIKit

public protocol SoramitsuHapticable {

	func prepare()

	func prepare(if condition: Bool)

	func tic()
}

public extension SoramitsuHapticable {

	func prepare(if condition: Bool) {
		if condition {
			prepare()
		}
	}
}

extension UIImpactFeedbackGenerator: SoramitsuHapticable {
	public func tic() {
		impactOccurred()
	}
}

final class SoramitsuNotificationFeedbackGenerator: UINotificationFeedbackGenerator {

	private let type: SoramitsuHapticNotificationType

	init(type: SoramitsuHapticNotificationType) {
		self.type = type
		super.init()
	}
}

extension SoramitsuNotificationFeedbackGenerator: SoramitsuHapticable {
	func tic() {
		notificationOccurred(type.style)
	}
}

private extension SoramitsuHapticNotificationType {

	var style: UINotificationFeedbackGenerator.FeedbackType {
		switch self {
		case .error: return .error
		case .success: return .success
		case .warning: return .warning
		}
	}
}
