import UIKit

// #codegen
final class DarkPalette: Palette {
	func color(_ color: SoramitsuColor) -> UIColor {
		switch color {
		case let .custom(uiColor): return uiColor
		
        case .statusWarningContainer: return Colors.darkStatusWarningContainer
        case .fgTertiary: return Colors.darkForegroundTertiary
        case .accentSecondary: return Colors.darkAccentSecondary
        case .statusSuccessContainer: return Colors.darkStatusSuccessContainer
        case .accentPrimary: return Colors.darkAccentPrimary
        case .bgSurfaceInverted: return Colors.darkBackgroundSurfaceInverted
        case .accentSecondaryContainer: return Colors.darkAccentSecondaryContainer
        case .fgPrimary: return Colors.darkForegroundPrimary
        case .bgSurface: return Colors.darkBackgroundSurface
        case .accentPrimaryContainer: return Colors.darkAccentPrimaryContainer
        case .fgSecondary: return Colors.darkForegroundSecodary
        case .fgInverted: return Colors.darkForegroundInverted
        case .additionalPolkaswapContainer: return Colors.darkAdditionalPolkaswapContainer
        case .statusError: return Colors.darkStatusError
        case .accentTertiary: return Colors.darkAccentTertiary
        case .bgSurfaceVariant: return Colors.darkBackgroundSurfaceVariant
        case .statusSuccess: return Colors.darkStatusSuccess
        case .accentTertiaryContainer: return Colors.darkAccentTertiaryContainer
        case .statusErrorContainer: return Colors.darkStatusErrorContainer
        case .bgPage: return Colors.darkBackgroundPage
        case .additionalPolkaswap: return Colors.darkAdditionalPolkaswap
        case .statusWarning: return Colors.darkStatusWarning
        case .fgOutline: return Colors.darkForegroundOutline
        case .statusInfo: return Colors.darkStatusInfo
        case .statusInfoContainer: return Colors.darkStatusInfoContainer
		default: return .black
		}
	}
}
