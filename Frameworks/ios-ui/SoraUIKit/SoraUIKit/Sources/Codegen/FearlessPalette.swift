import UIKit

final class FearlessPalette: Palette {
    func color(_ color: SoramitsuColor) -> UIColor {
        switch color {
        case let .custom(uiColor): return uiColor
        
        case .additionalPolkaswapContainer: return UIColor(hex: "#FF2782")
        case .accentSecondaryContainer: return UIColor(hex: "#313131")
        case .fgOutline: return UIColor(hex: "#F5F2F2")
        case .statusInfoContainer: return Colors.blue5
        case .accentPrimary: return UIColor(hex: "#EE0077")
        case .statusErrorContainer: return UIColor(hex: "#FFE8EB")
        case .statusWarning: return UIColor(hex: "#FF9900")
        case .bgSurface: return UIColor(hex: "#171717")
        case .statusSuccess: return UIColor(hex: "#33B590")
        case .accentPrimaryContainer: return UIColor(hex: "#FFE8EB")
        case .fgTertiary: return UIColor(hex: "#C3B3B3")
        case .accentTertiaryContainer: return UIColor(hex: "#313131")
        case .statusError: return UIColor(hex: "#FC4252")
        case .fgSecondary: return UIColor(hex: "#808080")
        case .bgPage: return UIColor(hex: "#070707")
        case .bgSurfaceVariant: return UIColor(hex: "#313131")
        case .additionalPolkaswap: return UIColor(hex: "#FF2782")
        case .bgSurfaceInverted: return UIColor(hex: "#FCFCFC")
        case .statusWarningContainer: return UIColor(hex: "#FFF1D2")
        case .accentTertiary: return UIColor(hex: "#808080")
        case .statusInfo: return Colors.blue40
        case .accentSecondary: return UIColor(hex: "#FCFCFC")
        case .fgPrimary: return UIColor(hex: "#FCFCFC")
        case .statusSuccessContainer: return UIColor(hex: "#D3F6EC")
        case .fgInverted: return UIColor(hex: "#070707")
        default: return .black
        }
    }
}

extension UIColor {
    convenience init(hex: String, alpha: CGFloat = 1.0) {

        let hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)

        let offset = hexString.hasPrefix("#") ? 1 : 0
        let start = hexString.index(hexString.startIndex, offsetBy: offset)
        let hexColor = String(hexString[start...])

        let scanner = Scanner(string: hexColor)

        var color: UInt64 = 0
        scanner.scanHexInt64(&color)

        let mask = 0x000000FF
        let red     = Int(color >> 16) & mask
        let green   = Int(color >> 8) & mask
        let blue    = Int(color) & mask

        self.init(red: CGFloat(red) / 255.0,
                  green: CGFloat(green) / 255.0,
                  blue: CGFloat(blue) / 255.0,
                  alpha: alpha)
    }
}
