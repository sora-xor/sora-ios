// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

import SoraUIKit
import UIKit

/// Colours, type and geometry of the portfolio surfaces. Everything that is not a chart slot or the
/// sky comes from the app's Neon tokens, so both themes and the effect tiers follow the app.
enum PortfolioTheme {
    // MARK: Tokens

    static var tokens: NeonTokens { NeonTokens.current }
    static var isDark: Bool { SoramitsuUI.shared.theme == .dark }

    // MARK: Chart slots (validated for colour-blind separation; colour follows the entity)

    static let slotColors: [UIColor] = [
        UIColor(portfolioHex: 0xFF009A),
        UIColor(portfolioHex: 0x4693F1),
        UIColor(portfolioHex: 0xA97416),
        UIColor(portfolioHex: 0x8B5CFF),
        UIColor(portfolioHex: 0x3CA694)
    ]
    static let otherColor = UIColor(portfolioHex: 0x6F7280)

    static func color(for slot: PortfolioSlot) -> UIColor {
        switch slot {
        case let .slot(index): return slotColors.indices.contains(index) ? slotColors[index] : otherColor
        case .other: return otherColor
        }
    }

    // MARK: Brand

    /// The Polkaswap flower's own fill (the asset catalogue vector). The mark is never recoloured.
    static let flowerPink = UIColor(portfolioHex: 0xFF0066)

    // MARK: Sky

    /// Night (dark) or dawn (light) gradient. It fades out at the bottom, so the sky runs into the
    /// app's page backdrop (the aurora behind every tab) without a seam.
    static func skyColors() -> [CGColor] {
        let fade = tokens.canvas.withAlphaComponent(0).cgColor
        if isDark {
            return [UIColor(portfolioHex: 0x0B0A14).cgColor, UIColor(portfolioHex: 0x1B0C24).cgColor, fade]
        }
        return [UIColor(portfolioHex: 0xFFF6FA).cgColor, UIColor(portfolioHex: 0xFFE3EE).cgColor, fade]
    }

    static let skyLocations: [NSNumber] = [0, 0.72, 1]

    static var glowColor: UIColor {
        isDark ? UIColor(portfolioHex: 0xFF0066, alpha: 0.34) : UIColor(portfolioHex: 0xFF0066, alpha: 0.16)
    }

    static var starColor: UIColor { UIColor(portfolioHex: 0xFFE7C2) }

    // MARK: Text and status

    static var textPrimary: UIColor { tokens.textPrimary }
    static var textSecondary: UIColor { tokens.textSecondary }
    static var textTertiary: UIColor { tokens.textTertiary }
    static var up: UIColor { tokens.success }
    static var down: UIColor { tokens.error }
    static var warning: UIColor { tokens.warning }
    static var hairline: UIColor { tokens.hairline }
    static var accentText: UIColor { tokens.polkaswapText }

    // MARK: Type (scaled for Dynamic Type)

    static func font(_ data: FontData, _ style: UIFont.TextStyle, maximum: CGFloat? = nil) -> UIFont {
        let metrics = UIFontMetrics(forTextStyle: style)
        if let maximum {
            return metrics.scaledFont(for: data.font, maximumPointSize: maximum)
        }
        return metrics.scaledFont(for: data.font)
    }

    static func font(_ data: FontData, size: CGFloat, _ style: UIFont.TextStyle) -> UIFont {
        UIFontMetrics(forTextStyle: style).scaledFont(for: data.font.withSize(size))
    }

    // MARK: Geometry

    enum Sky {
        /// Height below the safe area.
        static let height: CGFloat = 214
        /// Flower centre below the safe area.
        static let flowerCenterY: CGFloat = 138
        static let flowerSize: CGFloat = 76
        static let innerRadius: CGFloat = 52
        static let outerRadius: CGFloat = 108
        static let rayWidth: CGFloat = 1.7
        /// Rays fade in over the inner 30 % of their length.
        static let fadeFraction: CGFloat = 0.3
        static let highlightLift: CGFloat = 6
        static let dimmedAlpha: Float = 0.26
        static let cardOverlap: CGFloat = 22
    }

    enum Depth {
        // Points at full deflection (x; y is about 0.65 x).
        static let stars: CGFloat = 3
        static let fan: CGFloat = 7
        static let sheen: CGFloat = 7
        static let flower: CGFloat = 22
        static let flowerRotationDeg: CGFloat = 1.4
        static let glow: CGFloat = 10
        static let ring: CGFloat = 3
        static let orb: CGFloat = 8
        static let satellites: CGFloat = 15
        static let polkaswapNode: CGFloat = 24
        static let yFactor: CGFloat = 0.65
    }
}

extension UIColor {
    convenience init(portfolioHex rgb: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255,
                  green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255,
                  alpha: alpha)
    }
}
