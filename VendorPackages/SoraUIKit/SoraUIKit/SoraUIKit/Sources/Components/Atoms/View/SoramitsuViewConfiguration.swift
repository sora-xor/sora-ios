import UIKit

public class SoramitsuViewConfiguration<Type: Element & UIView>: SoramitsuConfiguration<Type> {
    
    public var backgroundColor: SoramitsuColor = .custom(uiColor: .clear) {
        didSet {
            let supportedPalette = supportsPaletteMode ? style.palette : LightPalette()
            let color = supportedPalette.color(backgroundColor)
            owner?.backgroundColor = color
            updateSurface()
            updateShadowPath()
        }
    }

    /// True while the stored background is re-applied (theme change, owner
    /// set), as opposed to a caller assigning a new one.
    private(set) var isReapplyingBackground = false

    func reapplyBackground() {
        isReapplyingBackground = true
        retrigger(self, \.backgroundColor)
        isReapplyingBackground = false
    }

    /// Like `isReapplyingBackground`, for the tint colour.
    private(set) var isReapplyingTint = false

    func reapplyTint() {
        isReapplyingTint = true
        retrigger(self, \.tintColor)
        isReapplyingTint = false
    }

    /// How a surface is drawn (SORA Neon).
    /// `.automatic` gives the legacy card idiom (`.bgSurface`, a card radius,
    /// all corners rounded) the Neon card treatment (opaque surface,
    /// hairline, theme shadows) and draws everything else as is.
    public var material: SoramitsuSurfaceMaterial = .automatic {
        didSet {
            updateSurface()
        }
    }
    
    public var tintColor: SoramitsuColor = .accentPrimary {
        didSet {
            let supportedPalette = supportsPaletteMode ? style.palette : LightPalette()
            owner?.tintColor = supportedPalette.color(tintColor)
        }
    }
    
    public var cornerRadius: Radius = .zero {
        didSet {
            let radius = style.radii.radius(cornerRadius, size: owner?.frame.size ?? .zero)
            owner?.layer.cornerRadius = radius
            owner?.layer.cornerCurve = .continuous
            overlay.viewCornerRadiusDidChange()
            updateSurface()
        }
    }
    
    public var cornerMask: CornerMask = .all {
        didSet {
            owner?.layer.maskedCorners = cornerMask.maskValue
            updateSurface()
        }
    }
    
    public var borderWidth: CGFloat = 0 {
        didSet {
            owner?.layer.borderWidth = borderWidth
            applyCardHairline()
        }
    }
    
    public var borderColor: SoramitsuColor? {
        didSet {
            guard let color = borderColor else {
                owner?.layer.borderColor = nil
                applyCardHairline()
                return
            }
            let supportedPalette = supportsPaletteMode ? style.palette : LightPalette()
            owner?.layer.borderColor = supportedPalette.color(color).cgColor
        }
    }

    
    public var clipsToBounds: Bool = true {
        didSet {
            owner?.clipsToBounds = clipsToBounds
        }
    }
    
    public var useAutoresizingMask: Bool = false {
        didSet {
            owner?.translatesAutoresizingMaskIntoConstraints = useAutoresizingMask
        }
    }
    
    public private(set) lazy var loadingPlaceholder = SoramitsuLoadingPlaceholderDecorator(style: style)
    
    public var alpha: CGFloat = 1 {
        didSet {
            owner?.alpha = alpha
        }
    }
    
    public var isHidden: Bool = false {
        didSet {
            owner?.isHidden = isHidden
        }
    }
    
    public var shadow: Shadow = .none {
        didSet {
            guard owner != nil else { return }
            applyShadowStyle()
            clipsToBounds = shadow == .none
        }
    }
    
    public var transform: CGAffineTransform = .identity {
        didSet {
            owner?.transform = transform
        }
    }
    
    public var isExclusiveTouch: Bool = false {
        didSet {
            owner?.isExclusiveTouch = isExclusiveTouch
        }
    }
    
    public var isUserInteractionEnabled: Bool = true {
        didSet {
            owner?.isUserInteractionEnabled = isUserInteractionEnabled
        }
    }
    
    public var supportsPaletteMode: Bool = true {
        didSet {
            reapplyBackground()
            reapplyTint()
            retrigger(self, \.borderColor)
            applyShadowStyle()
        }
    }
    
    private(set) lazy var overlay = SoramitsuOverlayDecorator(style: style)

    /// Sheen and gradient hairline of a glass card. Created only for cards.
    private var surfaceLayer: GradientBorderLayer?
    private var surfaceSize: CGSize = .zero
    private var surfaceStyleKey: String?
    
    private lazy var observer: ViewObserver = {
        let observer = ViewObserver()
        observer.viewSizeDidChangeHandler = { [weak self] in
            self?.ownerSizeDidChange()
        }
        return observer
    }()
    
