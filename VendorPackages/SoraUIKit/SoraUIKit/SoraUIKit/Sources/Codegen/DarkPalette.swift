import UIKit

// #codegen
final class DarkPalette: Palette {
	func color(_ color: SoramitsuColor) -> UIColor {
		switch color {
		case let .custom(uiColor): return uiColor
		
		case .statusWarningContainer: return Colors.darktheme19
		case .fgTertiary: return Colors.darktheme13
		case .accentSecondary: return Colors.darktheme3
		case .statusSuccessContainer: return Colors.darktheme17
		case .accentPrimary: return Colors.darktheme1
		case .bgSurfaceInverted: return Colors.darktheme10
		case .accentSecondaryContainer: return Colors.darktheme4
		case .fgPrimary: return Colors.darktheme11
		case .bgSurface: return Colors.darktheme8
		case .accentPrimaryContainer: return Colors.darktheme2
		case .fgSecondary: return Colors.darktheme12
		case .fgInverted: return Colors.darktheme14
		case .additionalPolkaswapContainer: return Colors.polkaswap5
		case .statusError: return Colors.darktheme20
		case .accentTertiary: return Colors.darktheme5
		case .bgSurfaceVariant: return Colors.darktheme9
		case .statusSuccess: return Colors.darktheme16
		case .accentTertiaryContainer: return Colors.darktheme6
		case .statusErrorContainer: return Colors.darktheme21
		case .bgPage: return Colors.darktheme7
		case .additionalPolkaswap: return Colors.polkaswap40
		case .statusWarning: return Colors.darktheme18
		case .fgOutline: return Colors.darktheme15
		case .statusInfo: return Colors.blue40
		case .statusInfoContainer: return Colors.blue5
		default: return .black
		}
	}
}