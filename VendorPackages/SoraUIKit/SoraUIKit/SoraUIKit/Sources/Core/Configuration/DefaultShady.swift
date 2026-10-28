import UIKit

/// Theme-aware shadows (SORA Neon). Light: soft ink shadows. Dark: deeper
/// black shadows that still separate a surface from the near-black canvas.
/// Cards drawn as glass use `NeonTokens.cardShadow` instead (light only).
struct DefaultShady: Shady {
	private static let ink = UIColor(red: 11 / 255.0, green: 12 / 255.0, blue: 20 / 255.0, alpha: 1).cgColor
	private static let black = UIColor.black.cgColor

	func shadow(_ gShadow: Shadow, dark: Bool) -> ShadowData {
		switch (gShadow, dark) {
		case (.none, _):
			return ShadowData(color: nil, offset: .zero, radius: 0, opacity: 0)
		case (.extraSmall, false):
			return ShadowData(color: Self.ink, offset: .zero, radius: 8, opacity: 0.06)
		case (.small, false):
			return ShadowData(color: Self.ink, offset: CGSize(width: 0, height: 8), radius: 12, opacity: 0.06)
		case (.default, false):
			return ShadowData(color: Self.ink, offset: CGSize(width: 0, height: 10), radius: 14, opacity: 0.08)
		case (.extraSmall, true):
			return ShadowData(color: Self.black, offset: .zero, radius: 8, opacity: 0.35)
		case (.small, true):
			return ShadowData(color: Self.black, offset: CGSize(width: 0, height: 8), radius: 12, opacity: 0.45)
		case (.default, true):
			return ShadowData(color: Self.black, offset: CGSize(width: 0, height: 10), radius: 14, opacity: 0.5)
		}
	}
}
