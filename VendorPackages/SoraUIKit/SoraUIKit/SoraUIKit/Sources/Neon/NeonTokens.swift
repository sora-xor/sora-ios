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

    /// The tokens the app draws with: the classic SORA layout and colours in lit materials
    /// (porcelain plates, wells, lacquer), one light over everything. See `Lit`.
    public static var current: NeonTokens { .lit }

    public static func tokens(for theme: SoramitsuThemeType) -> NeonTokens { .lit }
}

// MARK: - Values

private func c(_ rgb: UInt32, _ alpha: CGFloat = 1) -> UIColor {
    UIColor(red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: alpha)
}

private let clear = UIColor.clear

// MARK: - Classic

private let noGradient = NeonGradient([(0, clear), (1, clear)])
private func solid(_ color: UIColor) -> NeonGradient { NeonGradient([(0, color), (1, color)]) }
private let noGlow = GlowSpec(color: clear, rest: 0, peak: 0, pressed: 0, blur: 0, offsetY: 0)
private let noShadow = ShadowSpec(color: clear, alpha: 0, blur: 0, offset: .zero)

public extension NeonTokens {
    /// The classic layout's slots in lit porcelain. Plates, wells and gloss come from `Lit`; these are the
    /// colours of what sits on them and of the surfaces that have no plate.
    static let lit = NeonTokens(
        isDark: false,
        canvas: Lit.page, layer1: Lit.page, surface: Lit.surface, surfaceVariant: Lit.wellFloor,
        sheet: Lit.surface, toast: Colors.brown90,
        scrim: Colors.brown90.withAlphaComponent(0.32), scrimOverBlur: Colors.brown90.withAlphaComponent(0.24),
        auroraCyan: clear, auroraMagenta: clear, auroraRed: clear, safeAuroraMint: clear, safeAuroraCyan: clear,
        gridMinor: clear, gridMajor: clear,
        glassFill: Lit.surface, glassFillStrong: Lit.surface, glassFillPressed: Lit.wellFloor,
        glassSolid: Lit.surface, chromeTint16: Lit.page, glassTint26: clear,
        cardFill: Lit.surface, inputFill: Lit.surface,
        glassHighlight: noGradient, borderGlass: noGradient, borderSpectrum: noGradient, borderSafe: noGradient,
        borderCtaSheen: noGradient, borderChromeTop: noGradient,
        cardShadow: nil,
        hairline: Lit.engraveDark, divider: Lit.engraveDark, borderInput: Lit.engraveDark, focusRing: Colors.brown50,
        textPrimary: Lit.ink, textSecondary: Lit.inkSecondary, textTertiary: Lit.inkTertiary,
        textDisabled: Lit.inkTertiary, onAccent: Colors.white100, link: Colors.red50,
        brandRed: Colors.red50, redText: Colors.red50, cyan: Colors.red50, steel: Lit.inkSecondary,
        magenta: Colors.polkaswap50, polkaswapBrand: Colors.polkaswap50, polkaswapText: Colors.polkaswap50,
        ctaPrimary: NeonGradient([(0, c(0xF0343C)), (1, c(0xC9102A))]),
        ctaSwap: NeonGradient([(0, c(0xFF2B84)), (1, c(0xCC0052))]),
        ctaSafe: NeonGradient([(0, c(0x2BB68B)), (1, c(0x12835F))]),
        ctaDisabled: Lit.wellFloor,
        success: c(0x12835F), successContainer: Colors.green5, warning: Colors.yellow30,
        warningContainer: Colors.yellow5, warningFill: Colors.yellow30, onWarningFill: Colors.brown90,
        error: Colors.red60, errorContainer: Colors.red5, info: Colors.blue40, infoContainer: Colors.blue5,
        redContainer: Colors.red5,
        tertiaryContainer: Lit.wellFloor, polkaswapContainer: Colors.polkaswap5,
        glowPrimary: noGlow, glowSwap: noGlow, glowFocus: noGlow, glowDot: noGlow, glowTab: noGlow,
        glowSafe: noGlow, glowSuccess: noGlow,
        heroTextGlow: nil,
        neuBg: Lit.page, neuFacePressed: Lit.wellFloor,
        neuFace: NeonGradient([(0, Lit.plateLit), (1, Lit.plateDeep)]),
        neuRim: NeonGradient([(0, c(0xFFFFFF, 0.9)), (1, c(0xFFFFFF, 0))]),
        neuDark: ShadowSpec(color: c(0x6B4A40), alpha: 0.34, blur: 14, offset: CGSize(width: 5, height: 7)),
        neuLight: ShadowSpec(color: c(0xFFFFFF), alpha: 0.95, blur: 10, offset: CGSize(width: -4, height: -5)),
        neuInnerDark: ShadowSpec(color: c(0x6B4A40), alpha: 0.38, blur: 8, offset: CGSize(width: 2.5, height: 3.5)),
        neuInnerLight: ShadowSpec(color: c(0xFFFFFF), alpha: 0.85, blur: 6, offset: CGSize(width: -2, height: -2.5)),
        skeletonBase: Lit.wellFloor, skeletonHighlight: Colors.white100.withAlphaComponent(0.7)
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
