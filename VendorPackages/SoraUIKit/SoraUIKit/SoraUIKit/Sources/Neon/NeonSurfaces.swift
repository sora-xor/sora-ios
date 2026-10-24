import UIKit

/// Card glass (spec §4.3.1): a translucent fill, a top sheen and a gradient
/// hairline. No runtime blur, so it is safe in lists. Under Reduce
/// Transparency, Increase Contrast or "Reduce effects" it becomes the opaque
/// `glassSolid` with a hairline.
///
/// Put content in `contentView`.
public final class GlassView: UIView {
    public enum Border {
        case glass
        case spectrum
        case safe
        case none
    }

    public enum Fill {
        /// `glass.fill`: the spec's translucent card glass.
        case glass
        /// `glass.fillStrong`: hero inputs, sheet headers.
        case strong
        /// `glass.solid`: opaque. Use for secrets and review sheets.
        case solid
    }

    public let contentView = UIView()
    public var shape: NeonShape = .rounded(24) { didSet { setNeedsLayout(); surface.shape = shape } }
    public var border: Border = .glass { didSet { apply() } }
    public var fill: Fill = .glass { didSet { apply() } }

    private let surface = GradientBorderLayer()
    private var observers: [NSObjectProtocol] = []

    public override init(frame: CGRect) {
        super.init(frame: frame)
        layer.masksToBounds = false
        layer.insertSublayer(surface, at: 0)
        contentView.backgroundColor = .clear
        contentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        apply()
        SoramitsuUI.updates.addObserver(self)
        observers.append(NotificationCenter.default.addObserver(forName: .neonFxChanged, object: nil, queue: .main) {
            [weak self] _ in self?.apply()
        })
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    public func apply() {
        let tokens = NeonTokens.current
        let fx = FxPolicy.current
        let opaque = fill == .solid || fx.opaqueGlass
        let fillColor: UIColor
        switch fill {
        case .glass: fillColor = opaque ? tokens.glassSolid : tokens.glassFill
        case .strong: fillColor = opaque ? tokens.glassSolid : tokens.glassFillStrong
        case .solid: fillColor = tokens.glassSolid
        }
        let gradient: NeonGradient?
        switch border {
        case .glass: gradient = tokens.borderGlass
        case .spectrum: gradient = tokens.borderSpectrum
        case .safe: gradient = tokens.borderSafe
        case .none: gradient = nil
        }
        let width: CGFloat = fx.highContrast ? 2 : (border == .spectrum ? 1.5 : 1)
        surface.fill = fillColor
        surface.apply(border: gradient, lineWidth: width, sheen: opaque ? nil : tokens.glassHighlight)
        layer.applyNeonShadow(fx.tier == .minimal ? nil : tokens.cardShadow,
                              path: shape.path(in: bounds).cgPath)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        surface.frame = bounds
        surface.contentsScale = traitCollection.displayScale
        if layer.shadowOpacity > 0 {
            layer.shadowPath = shape.path(in: bounds).cgPath
        }
        CATransaction.commit()
    }
}

extension GlassView: SoramitsuObserver {
    public func styleDidChange(options: UpdateOptions) {
        if options.contains(.palette) { apply() }
    }
}

/// A glow placed directly behind a control, the same size (spec §4.5).
/// The control's own layer is not touched. Only `shadowOpacity` animates.
public final class GlowHostView: UIView {
    public var shape: NeonShape = .capsule { didSet { setNeedsLayout() } }
    private var spec: GlowSpec?
    /// MINIMAL tier: a ring just outside the control instead of the glow.
    private var ring: NeonRingLayer?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        backgroundColor = .clear
        layer.masksToBounds = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func configure(_ glow: GlowSpec?, fx: FxPolicy = .current) {
        spec = glow
        guard let glow, fx.glows else {
            layer.shadowOpacity = 0
            ring?.removeFromSuperlayer()
            ring = nil
            return
        }
        if fx.tier == .minimal {
            // Ring fallback: no blur, still a clear signal. Drawn outside the
            // control, which sits on top of this view with the same frame.
            layer.shadowOpacity = 0
            let ring = self.ring ?? NeonRingLayer()
            if self.ring == nil {
                layer.addSublayer(ring)
                self.ring = ring
            }
            ring.apply(glow)
            setNeedsLayout()
            return
        }
        ring?.removeFromSuperlayer()
        ring = nil
        layer.applyNeonGlow(glow, path: shape.path(in: bounds).cgPath)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        let radius: CGFloat = {
            switch shape {
            case let .rounded(radius): return radius
            case .capsule: return min(bounds.width, bounds.height) / 2
            case let .chamfer(radius, _): return radius
            }
        }()
        layer.cornerRadius = radius
        layer.shadowPath = shape.path(in: bounds).cgPath
        ring?.layout(around: bounds, cornerRadius: radius)
    }

    /// Finite pulse for the whitelisted CTAs only (spec §4.7.2): 3 cycles.
    public func startPulse() {
        guard let spec, FxPolicy.current.pulses, layer.shadowOpacity > 0 else { return }
        let animation = CABasicAnimation(keyPath: "shadowOpacity")
        animation.fromValue = spec.rest
        animation.toValue = spec.peak
        animation.duration = 1.2
        animation.autoreverses = true
        animation.repeatCount = 3
        animation.timingFunction = NeonMotion.sine
        animation.beginTime = CACurrentMediaTime() + 0.6
        layer.add(animation, forKey: "neon.pulse")
    }

    public func stopPulse() {
        layer.removeAnimation(forKey: "neon.pulse")
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { stopPulse() }
    }
}
