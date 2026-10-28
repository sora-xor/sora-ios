import UIKit

/// Chrome: bars, sheets, toasts (spec §4.3.3, §4.3.4).
///
/// Real blur is used only here, never in list cells. On iOS 26+ (built with
/// the iOS 26 SDK or later) the system bars are Liquid Glass: we tint them and
/// never paint over them.
public enum NeonChrome {
    /// True when system bars render Liquid Glass.
    public static var usesLiquidGlass: Bool {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            return true
        }
        #endif
        return false
    }

    /// A chrome background: `UIGlassEffect` on iOS 26+, an ultra-thin
    /// material with the chrome tint below, or an opaque fill when glass is
    /// reduced. Never put one in a table or collection cell.
    public static func makeBackgroundView(tokens: NeonTokens = .current, fx: FxPolicy = .current) -> UIView {
        if fx.opaqueGlass {
            let view = UIView()
            view.backgroundColor = tokens.isDark ? tokens.layer1 : tokens.surface
            view.isUserInteractionEnabled = false
            return view
        }
        let effectView = UIVisualEffectView(effect: effect(tokens: tokens))
        effectView.isUserInteractionEnabled = false
        if !usesLiquidGlass {
            // Never set alpha < 1 on an effect view; tint with a subview.
            let tint = UIView(frame: effectView.contentView.bounds)
            tint.backgroundColor = tokens.chromeTint16
            tint.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            effectView.contentView.addSubview(tint)
        }
        return effectView
    }

    /// The material for custom chrome.
    public static func effect(tokens: NeonTokens) -> UIVisualEffect {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            let glass = UIGlassEffect(style: .regular)
            glass.tintColor = tokens.glassTint26
            return glass
        }
        #endif
        return UIBlurEffect(style: tokens.isDark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight)
    }

    /// Tab bar appearance. iOS 26+: the system default background only.
    public static func tabBarAppearance(tokens: NeonTokens = .current, fx: FxPolicy = .current) -> UITabBarAppearance {
        let appearance = UITabBarAppearance()
        if usesLiquidGlass {
            appearance.configureWithDefaultBackground()
        } else if fx.opaqueGlass {
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = tokens.isDark ? tokens.layer1 : tokens.surface
            appearance.shadowColor = .clear
        } else {
            // The custom `TabBar` draws its own notched chrome below the items.
            appearance.configureWithTransparentBackground()
            appearance.shadowColor = .clear
        }
        let normalFont = FontType.textXS.font
        let selectedFont = FontType.textBoldXS.font
        for item in [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance,
                     appearance.compactInlineLayoutAppearance] {
            item.normal.iconColor = tokens.textSecondary
            item.normal.titleTextAttributes = [.foregroundColor: tokens.textSecondary, .font: normalFont]
            item.selected.iconColor = tokens.textPrimary
            item.selected.titleTextAttributes = [.foregroundColor: tokens.textPrimary, .font: selectedFont]
        }
        return appearance
    }

    /// Colour of text bar buttons ("Add node", "Edit", "Skip"). Bars carry
    /// no red text. On dark bars cyan is 7.35:1 against the worst-case bar;
    /// on light bars only `text.primary` and `text.secondary` reach 4.5:1,
    /// so the title is `text.primary` there (spec §2.6-6, §3.2). Icons keep
    /// the bar tint (cyan), which passes the 3:1 they need.
    public static func barButtonTitleColor(tokens: NeonTokens = .current) -> UIColor {
        tokens.isDark ? tokens.cyan : tokens.textPrimary
    }

    /// Navigation bar appearances: (standard, scroll edge).
    /// Back-button titles are hidden (the app shows the arrow only).
    public static func navigationBarAppearances(tokens: NeonTokens = .current,
                                                fx: FxPolicy = .current) -> (UINavigationBarAppearance,
                                                                             UINavigationBarAppearance) {
        let titleFont = FontType.headline2.font
        let largeTitleFont = FontType.headline1.font
        func configure(_ appearance: UINavigationBarAppearance) {
            appearance.titleTextAttributes = [.foregroundColor: tokens.textPrimary, .font: titleFont]
            appearance.largeTitleTextAttributes = [.foregroundColor: tokens.textPrimary, .font: largeTitleFont]
            // Text bar buttons: one style for every screen, re-applied with
            // the theme. Set before the back button, which stays hidden.
            let buttonFont = FontType.textBoldS.font
            let buttonColor = barButtonTitleColor(tokens: tokens)
            for button in [appearance.buttonAppearance, appearance.doneButtonAppearance] {
                button.normal.titleTextAttributes = [.foregroundColor: buttonColor, .font: buttonFont]
                button.highlighted.titleTextAttributes = [.foregroundColor: buttonColor.withAlphaComponent(0.6),
                                                          .font: buttonFont]
                button.focused.titleTextAttributes = [.foregroundColor: buttonColor, .font: buttonFont]
                button.disabled.titleTextAttributes = [.foregroundColor: tokens.textDisabled, .font: buttonFont]
            }
            let hidden: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.clear]
            appearance.backButtonAppearance.normal.titleTextAttributes = hidden
            appearance.backButtonAppearance.highlighted.titleTextAttributes = hidden
            appearance.backButtonAppearance.focused.titleTextAttributes = hidden
            appearance.backButtonAppearance.disabled.titleTextAttributes = hidden
        }
        let standard = UINavigationBarAppearance()
        let scrollEdge = UINavigationBarAppearance()
        if usesLiquidGlass {
            standard.configureWithDefaultBackground()
            scrollEdge.configureWithTransparentBackground()
        } else {
            scrollEdge.configureWithTransparentBackground()
            if fx.opaqueGlass {
                standard.configureWithOpaqueBackground()
                standard.backgroundColor = tokens.isDark ? tokens.layer1 : tokens.surface
            } else {
                standard.configureWithTransparentBackground()
                standard.backgroundEffect = UIBlurEffect(style: tokens.isDark ? .systemUltraThinMaterialDark
                                                                               : .systemUltraThinMaterialLight)
                standard.backgroundColor = tokens.chromeTint16
            }
            standard.shadowColor = tokens.hairline
        }
        configure(standard)
        configure(scrollEdge)
        return (standard, scrollEdge)
    }
}
