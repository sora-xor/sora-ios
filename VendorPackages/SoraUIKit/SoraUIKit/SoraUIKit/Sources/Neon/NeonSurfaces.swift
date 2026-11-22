import UIKit

/// A sheet of frosted glass, or a soft raised pad when it is small (`LitPlateLayer`). Baked and stretched, so
/// it is safe in lists. `blursBackdrop` blurs what passes behind it: for the few sheets something really does.
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

    /// The sheet behind the content, for its bounce light, sheen and shadow sizes.
    public let plate = LitPlateLayer()
    /// Blurs what is behind the sheet. Costs a live pass, so only where something moves behind the glass.
    public var blursBackdrop = false { didSet { if oldValue != blursBackdrop { applyBackdrop() } } }
    private var backdrop: UIVisualEffectView?
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

    /// Kept for callers that restyle on a theme change: the sheet's look follows only its shape.
    public func apply() {
        setNeedsLayout()
    }

    private func applyBackdrop() {
        if blursBackdrop, backdrop == nil {
            let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialLight))
            blur.isUserInteractionEnabled = false
            blur.clipsToBounds = true
            // Under the sheet's milk and edge, over nothing of its own.
            blur.layer.zPosition = -2
            plate.zPosition = -1
            insertSubview(blur, at: 0)
            backdrop = blur
        } else if !blursBackdrop {
            backdrop?.removeFromSuperview()
            backdrop = nil
            plate.zPosition = 0
        }
        plate.isOverBackdrop = blursBackdrop
        setNeedsLayout()
    }

    private var plateRadius: CGFloat {
        switch shape {
        case let .rounded(radius): return min(min(radius, Lit.sheetRadius), min(bounds.width, bounds.height) / 2)
        case .capsule: return min(bounds.width, bounds.height) / 2
        case let .chamfer(radius, _): return min(min(radius, Lit.sheetRadius), min(bounds.width, bounds.height) / 2)
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
        backdrop?.frame = bounds
        backdrop?.layer.cornerRadius = plateRadius
        CATransaction.commit()
        LitParallax.attach(to: self, depth: bounds.height < 80 ? 2 : 4)
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

    /// The classic design draws no glow at any tier, so the host stays dark;
    /// the spec is kept for callers that read it back.
    public func configure(_ glow: GlowSpec?, fx: FxPolicy = .current) {
        spec = glow
        layer.shadowOpacity = 0
        ring?.removeFromSuperlayer()
        ring = nil
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

    public func stopPulse() {
        layer.removeAnimation(forKey: "neon.pulse")
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { stopPulse() }
    }
}
