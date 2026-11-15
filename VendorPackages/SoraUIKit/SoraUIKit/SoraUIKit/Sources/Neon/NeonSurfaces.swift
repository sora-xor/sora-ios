import UIKit

/// A raised porcelain plate (`LitPlateLayer`): its shadows on the page, a face turned to the light and a
/// rounded lit edge. Baked and stretched, so it is safe in lists.
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
    public var shape: NeonShape = .rounded(24) { didSet { setNeedsLayout() } }
    public var border: Border = .glass { didSet { apply() } }
    public var fill: Fill = .glass { didSet { apply() } }

    /// The plate behind the content, for its bounce light, sheen and shadow sizes.
    public let plate = LitPlateLayer()
    /// How high the plate stands; by default from its shape.
    public var elevation: CGFloat? { didSet { setNeedsLayout() } }
    private var observers: [NSObjectProtocol] = []

    public override init(frame: CGRect) {
        super.init(frame: frame)
        layer.masksToBounds = false
        layer.insertSublayer(plate, at: 0)
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

    /// Kept for callers that restyle on a theme change: the plate's look follows only its shape.
    public func apply() {
        setNeedsLayout()
    }

    private var plateRadius: CGFloat {
        switch shape {
        case let .rounded(radius): return min(radius, min(bounds.width, bounds.height) / 2)
        case .capsule: return min(bounds.width, bounds.height) / 2
        case let .chamfer(radius, _): return min(radius, min(bounds.width, bounds.height) / 2)
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0 else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        plate.cornerRadiusValue = plateRadius
        if let elevation {
            plate.elevation = elevation
        } else if case .capsule = shape {
            plate.elevation = 8
        } else {
            plate.elevation = bounds.height < 80 ? 9 : 16
        }
        plate.frame = bounds
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
