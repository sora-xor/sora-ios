import UIKit

/// A tactile neumorphic control (spec §4.6): PIN keys, quick-action discs,
/// icon buttons. Depth alone fails WCAG 1.4.11, so every control also shows a
/// contrast element: put a digit, an icon or a label in `contentView`.
///
/// Every shadow has an explicit path. Only opacity and transform animate.
open class NeumorphicControl: UIControl {
    public var shape: NeonShape = .capsule { didSet { setNeedsLayout() } }
    /// Flat variant (biometric and delete keys): no face, no outer shadows.
    public var isFlat: Bool = false { didSet { apply() } }
    public let contentView = UIView()

    private let darkShadow = CALayer()
    private let lightShadow = CALayer()
    private let face = CAGradientLayer()
    private let rim = GradientBorderLayer()
    private let innerDark = CAShapeLayer()
    private let innerLight = CAShapeLayer()
    private let ring = CAShapeLayer()
    private var observers: [NSObjectProtocol] = []

    public override init(frame: CGRect) {
        super.init(frame: frame)
        [darkShadow, lightShadow].forEach {
            $0.backgroundColor = UIColor.clear.cgColor
            layer.addSublayer($0)
        }
        face.startPoint = .zero
        face.endPoint = CGPoint(x: 1, y: 1)
        layer.addSublayer(face)
        layer.addSublayer(rim)
        [innerDark, innerLight].forEach {
            $0.fillRule = .evenOdd
            $0.fillColor = UIColor.black.cgColor
            $0.opacity = 0
            $0.mask = CAShapeLayer()
            layer.addSublayer($0)
        }
        ring.fillColor = nil
        ring.lineWidth = 1.5
        ring.opacity = 0
        layer.addSublayer(ring)
        contentView.isUserInteractionEnabled = false
        contentView.backgroundColor = .clear
        addSubview(contentView)
        apply()
        SoramitsuUI.updates.addObserver(self)
        observers.append(NotificationCenter.default.addObserver(forName: .neonFxChanged, object: nil, queue: .main) {
            [weak self] _ in self?.apply()
        })
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    open func apply() {
        let tokens = NeonTokens.current
        let rich = FxPolicy.current.tier != .minimal && !isFlat
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        configureShadow(darkShadow, tokens.neuDark, visible: rich)
        configureShadow(lightShadow, tokens.neuLight, visible: rich)
        face.isHidden = isFlat
        if FxPolicy.current.tier == .minimal {
            face.colors = [tokens.surface.cgColor, tokens.surface.cgColor]
            rim.apply(border: NeonGradient([(0, tokens.hairline), (1, tokens.hairline)]), lineWidth: 1)
        } else {
            face.colors = tokens.neuFace.cgColors
            face.locations = tokens.neuFace.nsLocations
            rim.apply(border: isFlat ? nil : tokens.neuRim, lineWidth: 1)
        }
        configureInner(innerDark, tokens.neuInnerDark)
        configureInner(innerLight, tokens.neuInnerLight)
        innerDark.isHidden = !rich
        innerLight.isHidden = !rich
        ring.strokeColor = tokens.cyan.withAlphaComponent(tokens.isDark ? 0.8 : 1).cgColor
        CATransaction.commit()
        setNeedsLayout()
    }

    private func configureShadow(_ target: CALayer, _ spec: ShadowSpec, visible: Bool) {
        target.shadowColor = spec.color.cgColor
        target.shadowOpacity = visible ? spec.alpha : 0
        target.shadowRadius = spec.blur / 2
        target.shadowOffset = spec.offset
    }

    private func configureInner(_ target: CAShapeLayer, _ spec: ShadowSpec) {
        target.shadowColor = spec.color.cgColor
        target.shadowOpacity = spec.alpha
        target.shadowRadius = spec.blur / 2
        target.shadowOffset = spec.offset
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let path = shape.path(in: bounds)
        for target in [darkShadow, lightShadow] {
            target.frame = bounds
            target.shadowPath = path.cgPath
        }
        face.frame = bounds
        face.cornerCurve = .continuous
        switch shape {
        case let .rounded(radius):
            face.mask = nil
            face.masksToBounds = true
            face.cornerRadius = min(radius, min(bounds.width, bounds.height) / 2)
        case .capsule:
            face.mask = nil
            face.masksToBounds = true
            face.cornerRadius = min(bounds.width, bounds.height) / 2
        case .chamfer:
            let faceMask = (face.mask as? CAShapeLayer) ?? CAShapeLayer()
            faceMask.path = path.cgPath
            face.mask = faceMask
        }
        rim.frame = bounds
        rim.shape = shape
        rim.contentsScale = traitCollection.displayScale
        for target in [innerDark, innerLight] {
            target.frame = bounds
            let outer = UIBezierPath(rect: bounds.insetBy(dx: -24, dy: -24))
            outer.append(path)
            outer.usesEvenOddFillRule = true
            target.path = outer.cgPath
            (target.mask as? CAShapeLayer)?.path = path.cgPath
        }
        ring.frame = bounds
        ring.path = shape.path(in: bounds.insetBy(dx: 0.75, dy: 0.75)).cgPath
        CATransaction.commit()
        contentView.frame = bounds
    }

    open override var isHighlighted: Bool {
        didSet {
            guard isHighlighted != oldValue else { return }
            setPressed(isHighlighted)
        }
    }

    open override var isEnabled: Bool {
        didSet { alpha = isEnabled ? 1 : 0.5 }
    }

    private func setPressed(_ pressed: Bool) {
        let tokens = NeonTokens.current
        let rich = FxPolicy.current.tier != .minimal && !isFlat
        let duration = pressed ? NeonMotion.press : NeonMotion.fast
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        darkShadow.shadowOpacity = rich && !pressed ? tokens.neuDark.alpha : 0
        lightShadow.shadowOpacity = rich && !pressed ? tokens.neuLight.alpha : 0
        innerDark.opacity = rich && pressed ? 1 : 0
        innerLight.opacity = rich && pressed ? 1 : 0
        ring.opacity = pressed ? 1 : 0
        if !isFlat {
            face.colors = pressed
                ? [tokens.neuFacePressed.cgColor, tokens.neuFacePressed.cgColor]
                : (FxPolicy.current.tier == .minimal ? [tokens.surface.cgColor, tokens.surface.cgColor]
                                                     : tokens.neuFace.cgColors)
        }
        CATransaction.commit()
        let scale: CGFloat = pressed && !FxPolicy.current.reduceMotion ? 0.96 : 1
        UIViewPropertyAnimator(duration: duration, dampingRatio: 0.8) {
            self.transform = CGAffineTransform(scaleX: scale, y: scale)
        }.startAnimation()
    }
}

extension NeumorphicControl: SoramitsuObserver {
    public func styleDidChange(options: UpdateOptions) {
        if options.contains(.palette) { apply() }
    }
}
