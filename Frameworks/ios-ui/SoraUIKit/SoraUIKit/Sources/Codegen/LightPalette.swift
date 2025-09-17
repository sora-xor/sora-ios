import UIKit

// #codegen
final class LightPalette: Palette {
	func color(_ color: SoramitsuColor) -> UIColor {
		switch color {
		case let .custom(uiColor): return uiColor
		
        case .additionalPolkaswapContainer: return Colors.additionalPolkaswapContainer
        case .accentSecondaryContainer: return Colors.accentSecondary
        case .fgOutline: return Colors.foregroundOutline
        case .statusInfoContainer: return Colors.statusInfoContainer
        case .accentPrimary: return Colors.accentPrimary
        case .statusErrorContainer: return Colors.statusErrorContainer
        case .statusWarning: return Colors.statusWarning
        case .bgSurface: return Colors.backgroundSurface
        case .statusSuccess: return Colors.statusSuccess
        case .accentPrimaryContainer: return Colors.accentPrimaryContainer
        case .fgTertiary: return Colors.foregroundTertiary
        case .accentTertiaryContainer: return Colors.accentTertiaryContainer
        case .statusError: return Colors.statusError
        case .fgSecondary: return Colors.foregroundSecodary
        case .bgPage: return Colors.backgroundPage
        case .bgSurfaceVariant: return Colors.backgroundSurfaceVariant
        case .additionalPolkaswap: return Colors.additionalPolkaswap
        case .bgSurfaceInverted: return Colors.backgroundSurfaceInverted
        case .statusWarningContainer: return Colors.statusWarningContainer
        case .accentTertiary: return Colors.accentTertiary
        case .statusInfo: return Colors.statusInfo
        case .accentSecondary: return Colors.accentSecondary
        case .fgPrimary: return Colors.foregroundPrimary
        case .statusSuccessContainer: return Colors.statusSuccessContainer
        case .fgInverted: return Colors.foregroundInverted
		default: return .black
		}
	}
}
