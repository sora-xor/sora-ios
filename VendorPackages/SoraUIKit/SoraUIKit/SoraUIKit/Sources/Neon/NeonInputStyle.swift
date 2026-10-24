import UIKit

/// Text-field chrome (spec §7.5): an opaque fill, a 1 pt `border.input`
/// border at rest, a 1.5 pt cyan border plus a soft focus glow when focused,
/// and status colours for success and errors. Never glows the text itself.
///
/// The glow is a shadow on the styled view's layer. That view must be a
/// plain view with no other writer of its layer, and neither it nor the
/// field around it may clip.
enum NeonInputStyle {
    /// - Parameter focusGlow: false for fields that hold a secret (recovery
    ///   phrase, seed, password): secrets never glow (spec §1.8). They keep
    ///   the focused border.
    static func apply(to view: UIView, state: InputFieldState, isEnabled: Bool, cornerRadius: CGFloat,
                      focusGlow: Bool = true, tokens: NeonTokens = .current, fx: FxPolicy = .current) {
        view.layer.cornerRadius = cornerRadius
        view.layer.cornerCurve = .continuous
        guard isEnabled, state != .disabled else {
            view.backgroundColor = tokens.ctaDisabled
            view.layer.borderColor = tokens.hairline.cgColor
            view.layer.borderWidth = 1
            clearGlow(view)
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
        guard focusGlow, state == .focused, tokens.isDark, fx.glows, fx.tier == .full else {
            clearGlow(view)
            return
        }
        view.layer.applyNeonGlow(tokens.glowFocus, path: nil)
        view.layer.setValue(tokens.glowFocus.rest, forKey: glowAlphaKey)
        layout(view)
    }

    private static func clearGlow(_ view: UIView) {
        view.layer.shadowOpacity = 0
        view.layer.shadowPath = nil
        view.layer.setValue(nil, forKey: glowAlphaKey)
    }

    /// Keeps the glow in step with the field's size and surroundings. Call
    /// from the field's `layoutSubviews`.
    ///
    /// The glow is drawn whole or not at all. An ancestor that clips closer
    /// than the glow reaches would cut it into a strip or leave only its
    /// corners, and a glow is never drawn inside a table or collection cell
    /// (spec §4.5). The focused border is always there.
    static func layout(_ view: UIView) {
        guard let alpha = view.layer.value(forKey: glowAlphaKey) as? Float else { return }
        let reach = glowReach(of: view.layer)
        guard hasRoom(for: view, reach: reach) else {
            view.layer.shadowOpacity = 0
            view.layer.shadowPath = nil
            return
        }
        view.layer.shadowOpacity = alpha
        // An explicit path the size of the field (spec §10.3).
        view.layer.shadowPath = UIBezierPath(roundedRect: view.bounds, cornerRadius: view.layer.cornerRadius).cgPath
    }

    /// The rest alpha of the glow a focused field wants, kept on its layer
    /// while it is focused, whether or not the glow has room right now.
    private static let glowAlphaKey = "soraNeonFocusGlowAlpha"

    /// How far the glow is visible outside the field: the design blur (twice
    /// the layer's shadow radius) plus its offset.
    static func glowReach(of layer: CALayer) -> CGFloat {
        layer.shadowRadius * 2 + max(abs(layer.shadowOffset.width), abs(layer.shadowOffset.height))
    }

    /// True when no ancestor would cut a glow that reaches `reach` points
    /// outside `view`, and `view` is not in a list cell.
    static func hasRoom(for view: UIView, reach: CGFloat) -> Bool {
        let needed = view.bounds.insetBy(dx: -reach, dy: -reach)
        var ancestor = view.superview
        while let current = ancestor {
            if current is UITableViewCell || current is UICollectionViewCell { return false }
            if current.clipsToBounds {
                let rect = view.convert(needed, to: current)
                let visible = current.bounds.insetBy(dx: -0.5, dy: -0.5)
                if current is UIScrollView {
                    // Content moves under the top and bottom edges of a
                    // scroll view anyway; only its sides are fixed.
                    if rect.minX < visible.minX || rect.maxX > visible.maxX { return false }
                } else if !visible.contains(rect) {
                    return false
                }
            }
            ancestor = current.superview
        }
        return true
    }
}