    override func configureOwner() {
        guard let owner = owner else { return }
        super.configureOwner()
        
        loadingPlaceholder.view = owner
        overlay.view = owner
        
        reapplyBackground()
        reapplyTint()
        retrigger(self, \.cornerRadius)
        retrigger(self, \.borderWidth)
        retrigger(self, \.borderColor)
        retrigger(self, \.clipsToBounds)
        retrigger(self, \.useAutoresizingMask)
        retrigger(self, \.isExclusiveTouch)
        
        observer.observe(owner)
    }
    
    private func ownerSizeDidChange() {
        retrigger(self, \.cornerRadius)
        updateShadowPath()
        layoutSurface()
    }
    
    public override func styleDidChange(options: UpdateOptions) {
        super.styleDidChange(options: options)
        
        if options.contains(.palette) {
            reapplyBackground()
            reapplyTint()
            retrigger(self, \.borderColor)
            // Re-colour the shadow only. Re-assigning `shadow` would also reset
            // `clipsToBounds`, clipping content a caller let overflow (for
            // example the Welcome logo) on every theme change.
            applyShadowStyle()
        } else if options.contains(.effects) {
            // Glass, hairline width and card shadows follow the effect policy.
            updateSurface()
            applyShadowStyle()
        }
    }

    // MARK: - SORA Neon surfaces

    private var tokens: NeonTokens {
        supportsPaletteMode ? NeonTokens.current : .light
    }

    /// True when this view is drawn as a card (legacy idiom or `.glass`).
    var resolvesToCard: Bool {
        guard let owner, !(owner is UIControl), !(owner is UIScrollView) else { return false }
        switch material {
        case .solid: return false
        case .glass: return true
        case .automatic: return isLegacyCard
        }
    }

    /// The legacy card idiom: `.bgSurface`, a card radius, all corners.
    private var isLegacyCard: Bool {
        guard let owner, case .bgSurface = backgroundColor,
              owner.layer.maskedCorners == CornerMask.all.maskValue else { return false }
        switch cornerRadius {
        case .max, .extraLarge, .large: return true
        case let .custom(radius): return radius >= 20
        default: return false
        }
    }

    /// True while this configuration draws the card hairline in the
    /// layer border (only when the caller set no border of its own).
    private var drawsCardHairline = false

    private func updateSurface() {
        guard let owner else { return }
        let supportedPalette = supportsPaletteMode ? style.palette : LightPalette()
        guard resolvesToCard else {
            if surfaceLayer != nil {
                surfaceLayer?.removeFromSuperlayer()
                surfaceLayer = nil
                owner.backgroundColor = supportedPalette.color(backgroundColor)
            }
            if surfaceStyleKey != nil {
                surfaceStyleKey = nil
                applyShadowStyle()
            }
            applyCardHairline()
            return
        }
        let tokens = self.tokens
        let fx = FxPolicy.current
        let key = "\(tokens.isDark)|\(fx.opaqueGlass)|\(fx.highContrast)|\(material == .glass)"
        if material == .glass {
            // Translucent card glass (spec §4.3.1): fill, sheen and a
            // gradient hairline drawn under the content. Opt-in only.
            owner.backgroundColor = fx.opaqueGlass ? tokens.glassSolid : tokens.glassFill
            let layer: GradientBorderLayer
            if let existing = surfaceLayer {
                layer = existing
            } else {
                layer = GradientBorderLayer()
                owner.layer.insertSublayer(layer, at: 0)
                surfaceLayer = layer
                surfaceSize = .zero
                surfaceStyleKey = nil
            }
            // Redraw only when the theme or the effect policy changed, not
            // on every size or radius update.
            if key != surfaceStyleKey {
                let border = fx.opaqueGlass ? NeonGradient([(0, tokens.hairline), (1, tokens.hairline)])
                                            : tokens.borderGlass
                layer.apply(border: border, lineWidth: fx.highContrast ? 2 : 1,
                            sheen: fx.opaqueGlass ? nil : tokens.glassHighlight)
            }
            layoutSurface()
        } else {
            // Legacy cards stay opaque: their inner views are often
            // `.bgSurface` too, and a translucent card would show them as
            // patches. They get the Neon surface colour, a hairline drawn
            // above the content and theme-aware shadows.
            if surfaceLayer != nil {
                surfaceLayer?.removeFromSuperlayer()
                surfaceLayer = nil
            }
            owner.backgroundColor = supportedPalette.color(backgroundColor)
        }
        if key != surfaceStyleKey {
            surfaceStyleKey = key
            applyShadowStyle()
        }
        applyCardHairline()
    }

