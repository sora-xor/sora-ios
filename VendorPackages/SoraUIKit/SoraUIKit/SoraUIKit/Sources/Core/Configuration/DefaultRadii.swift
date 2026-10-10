import CoreGraphics

struct DefaultRadii: Radii {
	var small: CGFloat = 12
	var medium: CGFloat = 16
	var large: CGFloat = 20
	var extraLarge: CGFloat = 24
	/// The card radius (SORA Neon cards are 24; it was 32).
	var max: CGFloat = 24
}
