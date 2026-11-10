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

    /// SORA's red (the logo and the XOR icon) and the shading of the hero's planet.
    static let soraRed = UIColor(portfolioHex: 0xE3232C)
    static let soraLight = UIColor(portfolioHex: 0xFF6B6E)
    static let soraDeep = UIColor(portfolioHex: 0xA8101F)
    static let soraEdge = UIColor(portfolioHex: 0x6E0712)
    static let soraGlow = UIColor(portfolioHex: 0xFF2D3D)

    // MARK: Sky

    /// Night (dark) or dawn (light) gradient. It fades out at the bottom, so the sky runs into the
    /// app's page backdrop (the aurora behind every tab) without a seam.
    static func skyColors() -> [CGColor] {
        let fade = tokens.canvas.withAlphaComponent(0).cgColor
        if isDark {
            return [UIColor(portfolioHex: 0x08070F).cgColor, UIColor(portfolioHex: 0x1A0A14).cgColor, fade]
        }
        return [UIColor(portfolioHex: 0xFFF9F7).cgColor, UIColor(portfolioHex: 0xFFE8E5).cgColor, fade]
    }

    static let skyLocations: [NSNumber] = [0, 0.72, 1]

    /// The halo behind the planet.
    static var glowColor: UIColor { soraGlow.withAlphaComponent(isDark ? 0.5 : 0.22) }

    static var hazeViolet: UIColor { UIColor(portfolioHex: 0x6C3BFF, alpha: isDark ? 0.16 : 0.05) }
    static var hazeCyan: UIColor { UIColor(portfolioHex: 0x22D3EE, alpha: isDark ? 0.10 : 0.05) }
    static var starColor: UIColor { UIColor(portfolioHex: 0xFFE9E4) }
    /// The planet's rim on its shadow side.
    static var rimColor: UIColor { isDark ? UIColor(portfolioHex: 0x8AF3FF) : UIColor.white.withAlphaComponent(0.85) }
    /// Orbit lines and the empty band.
    static var ringLine: UIColor { isDark ? .white : UIColor(portfolioHex: 0x3A0B14) }

    /// A quick action's disc, lit to deep, in the hero's colours.
    static func actionColors(_ action: PortfolioQuickAction) -> (lit: UIColor, deep: UIColor) {
        switch action {
        case .send: return (UIColor(portfolioHex: 0xFF5A63), UIColor(portfolioHex: 0xC8102E))
        case .receive: return (UIColor(portfolioHex: 0x5AA8FF), UIColor(portfolioHex: 0x1F5FD6))
        case .move: return (UIColor(portfolioHex: 0xA57BFF), UIColor(portfolioHex: 0x5B2FD1))
        case .swap: return (UIColor(portfolioHex: 0xFF4F96), UIColor(portfolioHex: 0xD6005A))
        }
    }

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

    /// The SORA planet and its ring. The ring is a flat band seen from just above, so on screen it is
    /// widest at the sides and thinnest in front and behind, and every segment keeps its share of the
    /// band's area. Angles are degrees of the ring's own circle: 0 at the right, 90 in front.
    enum Sky {
        /// Height below the safe area.
        static let height: CGFloat = 214
        /// Planet centre below the safe area.
        static let planetCenterY: CGFloat = 132
        static let planetRadius: CGFloat = 46
        /// The ring in its own plane: the band's centre line and width, and the two orbit lines.
        static let ringRadius: CGFloat = 128
        static let ringWidth: CGFloat = 13
        static let orbitOuter: CGFloat = 150
        static let orbitInner: CGFloat = 106
        /// How far beyond the band, on screen, a tap still picks a segment.
        static let tapSlop: CGFloat = 12
        /// The ring plane at rest: its height over its width, and its roll (negative: right side up).
        static let aspect: CGFloat = 0.31
        static let rollDeg: CGFloat = -10
        /// How much more the plane opens and rolls at full deflection.
        static let aspectTilt: CGFloat = 0.07
        static let rollTiltDeg: CGFloat = 6
        /// Gap between two segments, in degrees of the ring's own circle.
        static let gapDeg: CGFloat = 2.4
        static let degreesPerRay: CGFloat = 360 / CGFloat(PortfolioAllocation.rayCount)
        static let selectedWidth: CGFloat = 1.35
        static let dimmedAlpha: Float = 0.26
        /// Seconds per lap of the light that runs round the ring, and for the ring to draw itself in.
        static let cometLap: CFTimeInterval = 9
        static let intro: CFTimeInterval = 1.1
        static let cardOverlap: CGFloat = 22
    }

    enum Depth {
        // Points at full deflection (x; y is about 0.65 x).
        static let stars: CGFloat = 3
        /// The planet and its ring move as one.
        static let planet: CGFloat = 14
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

    /// This colour mixed with `other`: 0 keeps it, 1 gives `other`.
    func blended(with other: UIColor, _ fraction: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * fraction, green: g1 + (g2 - g1) * fraction,
                       blue: b1 + (b2 - b1) * fraction, alpha: a1 + (a2 - a1) * fraction)
    }
}