    /// A 1 pt hairline on cards whose caller set no border. The layer border
    /// is drawn above the content, so inner views never hide it.
    private func applyCardHairline() {
        guard let owner else { return }
        let isCard = resolvesToCard
        owner.layer.setValue(isCard, forKey: Self.cardMarkerKey)
        guard borderWidth == 0, borderColor == nil else {
            drawsCardHairline = false
            return
        }
        // Rows drawn as cards inside a card (grouped settings, menus) get no
        // hairline of their own: one outline per card.
        if isCard, material != .glass, !isNestedInCard(owner) {
            owner.layer.borderWidth = FxPolicy.current.highContrast ? 2 : 1
            owner.layer.borderColor = tokens.hairline.cgColor
            drawsCardHairline = true
        } else if drawsCardHairline {
            owner.layer.borderWidth = 0
            owner.layer.borderColor = nil
            drawsCardHairline = false
        }
    }

    private static var cardMarkerKey: String { "soraNeonCard" }

    private func isNestedInCard(_ view: UIView) -> Bool {
        var ancestor = view.superview
        while let current = ancestor {
            if (current.layer.value(forKey: Self.cardMarkerKey) as? Bool) == true {
                return true
            }
            ancestor = current.superview
        }
        return false
    }

    private func layoutSurface() {
        guard let owner, let surfaceLayer else { return }
        let shape = NeonShape.rounded(owner.layer.cornerRadius)
        guard owner.bounds.size != surfaceSize || surfaceLayer.shape != shape else { return }
        surfaceSize = owner.bounds.size
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        surfaceLayer.frame = owner.bounds
        surfaceLayer.shape = shape
        surfaceLayer.contentsScale = owner.traitCollection.displayScale > 0 ? owner.traitCollection.displayScale : 2
        surfaceLayer.setNeedsDisplay()
        CATransaction.commit()
    }

    private func applyShadowStyle() {
        guard let owner else { return }
        let dark = (supportsPaletteMode ? SoramitsuUI.shared.theme : .light) == .dark
        if shadow == .none {
            owner.layer.shadowOpacity = 0
            owner.layer.shadowPath = nil
            return
        }
        if resolvesToCard {
            // Spec §4.3.1: dark glass cards have no shadow; light ones a soft ink shadow.
            let spec = dark || FxPolicy.current.tier == .minimal ? nil : tokens.cardShadow
            owner.layer.applyNeonShadow(spec, path: nil)
        } else {
            let data = style.shady.shadow(shadow, dark: dark)
            owner.layer.shadowColor = data.color
            owner.layer.shadowOffset = data.offset
            owner.layer.shadowRadius = data.radius
            owner.layer.shadowOpacity = data.opacity
        }
        updateShadowPath()
    }

    /// An explicit shadow path avoids an offscreen pass per frame (spec
    /// §10.3). A view with a clear fill gets an empty path, so it casts no
    /// shadow: a content-derived shadow would shadow its text and icons and
    /// cost an offscreen pass every frame. The path is rebuilt when the fill
    /// or the size changes.
    private func updateShadowPath() {
        guard let owner else { return }
        guard shadow != .none, owner.layer.shadowOpacity > 0 else {
            owner.layer.shadowPath = nil
            return
        }
        guard let fill = owner.backgroundColor, fill.cgColor.alpha > 0 else {
            owner.layer.shadowPath = CGMutablePath()
            return
        }
        let radius = owner.layer.cornerRadius
        let mask = owner.layer.maskedCorners
        let path: UIBezierPath
        if mask == CornerMask.all.maskValue || radius == 0 {
            path = UIBezierPath(roundedRect: owner.bounds, cornerRadius: radius)
        } else {
            var corners: UIRectCorner = []
            if mask.contains(.layerMinXMinYCorner) { corners.insert(.topLeft) }
            if mask.contains(.layerMaxXMinYCorner) { corners.insert(.topRight) }
            if mask.contains(.layerMinXMaxYCorner) { corners.insert(.bottomLeft) }
            if mask.contains(.layerMaxXMaxYCorner) { corners.insert(.bottomRight) }
            path = UIBezierPath(roundedRect: owner.bounds, byRoundingCorners: corners,
                                cornerRadii: CGSize(width: radius, height: radius))
        }
        owner.layer.shadowPath = path.cgPath
    }
    
    /// Анимированное изменений лэйаута
    func animateLayoutChanges() {
        UIView.animate(withDuration: CATransaction.animationDuration(),
                       delay: .zero,
                       options: [.allowUserInteraction],
                       animations: {
            self.owner?.layoutIfNeeded()
        })
    }
}

/// How a Soramitsu view's surface is drawn (SORA Neon).
public enum SoramitsuSurfaceMaterial {
    /// The Neon card treatment for the legacy card idiom, solid otherwise.
    case automatic
    /// The palette colour as is.
    case solid
    /// Card glass: translucent fill, sheen and gradient hairline (no blur).
    case glass
}
