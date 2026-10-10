import UIKit

// SORA Neon light ("Daylight") theme slots (design spec §2.3). Values live in
// `NeonTokens`. The switch is exhaustive on purpose.
final class LightPalette: Palette {
	func color(_ color: SoramitsuColor) -> UIColor {
		NeonPaletteMapping.color(color, tokens: .light)
	}
}

enum NeonPaletteMapping {
	static func color(_ color: SoramitsuColor, tokens t: NeonTokens) -> UIColor {
		switch color {
		case let .custom(uiColor): return uiColor

		case .bgPage: return t.canvas
		case .bgSurface: return t.surface
		case .bgSurfaceVariant: return t.surfaceVariant
		case .bgSurfaceInverted: return t.isDark ? t.textPrimary : t.toast

		case .fgPrimary: return t.textPrimary
		case .fgSecondary: return t.textSecondary
		case .fgTertiary: return t.textTertiary
		case .fgInverted: return t.onAccent
		case .fgOutline: return t.divider

		case .accentPrimary: return t.brandRed
		case .accentPrimaryContainer: return t.redContainer
		case .accentSecondary: return t.textPrimary
		case .accentSecondaryContainer: return t.surfaceVariant
		case .accentTertiary: return t.steel
		case .accentTertiaryContainer: return t.tertiaryContainer

		case .statusSuccess: return t.success
		case .statusSuccessContainer: return t.successContainer
		case .statusWarning: return t.warning
		case .statusWarningContainer: return t.warningContainer
		case .statusError: return t.error
		case .statusErrorContainer: return t.errorContainer
		case .statusInfo: return t.info
		case .statusInfoContainer: return t.infoContainer

		case .additionalPolkaswap: return t.polkaswapBrand
		case .additionalPolkaswapContainer: return t.polkaswapContainer
		}
	}
}
