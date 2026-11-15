import UIKit

/// What has become of something sent to the network, drawn as 天円地方: the circle of heaven round the
/// square of earth.
///
/// While it is in flight the circle is open and turning, and the square stands on its corner. When the
/// network has settled it the circle closes and the square comes down flat and is stamped, as a seal is
/// set on a paid bill. If it failed, the circle stays open and still.
public final class SacredSealView: UIView {
    public enum State: Equatable {
        case working
        case settled
        case broken
    }

    public private(set) var state: State = .working
    public var workingColor: UIColor = Lit.inkSecondary { didSet { applyColors() } }
    public var settledColor: UIColor = UIColor(litHex: 0x1E9E6A) { didSet { applyColors() } }
    public var brokenColor: UIColor = Lit.lacquerRed { didSet { applyColors() } }
    public var markColor: UIColor = .white { didSet { applyColors() } }

    private let ring = CAShapeLayer()
    private let square = CAShapeLayer()
    private let mark = CAShapeLayer()
    private let ripple = CAShapeLayer()
    private var builtSide: CGFloat = 0

    /// The share of the circle drawn while it is open.
    static let openShare: CGFloat = 0.82
    private static let turnKey = "sacred.turn"
    private static let breathKey = "sacred.breath"

    public override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        for shape in [ripple, ring, square, mark] {
            shape.fillColor = nil
            shape.lineCap = .round
            shape.lineJoin = .round
            layer.addSublayer(shape)
        }
        ripple.opacity = 0
        NotificationCenter.default.addObserver(self, selector: #selector(refreshLoop),
                                               name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshLoop),
                                               name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    public override var intrinsicContentSize: CGSize { CGSize(width: 24, height: 24) }

    public override func layoutSubviews() {
        super.layoutSubviews()
        let side = min(bounds.width, bounds.height)
        guard side > 0, abs(side - builtSide) > 0.01 else { return }
        builtSide = side
        build()
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        refreshLoop()
    }

    private var lineWidth: CGFloat { max(1.5, builtSide * 0.06) }
    private var radius: CGFloat { max(1, builtSide / 2 - lineWidth / 2 - 0.5) }

    private func build() {
        let middle = CGPoint(x: bounds.midX, y: bounds.midY)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for shape in [ripple, ring, square, mark] {
            shape.bounds = CGRect(x: 0, y: 0, width: builtSide, height: builtSide)
            shape.position = middle
        }
        var toMiddle = CGAffineTransform(translationX: builtSide / 2, y: builtSide / 2)
        ring.path = SacredGeometry.circle(radius: radius).copy(using: &toMiddle)
        ring.lineWidth = lineWidth
        ripple.path = ring.path
        ripple.lineWidth = lineWidth * 0.7
        // The square's corners stop short of the circle, so on its corner it still turns freely inside.
        let half = radius * 0.62 / SacredGeometry.yamato
        let box = CGRect(x: builtSide / 2 - half, y: builtSide / 2 - half, width: half * 2, height: half * 2)
        square.path = UIBezierPath(roundedRect: box, cornerRadius: half * 0.24).cgPath
        square.lineWidth = lineWidth * 0.8
        CATransaction.commit()
        apply(animated: false, from: state)
    }

    private func markPath(for state: State) -> CGPath? {
        let half = radius * 0.62 / SacredGeometry.yamato
        let middle = CGPoint(x: builtSide / 2, y: builtSide / 2)
        let path = CGMutablePath()
        switch state {
        case .working:
            return nil
        case .settled:
            path.move(to: CGPoint(x: middle.x - half * 0.50, y: middle.y + half * 0.02))
            path.addLine(to: CGPoint(x: middle.x - half * 0.12, y: middle.y + half * 0.40))
            path.addLine(to: CGPoint(x: middle.x + half * 0.52, y: middle.y - half * 0.36))
        case .broken:
            let reach = half * 0.34
            path.move(to: CGPoint(x: middle.x - reach, y: middle.y - reach))
            path.addLine(to: CGPoint(x: middle.x + reach, y: middle.y + reach))
            path.move(to: CGPoint(x: middle.x + reach, y: middle.y - reach))
            path.addLine(to: CGPoint(x: middle.x - reach, y: middle.y + reach))
        }
        return path
    }

    private func applyColors() {
        guard builtSide > 0 else { return }
        apply(animated: false, from: state)
    }

    public func setState(_ next: State, animated: Bool) {
        let previous = state
        state = next
        guard builtSide > 0 else { return }
        apply(animated: animated && previous != next && LitMotion.allowed && window != nil, from: previous)
    }

