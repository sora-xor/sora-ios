import UIKit

// SORA Neon dark theme slots (design spec §2.3). Values live in `NeonTokens`.
// The switch is exhaustive on purpose: a new slot without a value must fail
// to compile instead of silently rendering black.
final class DarkPalette: Palette {
	func color(_ color: SoramitsuColor) -> UIColor {
		NeonPaletteMapping.color(color, tokens: .dark)
	}
}
