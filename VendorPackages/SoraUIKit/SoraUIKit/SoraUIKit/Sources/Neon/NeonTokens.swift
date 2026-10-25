import UIKit

// SORA Neon design tokens (design spec §2.1 dark, §2.2 light).
//
// This file is the single source of the hex values. The legacy
// `SoramitsuColor` slots (`DarkPalette` / `LightPalette`) map onto these
// tokens (spec §2.3), so every `sora.*Color` call site picks them up.
// Blur values are a design blur B (Figma/CSS); a CALayer shadow radius is B / 2.

public struct NeonGradient {
    public let colors: [UIColor]
    public let locations: [CGFloat]

    public init(_ stops: [(CGFloat, UIColor)]) {
        colors = stops.map(\.1)
        locations = stops.map(\.0)
    }

    public var cgColors: [CGColor] { colors.map(\.cgColor) }
    public var nsLocations: [NSNumber] { locations.map { NSNumber(value: Double($0)) } }
}

public struct GlowSpec {
    public let color: UIColor
    public let rest: Float
    public let peak: Float
    public let pressed: Float
    /// Design blur B. `CALayer.shadowRadius` is `blur / 2`.
    public let blur: CGFloat
    public let offsetY: CGFloat
}

public struct ShadowSpec {
    public let color: UIColor
    public let alpha: Float
    /// Design blur B. `CALayer.shadowRadius` is `blur / 2`.
    public let blur: CGFloat
    public let offset: CGSize
}

public struct NeonTokens {
    public let isDark: Bool

    // Surfaces
    public let canvas, layer1, surface, surfaceVariant, sheet, toast, scrim, scrimOverBlur: UIColor
    // Ambient
    public let auroraCyan, auroraMagenta, auroraRed, safeAuroraMint, safeAuroraCyan: UIColor
    public let gridMinor, gridMajor: UIColor
    // Glass
    public let glassFill, glassFillStrong, glassFillPressed, glassSolid, chromeTint16, glassTint26: UIColor
    /// Fill for legacy `.bgSurface` cards drawn as glass: translucent enough to
    /// pick up the aurora, opaque enough that body text keeps its contrast
    /// over any backdrop (including photos).
    public let cardFill: UIColor
    /// Opaque fill for text fields (on cards and on the page).
    public let inputFill: UIColor
    public let glassHighlight, borderGlass, borderSpectrum, borderSafe, borderCtaSheen, borderChromeTop: NeonGradient
    public let cardShadow: ShadowSpec?
    // Lines
    public let hairline, divider, borderInput, focusRing: UIColor
    // Text
    public let textPrimary, textSecondary, textTertiary, textDisabled, onAccent, link: UIColor
    // Accents
    public let brandRed, redText, cyan, steel, magenta, polkaswapBrand, polkaswapText: UIColor
    public let ctaPrimary, ctaSwap, ctaSafe: NeonGradient
    public let ctaDisabled: UIColor
    // Status
    public let success, successContainer, warning, warningContainer, warningFill, onWarningFill: UIColor
    public let error, errorContainer, info, infoContainer, redContainer: UIColor
    // Slot-only containers (spec §2.3)
    public let tertiaryContainer, polkaswapContainer: UIColor
    // Glow
    public let glowPrimary, glowSwap, glowFocus, glowDot, glowTab, glowSafe, glowSuccess: GlowSpec
    public let heroTextGlow: UIColor?
    // Neumorphic
    public let neuBg, neuFacePressed: UIColor
    public let neuFace, neuRim: NeonGradient
    public let neuDark, neuLight, neuInnerDark, neuInnerLight: ShadowSpec
    // Skeleton
    public let skeletonBase, skeletonHighlight: UIColor

    /// Tokens for the theme currently shown by the app (not the system theme).
    public static var current: NeonTokens {
        SoramitsuUI.shared.theme == .dark ? .dark : .light
    }

    public static func tokens(for theme: SoramitsuThemeType) -> NeonTokens {
        theme == .dark ? .dark : .light
    }
}

// MARK: - Values

private func c(_ rgb: UInt32, _ alpha: CGFloat = 1) -> UIColor {
    UIColor(red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: alpha)
}

private let clear = UIColor.clear

