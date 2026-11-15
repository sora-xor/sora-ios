import UIKit

/// Plays the launch flight as line figures (`SacredGateScene`) on the dark launch page: what a phone
/// saving power flies instead of the traced scene (`SacredTenmonView`).
///
/// Every frame is worked out ahead and handed to Core Animation as keyframes of the line paths themselves,
/// so the lines stay sharp at any size and the flight keeps its pace while the main thread is busy
/// starting the wallet. The phase always ends on the clock, whether or not a frame was drawn.
public final class SacredGateView: UIView {
    public enum Phase: Equatable {
        case idle
        case intro
        /// Stopped in front of the inner gate, which turns slowly while the wallet gets ready.
        case holding
        case outro
        case arrived
    }

    public private(set) var phase: Phase = .idle
    /// Where the planet lands. Unset, it lands where a PIN screen shows its emblem.
    public var landing: SacredEmblemLayout.Placement?
    /// The placement the flight is using.
    public private(set) var placement: SacredEmblemLayout.Placement?

    private let haze = CAGradientLayer()
    private let gateLayers: [CAShapeLayer] = SacredGateScene.gates.map { _ in CAShapeLayer() }
    private let lockLayer = CAShapeLayer()
    private let planetGroup = CALayer()
    private let glow = SacredPlanet.glowLayer(planetRadius: 1)
    private let planetLayer = CALayer()
    private var scene: SacredGateScene?
    private var clock = 0

    private static let keyframesPerSecond: Double = 30
    private static let turnKey = "sacred.turn"

    public override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        backgroundColor = SacredInk.night
        clipsToBounds = true

        haze.type = .radial
        haze.startPoint = CGPoint(x: 0.5, y: 0.5)
        haze.endPoint = CGPoint(x: 1, y: 1)
        haze.colors = [UIColor(litHex: 0x5A1420, alpha: 0.55).cgColor, UIColor(litHex: 0x5A1420, alpha: 0).cgColor]
        haze.bounds = CGRect(x: 0, y: 0, width: 660, height: 660)
        haze.opacity = 0
        layer.addSublayer(haze)

        for (index, gate) in SacredGateScene.gates.enumerated() {
            let shape = gateLayers[index]
            shape.fillColor = nil
            shape.strokeColor = (gate.isGold ? SacredInk.nightGold : SacredInk.nightLine).cgColor
            shape.lineJoin = .round
            shape.lineCap = .round
            shape.opacity = 0
            layer.addSublayer(shape)
        }
        lockLayer.fillColor = nil
        lockLayer.strokeColor = SacredInk.nightLine.cgColor
        lockLayer.opacity = 0
        layer.addSublayer(lockLayer)

