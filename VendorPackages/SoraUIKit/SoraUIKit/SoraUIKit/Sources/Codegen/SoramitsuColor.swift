import UIKit

/// Semantic colour slots. Each theme maps every slot onto a SORA Neon token
/// (`DarkPalette`, `LightPalette`, design spec §2.3).
public enum SoramitsuColor {

	case custom(uiColor: UIColor)

	case bgPage
	case bgSurface
	case bgSurfaceVariant
	case bgSurfaceInverted

	case fgPrimary
	case fgSecondary
	case fgTertiary
	case fgInverted
	case fgOutline

	case accentPrimary
	case accentPrimaryContainer
	case accentSecondary
	case accentSecondaryContainer
	case accentTertiary
	case accentTertiaryContainer

	case statusSuccess
	case statusSuccessContainer
	case statusWarning
	case statusWarningContainer
	case statusError
	case statusErrorContainer
	case statusInfo
	case statusInfoContainer

	case additionalPolkaswap
	case additionalPolkaswapContainer
}

