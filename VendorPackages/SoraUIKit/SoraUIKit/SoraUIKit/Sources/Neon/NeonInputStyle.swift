import UIKit

/// Text-field chrome (spec §7.5): an opaque fill, a 1 pt `border.input`
/// border at rest, a 1.5 pt cyan border plus a soft focus glow when focused,
/// and status colours for success and errors. Never glows the text itself.
enum NeonInputStyle {
    static func apply(to view: UIView, state: InputFieldState, isEnabled: Bool, cornerRadius: CGFloat,
                      tokens: NeonTokens = .current, fx: FxPolicy = .current) {
        view.layer.cornerRadius = cornerRadius
        view.layer.cornerCurve = .continuous
        guard isEnabled, state != .disabled else {
            view.backgroundColor = tokens.ctaDisabled
            view.layer.borderColor = tokens.hairline.cgColor
            view.layer.borderWidth = 1
            view.layer.shadowOpacity = 0
            return
        }
        view.backgroundColor = tokens.inputFill
        let width: CGFloat = fx.highContrast ? 2 : 1
        switch state {
        case .default, .disabled:
            view.layer.borderColor = tokens.borderInput.cgColor
            view.layer.borderWidth = width
        case .focused:
            view.layer.borderColor = tokens.cyan.cgColor
            view.layer.borderWidth = width + 0.5
        case .success:
            view.layer.borderColor = tokens.success.cgColor
            view.layer.borderWidth = width + 0.5
        case .fail:
            view.layer.borderColor = tokens.error.cgColor
            view.layer.borderWidth = width + 0.5
        }
        // Focus glow: dark theme, full effects only (spec §7.5).
        if state == .focused, tokens.isDark, fx.glows, fx.tier == .full {
            view.layer.applyNeonGlow(tokens.glowFocus,
                                     path: UIBezierPath(roundedRect: view.bounds, cornerRadius: cornerRadius).cgPath)
        } else {
            view.layer.shadowOpacity = 0
        }
    }

    /// Keeps the glow path in step with the field size.
    static func layout(_ view: UIView) {
        guard view.layer.shadowOpacity > 0 else { return }
        view.layer.shadowPath = UIBezierPath(roundedRect: view.bounds, cornerRadius: view.layer.cornerRadius).cgPath
    }
}