    private func apply(animated: Bool, from previous: State) {
        let colour: UIColor
        switch state {
        case .working: colour = workingColor
        case .settled: colour = settledColor
        case .broken: colour = brokenColor
        }
        let ringFrom = ring.presentation()?.strokeEnd ?? ring.strokeEnd
        let turned = (ring.presentation()?.value(forKeyPath: "transform.rotation.z") as? CGFloat) ?? 0
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ring.strokeColor = colour.cgColor
        ring.strokeEnd = state == .settled ? 1 : Self.openShare
        ripple.strokeColor = colour.cgColor
        square.strokeColor = colour.cgColor
        square.fillColor = state == .settled ? colour.cgColor : nil
        square.transform = state == .settled ? CATransform3DIdentity : CATransform3DMakeRotation(.pi / 4, 0, 0, 1)
        mark.path = markPath(for: state)
        mark.strokeColor = (state == .settled ? markColor : colour).cgColor
        mark.lineWidth = lineWidth * 0.9
        if state != .working {
            // Keep the circle where its turning left it; closed, the place cannot be seen.
            ring.removeAnimation(forKey: Self.turnKey)
            ring.transform = state == .settled ? CATransform3DMakeRotation(turned, 0, 0, 1) : CATransform3DMakeRotation(.pi / 5, 0, 0, 1)
        } else {
            ring.transform = CATransform3DIdentity
        }
        CATransaction.commit()
        refreshLoop()
        guard animated else { return }
        switch state {
        case .settled:
            let close = CABasicAnimation(keyPath: "strokeEnd")
            close.fromValue = ringFrom
            close.toValue = 1
            close.duration = SacredGeometry.beat(1)
            ring.add(close, forKey: "sacred.close")

            let stamp = CASpringAnimation(keyPath: "transform.scale")
            stamp.fromValue = 1.32
            stamp.toValue = 1
            stamp.damping = 13
            stamp.stiffness = 260
            stamp.duration = stamp.settlingDuration
            square.add(stamp, forKey: "sacred.stamp")
            let down = CABasicAnimation(keyPath: "transform.rotation.z")
            down.fromValue = CGFloat.pi / 4
            down.toValue = 0
            down.duration = SacredGeometry.beat(2)
            down.timingFunction = CAMediaTimingFunction(name: .easeOut)
            square.add(down, forKey: "sacred.down")

            let draw = CABasicAnimation(keyPath: "strokeEnd")
            draw.fromValue = 0
            draw.toValue = 1
            draw.duration = SacredGeometry.beat(1)
            draw.beginTime = CACurrentMediaTime() + SacredGeometry.beat(1)
            draw.fillMode = .backwards
            mark.add(draw, forKey: "sacred.draw")

            let widen = CABasicAnimation(keyPath: "transform.scale")
            widen.fromValue = 1
            widen.toValue = SacredGeometry.phi
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0.5
            fade.toValue = 0
            let wave = CAAnimationGroup()
            wave.animations = [widen, fade]
            wave.duration = SacredGeometry.beat(3)
            wave.timingFunction = CAMediaTimingFunction(name: .easeOut)
            ripple.add(wave, forKey: "sacred.wave")
        case .broken:
            let shiver = CAKeyframeAnimation(keyPath: "transform.translation.x")
            shiver.values = [0, -3, 2.4, -1.4, 0.6, 0]
            shiver.duration = SacredGeometry.beat(3)
            shiver.isAdditive = true
            layer.add(shiver, forKey: "sacred.shiver")
        case .working:
            break
        }
    }

    /// The open circle turns once in 1.22 s. With Reduce Motion it stays where it is and breathes instead.
    @objc private func refreshLoop() {
        ring.removeAnimation(forKey: Self.turnKey)
        ring.removeAnimation(forKey: Self.breathKey)
        guard state == .working, window != nil, builtSide > 0 else { return }
        if LitMotion.allowed {
            let turn = CABasicAnimation(keyPath: "transform.rotation.z")
            turn.fromValue = 0
            turn.toValue = 2 * CGFloat.pi
            turn.duration = SacredGeometry.beat(5)
            turn.repeatCount = .infinity
            ring.add(turn, forKey: Self.turnKey)
        } else {
            let breath = CABasicAnimation(keyPath: "opacity")
            breath.fromValue = 1
            breath.toValue = 0.35
            breath.duration = SacredGeometry.beat(4)
            breath.autoreverses = true
            breath.repeatCount = .infinity
            ring.add(breath, forKey: Self.breathKey)
        }
    }
}
