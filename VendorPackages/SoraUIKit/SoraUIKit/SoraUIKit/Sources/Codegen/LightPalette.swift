import UIKit

// #codegen
final class LightPalette: Palette {
	func color(_ color: SoramitsuColor) -> UIColor {
		switch color {
		case let .custom(uiColor): return uiColor
		
		case .additionalPolkaswapContainer: return UIColor(litHex: 0xF7E1DF)
		case .accentSecondaryContainer: return Lit.wellFloor
		case .fgOutline: return UIColor(litHex: 0xDAD6CE)
		case .statusInfoContainer: return Colors.blue5
		case .accentPrimary: return Lit.lacquerRed
		case .statusErrorContainer: return UIColor(litHex: 0xF7E1DF)
		case .statusWarning: return UIColor(litHex: 0x8A5A0C)
		case .bgSurface: return Lit.surface
		case .statusSuccess: return UIColor(litHex: 0x286448)
		case .accentPrimaryContainer: return UIColor(litHex: 0xF7E1DF)
		case .fgTertiary: return Lit.inkTertiary
		case .accentTertiaryContainer: return Lit.wellFloor
		case .statusError: return Lit.lacquerDeep
		case .fgSecondary: return Lit.inkSecondary
		case .bgPage: return Lit.page
		case .bgSurfaceVariant: return Lit.wellFloor
		case .additionalPolkaswap: return Lit.lacquerRed
		case .bgSurfaceInverted: return Lit.ink
		case .statusWarningContainer: return UIColor(litHex: 0xF3E9D2)
		case .accentTertiary: return Lit.inkTertiary
		case .statusInfo: return Colors.blue40
		case .accentSecondary: return Lit.ink
		case .fgPrimary: return Lit.ink
		case .statusSuccessContainer: return UIColor(litHex: 0xDCEBE2)
		case .fgInverted: return Lit.padLit
		case .additionalPolkaswapText: return Lit.lacquerText
		case .skeletonBase: return Lit.wellFloor
		case .skeletonHighlight: return Colors.white100.withAlphaComponent(0.7)
		}
	}
}