public extension NeonTokens {
    static let dark = NeonTokens(
        isDark: true,
        canvas: c(0x06060B), layer1: c(0x0C0C15), surface: c(0x14141F), surfaceVariant: c(0x1C1C28),
        sheet: c(0x191926), toast: c(0x222233), scrim: c(0x000000, 0.55), scrimOverBlur: c(0x000000, 0.40),
        auroraCyan: c(0x00E5FF, 0.08), auroraMagenta: c(0xFF2BD6, 0.08), auroraRed: c(0xFF2244, 0.08),
        safeAuroraMint: c(0x2EF2A4, 0.07), safeAuroraCyan: c(0x00E5FF, 0.06),
        gridMinor: c(0x2EE6FF, 0.03), gridMajor: c(0x2EE6FF, 0.05),
        glassFill: c(0xFFFFFF, 0.05), glassFillStrong: c(0xFFFFFF, 0.08), glassFillPressed: c(0xFFFFFF, 0.10),
        glassSolid: c(0x14141F), chromeTint16: c(0x0A0A12, 0.80), glassTint26: c(0x06060B, 0.30),
        cardFill: c(0x14141F, 0.88), inputFill: c(0x1C1C28),
        glassHighlight: NeonGradient([(0, c(0xFFFFFF, 0.07)), (0.5, c(0xFFFFFF, 0))]),
        borderGlass: NeonGradient([(0, c(0xFFFFFF, 0.22)), (0.40, c(0xFFFFFF, 0.06)),
                                   (0.75, c(0xFFFFFF, 0.04)), (1, c(0x2EE6FF, 0.28))]),
        borderSpectrum: NeonGradient([(0, c(0x00E5FF, 0.80)), (0.5, c(0x8A5CFF, 0.45)), (1, c(0xFF2A55, 0.80))]),
        borderSafe: NeonGradient([(0, c(0x2EF2A4, 0.60)), (1, c(0x2EE6FF, 0.45))]),
        borderCtaSheen: NeonGradient([(0, c(0xFFFFFF, 0.40)), (0.5, c(0xFFFFFF, 0))]),
        borderChromeTop: NeonGradient([(0, clear), (0.5, c(0xFFFFFF, 0.12)), (1, clear)]),
        cardShadow: nil,
        hairline: c(0xFFFFFF, 0.10), divider: c(0x26263A), borderInput: c(0x6C6F80), focusRing: c(0x2EE6FF),
        textPrimary: c(0xF5F6FB), textSecondary: c(0xB3B7CB), textTertiary: c(0x969BB4),
        textDisabled: c(0x5E6277), onAccent: c(0x06060B), link: c(0x2EE6FF),
        brandRed: c(0xFF3355), redText: c(0xFF5A75), cyan: c(0x2EE6FF), steel: c(0x7CCFE0),
        magenta: c(0xFF5CE1), polkaswapBrand: c(0xFF0066), polkaswapText: c(0xFF5C9E),
        ctaPrimary: NeonGradient([(0, c(0xFF2A4A)), (1, c(0xFF3D7F))]),
        ctaSwap: NeonGradient([(0, c(0xFF0066)), (1, c(0xFF3DDC))]),
        ctaSafe: NeonGradient([(0, c(0x2EF2A4)), (1, c(0x2EE6FF))]),
        ctaDisabled: c(0xFFFFFF, 0.08),
        success: c(0x2EF2A4), successContainer: c(0x0B221D), warning: c(0xFFB547),
        warningContainer: c(0x241B12), warningFill: c(0xFFB547), onWarningFill: c(0x06060B),
        error: c(0xFF6B85), errorContainer: c(0x2A1119), info: c(0x2EE6FF), infoContainer: c(0x0B2128),
        redContainer: c(0x2A0C15),
        tertiaryContainer: c(0x0F1E24), polkaswapContainer: c(0x2B0614),
        glowPrimary: GlowSpec(color: c(0xFF2A55), rest: 0.45, peak: 0.70, pressed: 0.85, blur: 24, offsetY: 6),
        glowSwap: GlowSpec(color: c(0xFF0066), rest: 0.45, peak: 0.65, pressed: 0.80, blur: 20, offsetY: 4),
        glowFocus: GlowSpec(color: c(0x00E5FF), rest: 0.35, peak: 0.35, pressed: 0.60, blur: 12, offsetY: 0),
        glowDot: GlowSpec(color: c(0x00E5FF), rest: 0.50, peak: 0.50, pressed: 0.50, blur: 8, offsetY: 0),
        glowTab: GlowSpec(color: c(0xFF3355), rest: 0.60, peak: 0.60, pressed: 0.60, blur: 8, offsetY: 0),
        glowSafe: GlowSpec(color: c(0x2EF2A4), rest: 0.25, peak: 0.30, pressed: 0.25, blur: 20, offsetY: 0),
        glowSuccess: GlowSpec(color: c(0x2EF2A4), rest: 0.25, peak: 0.60, pressed: 0.25, blur: 24, offsetY: 0),
        heroTextGlow: c(0x00E5FF, 0.30),
        neuBg: c(0x0F0F18), neuFacePressed: c(0x101019),
        neuFace: NeonGradient([(0, c(0x191924)), (1, c(0x121219))]),
        neuRim: NeonGradient([(0, c(0xFFFFFF, 0.08)), (1, c(0xFFFFFF, 0))]),
        neuDark: ShadowSpec(color: c(0x000000), alpha: 0.65, blur: 12, offset: CGSize(width: 5, height: 5)),
        neuLight: ShadowSpec(color: c(0xFFFFFF), alpha: 0.07, blur: 10, offset: CGSize(width: -4, height: -4)),
        neuInnerDark: ShadowSpec(color: c(0x000000), alpha: 0.50, blur: 8, offset: CGSize(width: 3, height: 3)),
        neuInnerLight: ShadowSpec(color: c(0xFFFFFF), alpha: 0.05, blur: 6, offset: CGSize(width: -2, height: -2)),
        skeletonBase: c(0xFFFFFF, 0.05), skeletonHighlight: c(0xFFFFFF, 0.10)
    )