        planetGroup.opacity = 0
        planetGroup.addSublayer(glow)
        planetGroup.addSublayer(planetLayer)
        layer.addSublayer(planetGroup)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    public override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for shape in gateLayers + [lockLayer] { shape.frame = bounds }
        CATransaction.commit()
    }

    // MARK: Phases

    /// Flies to the stop in front of the inner gate. `completion` runs when the camera has stopped.
    public func playIntro(completion: @escaping () -> Void) {
        guard prepare() else { completion(); return }
        phase = .intro
        play(.intro, duration: SacredGateScene.introDuration) { [weak self] in
            guard let self else { return }
            self.phase = .holding
            self.startTurning()
            completion()
        }
    }

    /// Goes through the inner gate and sets the planet down. `completion` runs on arrival.
    public func playOutro(completion: @escaping () -> Void) {
        guard prepare() else { completion(); return }
        settleTurn()
        phase = .outro
        play(.outro, duration: SacredGateScene.outroDuration) { [weak self] in
            self?.phase = .arrived
            completion()
        }
    }

    /// Stops where the camera waits, with nothing moving. A pending completion is dropped.
    public func rest() {
        clock += 1
        removeMotion()
        guard prepare(), let scene else { return }
        show(scene.frame(.intro, at: 1))
        phase = .holding
    }

    /// The end of the flight with no flight: the planet in its ring, where it lands.
    public func showArrival() {
        clock += 1
        removeMotion()
        guard prepare(), let scene else { return }
        show(scene.frame(.outro, at: 1))
        phase = .arrived
    }

    // MARK: Drawing

    private func prepare() -> Bool {
        layoutIfNeeded()
        guard bounds.width > 0, bounds.height > 0 else { return false }
        if let scene, scene.size == bounds.size { return true }
        let place = landing ?? SacredEmblemLayout.pinPlacement(bounds: bounds, safeArea: safeAreaInsets)
            ?? SacredEmblemLayout.fallback(bounds: bounds, safeArea: safeAreaInsets)
        placement = place
        scene = SacredGateScene(size: bounds.size, landing: place.centre, planetRadius: place.planetRadius,
                                ringRadius: place.ringRadius)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let side = place.planetRadius * 2
        planetGroup.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        planetLayer.frame = planetGroup.bounds
        planetLayer.contents = SacredPlanet.image(diameter: side, scale: UIScreen.main.scale * 1.5).cgImage
        let glowSide = place.planetRadius * 4.2
        glow.bounds = CGRect(x: 0, y: 0, width: glowSide, height: glowSide)
        glow.position = CGPoint(x: side / 2, y: side / 2)
        CATransaction.commit()
        return true
    }

    private func show(_ frame: SacredGateScene.Frame) {
        guard let scene else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, stroke) in frame.gates.enumerated() {
            let shape = gateLayers[index]
            shape.path = stroke.path
            shape.opacity = Float(stroke.opacity)
            shape.lineWidth = stroke.lineWidth
        }
        lockLayer.path = frame.lock.path
        lockLayer.opacity = Float(frame.lock.opacity)
        lockLayer.lineWidth = frame.lock.lineWidth
        planetGroup.position = frame.planetCentre
        let scale = frame.planetRadius / max(0.001, scene.planetRadius)
        planetGroup.transform = CATransform3DMakeScale(scale, scale, 1)
        planetGroup.opacity = Float(frame.planetOpacity)
        haze.position = frame.vanishing
        haze.opacity = Float(frame.planetOpacity)
        CATransaction.commit()
    }

    private func play(_ part: SacredGateScene.Phase, duration: TimeInterval, then: @escaping () -> Void) {
        guard let scene else { then(); return }
        let count = max(2, Int((duration * Self.keyframesPerSecond).rounded()) + 1)
        let frames = (0..<count).map { scene.frame(part, at: CGFloat($0) / CGFloat(count - 1)) }
        func add(_ keyPath: String, _ values: [Any], to target: CALayer) {
            let animation = CAKeyframeAnimation(keyPath: keyPath)
            animation.values = values
            animation.duration = duration
            animation.calculationMode = .linear
            target.add(animation, forKey: "sacred." + keyPath)
        }
        for (index, shape) in gateLayers.enumerated() {
            add("path", frames.map { $0.gates[index].path }, to: shape)
            add("opacity", frames.map { $0.gates[index].opacity }, to: shape)
            add("lineWidth", frames.map { $0.gates[index].lineWidth }, to: shape)
        }
        add("path", frames.map { $0.lock.path }, to: lockLayer)
        add("opacity", frames.map { $0.lock.opacity }, to: lockLayer)
        add("position", frames.map { NSValue(cgPoint: $0.planetCentre) }, to: planetGroup)
        add("transform.scale", frames.map { $0.planetRadius / max(0.001, scene.planetRadius) }, to: planetGroup)
        add("opacity", frames.map { $0.planetOpacity }, to: planetGroup)
        add("position", frames.map { NSValue(cgPoint: $0.vanishing) }, to: haze)
        add("opacity", frames.map { $0.planetOpacity }, to: haze)
        if let last = frames.last { show(last) }
        clock += 1
        let mine = clock
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self, self.clock == mine else { return }
            then()
        }
    }

    private func removeMotion() {
        for target in gateLayers + [lockLayer, planetGroup, haze] { target.removeAllAnimations() }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gateLayers[SacredGateScene.innerGate].transform = CATransform3DIdentity
        CATransaction.commit()
    }

    // MARK: The inner gate turns while the wallet gets ready

    private func startTurning() {
        guard LitMotion.allowed, window != nil else { return }
        let turn = CABasicAnimation(keyPath: "transform.rotation.z")
        turn.byValue = CGFloat.pi / 3
        turn.duration = 2.9
        turn.repeatCount = .infinity
        turn.isCumulative = true
        gateLayers[SacredGateScene.innerGate].add(turn, forKey: Self.turnKey)
    }

    /// Brings the inner gate square again by the shorter way; the weave is the same every sixth of a turn.
    private func settleTurn() {
        let gate = gateLayers[SacredGateScene.innerGate]
        let angle = (gate.presentation()?.value(forKeyPath: "transform.rotation.z") as? CGFloat) ?? 0
        gate.removeAnimation(forKey: Self.turnKey)
        let sixth = CGFloat.pi / 3
        var rest = angle.truncatingRemainder(dividingBy: sixth)
        if rest > sixth / 2 { rest -= sixth }
        if rest < -sixth / 2 { rest += sixth }
        guard abs(rest) > 0.001 else { return }
        let settle = CABasicAnimation(keyPath: "transform.rotation.z")
        settle.fromValue = rest
        settle.toValue = 0
        settle.duration = SacredGeometry.beat(2)
        settle.timingFunction = CAMediaTimingFunction(name: .easeOut)
        gate.add(settle, forKey: "sacred.settle")
    }
}
