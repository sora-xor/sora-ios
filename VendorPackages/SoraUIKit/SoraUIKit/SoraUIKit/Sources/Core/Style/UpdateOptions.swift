import Foundation

public final class UpdateOptions: NSObject, OptionSet {
	public var rawValue: Int

	public static let palette = UpdateOptions(rawValue: 1 << 0)
	public static let statusBar = UpdateOptions(rawValue: 1 << 1)
	/// Only the effect policy changed (Reduce Transparency, Increase
	/// Contrast, Low Power Mode, thermal state, "Reduce effects"). Colours
	/// and text are unchanged: only surfaces that draw glass, glows, rings or
	/// shadows need to restyle.
	public static let effects = UpdateOptions(rawValue: 1 << 2)
	public static let all: UpdateOptions = [.palette, .statusBar]

	required public init(rawValue: Int) {
		self.rawValue = rawValue
	}

	public override var hash: Int {
		return rawValue
	}

	public override func isEqual(_ object: Any?) -> Bool {
		guard let newObj = object as? UpdateOptions else {
			return false
		}
		return rawValue == newObj.rawValue
	}
}