    static let light = NeonTokens(
        isDark: false,
        canvas: c(0xF2F3F8), layer1: c(0xECEEF5), surface: c(0xFFFFFF), surfaceVariant: c(0xE9EBF2),
        sheet: c(0xFFFFFF), toast: c(0x14141F), scrim: c(0x0B0C14, 0.32), scrimOverBlur: c(0x0B0C14, 0.24),
        auroraCyan: c(0x00C8E6, 0.10), auroraMagenta: c(0xFF2BD6, 0.07), auroraRed: c(0xFF2244, 0.06),
        safeAuroraMint: c(0x12B886, 0.08), safeAuroraCyan: c(0x00C8E6, 0.08),
        gridMinor: c(0x00708A, 0.04), gridMajor: c(0x00708A, 0.07),
        glassFill: c(0xFFFFFF, 0.72), glassFillStrong: c(0xFFFFFF, 0.85), glassFillPressed: c(0xE9EBF2, 0.85),
        glassSolid: c(0xFFFFFF), chromeTint16: c(0xF2F3F8, 0.80), glassTint26: c(0xFFFFFF, 0.30),
        cardFill: c(0xFFFFFF, 0.80), inputFill: c(0xFFFFFF),
        glassHighlight: NeonGradient([(0, c(0xFFFFFF, 0.60)), (0.5, c(0xFFFFFF, 0))]),
        borderGlass: NeonGradient([(0, c(0xFFFFFF, 1)), (0.40, c(0x0B0C14, 0.06)),
                                   (0.75, c(0x0B0C14, 0.08)), (1, c(0x00A3C4, 0.30))]),
        borderSpectrum: NeonGradient([(0, c(0x00A3C4, 0.70)), (0.5, c(0x7B4DFF, 0.40)), (1, c(0xC80E34, 0.70))]),
        borderSafe: NeonGradient([(0, c(0x08704D, 0.50)), (1, c(0x00708A, 0.40))]),
        borderCtaSheen: NeonGradient([(0, c(0xFFFFFF, 0.30)), (0.5, c(0xFFFFFF, 0))]),
        borderChromeTop: NeonGradient([(0, clear), (0.5, c(0x0B0C14, 0.08)), (1, clear)]),
        cardShadow: ShadowSpec(color: c(0x0B0C14), alpha: 0.06, blur: 24, offset: CGSize(width: 0, height: 8)),
        hairline: c(0x0B0C14, 0.08), divider: c(0xDADCE5), borderInput: c(0x7E8296), focusRing: c(0x00708A),
        textPrimary: c(0x0B0C14), textSecondary: c(0x454A5E), textTertiary: c(0x5E6278),
        textDisabled: c(0xA4A8B9), onAccent: c(0xFFFFFF), link: c(0x00708A),
        brandRed: c(0xC80E34), redText: c(0xC80E34), cyan: c(0x00708A), steel: c(0x1F6B7C),
        magenta: c(0xA3127C), polkaswapBrand: c(0xD6005A), polkaswapText: c(0xB0004B),
        ctaPrimary: NeonGradient([(0, c(0xC80E34)), (1, c(0xA50D4A))]),
        ctaSwap: NeonGradient([(0, c(0xD6005A)), (1, c(0xA3128A))]),
        ctaSafe: NeonGradient([(0, c(0x08704D)), (1, c(0x00708A))]),
        ctaDisabled: c(0x0B0C14, 0.06),
        success: c(0x08704D), successContainer: c(0xE3F6F0), warning: c(0x8A4F00),
        warningContainer: c(0xFFF0DA), warningFill: c(0xFFB547), onWarningFill: c(0x0B0C14),
        error: c(0xBC0E2D), errorContainer: c(0xF9E7EA), info: c(0x00708A), infoContainer: c(0xE0F8FC),
        redContainer: c(0xFBE7EB),
        tertiaryContainer: c(0xE2F3F7), polkaswapContainer: c(0xFCE3EE),
        glowPrimary: GlowSpec(color: c(0xC80E34), rest: 0.28, peak: 0.40, pressed: 0.50, blur: 20, offsetY: 8),
        glowSwap: GlowSpec(color: c(0xD6005A), rest: 0.28, peak: 0.40, pressed: 0.50, blur: 20, offsetY: 8),
        glowFocus: GlowSpec(color: c(0x00A3C4), rest: 0.28, peak: 0.40, pressed: 0.50, blur: 20, offsetY: 8),
        glowDot: GlowSpec(color: c(0x00A3C4), rest: 0.30, peak: 0.30, pressed: 0.30, blur: 8, offsetY: 0),
        glowTab: GlowSpec(color: c(0xC80E34), rest: 0.35, peak: 0.35, pressed: 0.35, blur: 8, offsetY: 0),
        glowSafe: GlowSpec(color: c(0x12B886), rest: 0.28, peak: 0.40, pressed: 0.50, blur: 20, offsetY: 8),
        glowSuccess: GlowSpec(color: c(0x12B886), rest: 0.28, peak: 0.40, pressed: 0.28, blur: 20, offsetY: 8),
        heroTextGlow: nil,
        neuBg: c(0xECEEF5), neuFacePressed: c(0xE3E6EF),
        neuFace: NeonGradient([(0, c(0xF4F6FB)), (1, c(0xE3E6EF))]),
        neuRim: NeonGradient([(0, c(0xFFFFFF, 1)), (1, c(0xFFFFFF, 0))]),
        neuDark: ShadowSpec(color: c(0xA3A9C0), alpha: 0.55, blur: 14, offset: CGSize(width: 6, height: 6)),
        neuLight: ShadowSpec(color: c(0xFFFFFF), alpha: 1, blur: 14, offset: CGSize(width: -6, height: -6)),
        neuInnerDark: ShadowSpec(color: c(0xA3A9C0), alpha: 0.50, blur: 8, offset: CGSize(width: 3, height: 3)),
        neuInnerLight: ShadowSpec(color: c(0xFFFFFF), alpha: 0.90, blur: 8, offset: CGSize(width: -3, height: -3)),
        skeletonBase: c(0x0B0C14, 0.06), skeletonHighlight: c(0xFFFFFF, 0.70)
    )
}

/// Motion tokens (spec §4.7.1).
public enum NeonMotion {
    public static let press: TimeInterval = 0.09
    public static let fast: TimeInterval = 0.16
    public static let base: TimeInterval = 0.24
    public static let slow: TimeInterval = 0.32
    public static let hero: TimeInterval = 0.5
    public static let standard = CAMediaTimingFunction(controlPoints: 0.2, 0, 0, 1)
    public static let decelerate = CAMediaTimingFunction(controlPoints: 0.05, 0.7, 0.1, 1)
    public static let exit = CAMediaTimingFunction(controlPoints: 0.3, 0, 1, 1)
    public static let sine = CAMediaTimingFunction(controlPoints: 0.37, 0, 0.63, 1)
}
