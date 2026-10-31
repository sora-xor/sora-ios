// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

import SoraUIKit
import UIKit

/// The ring plane on screen at one deflection. Angles are degrees of the ring's own circle: 0 at the
/// right, 90 in front (towards the viewer, below the planet's centre), growing clockwise.
struct PortfolioRingPose {
    let center: CGPoint
    let radius: CGFloat
    let aspect: CGFloat
    let rollDeg: CGFloat

    static func at(center: CGPoint, x: CGFloat, y: CGFloat) -> PortfolioRingPose {
        PortfolioRingPose(center: center,
                          radius: PortfolioTheme.Sky.ringRadius,
                          aspect: PortfolioTheme.Sky.aspect + PortfolioTheme.Sky.aspectTilt * y,
                          rollDeg: PortfolioTheme.Sky.rollDeg + PortfolioTheme.Sky.rollTiltDeg * x)
    }

    private var roll: CGFloat { rollDeg * .pi / 180 }

    /// The point of the plane's circle of radius `r` (the band's centre line by default) at `deg`.
    func point(_ deg: CGFloat, radius r: CGFloat? = nil) -> CGPoint {
        let r = r ?? radius
        let t = deg * .pi / 180
        let x = r * cos(t)
        let y = r * aspect * sin(t)
        return CGPoint(x: center.x + x * cos(roll) - y * sin(roll), y: center.y + x * sin(roll) + y * cos(roll))
    }

    /// A screen point in the ring's own plane (roll undone, height restored).
    func toPlane(_ p: CGPoint) -> CGPoint {
        let dx = p.x - center.x
        let dy = p.y - center.y
        return CGPoint(x: dx * cos(roll) + dy * sin(roll), y: (dy * cos(roll) - dx * sin(roll)) / aspect)
    }

    /// The transform of a layer centred on the planet that draws in the plane: flattened, then rolled.
    var transform: CATransform3D {
        CATransform3DConcat(CATransform3DMakeScale(1, aspect, 1), CATransform3DMakeRotation(roll, 0, 0, 1))
    }
}

/// The fan laid round the ring: 3.6 degrees per ray in the fan's order. The largest segment is centred
/// behind the planet, so the stretch of ring the planet hides always falls inside a segment that still
/// shows on both sides of it; a small segment can never disappear behind the planet, and the small
/// segments come round to the front.
enum PortfolioRing {
    static func start(_ segments: [PortfolioFanSegment]) -> CGFloat {
        guard let largest = segments.indices.max(by: { segments[$0].rays < segments[$1].rays }) else { return 90 }
        let before = segments[..<largest].reduce(0) { $0 + $1.rays }
        return 270 - (CGFloat(before) + CGFloat(segments[largest].rays) / 2) * PortfolioTheme.Sky.degreesPerRay
    }

    static func arcs(_ segments: [PortfolioFanSegment]) -> [(segment: PortfolioFanSegment, start: CGFloat, sweep: CGFloat)] {
        var arcs: [(segment: PortfolioFanSegment, start: CGFloat, sweep: CGFloat)] = []
        var start = Self.start(segments)
        for segment in segments {
            let sweep = CGFloat(segment.rays) * PortfolioTheme.Sky.degreesPerRay
            if segment.rays > 0 { arcs.append((segment: segment, start: start, sweep: sweep)) }
            start += sweep
        }
        return arcs
    }
}

/// The hero sky: a night (dark) or dawn (light) gradient, a nebula with the planet's halo, twinkling
/// stars, and the SORA planet with the allocation ring round it. The ring is the chart: 3.6 degrees
/// of band per ray (one ray per percent of the counted value), coloured by the entity's slot, its back
/// half passing behind the planet. A light runs round it while the sky is on screen. Decorative for
/// accessibility; the legend chips are the real buttons.
final class PortfolioSkyView: UIView {
    struct Model: Equatable {
        var segments: [PortfolioFanSegment]
        var highlightedKey: String?
        var showsFan: Bool
    }

    /// Parallax layers, deepest first. Only their transforms move.
    let starsView = PortfolioLayerView()
    let glowView = PortfolioLayerView()
    /// The planet and its ring, which move as one.
    let orbitView = PortfolioLayerView()

    /// Called with a segment key when the ring is tapped.
    var onSegmentTap: ((String) -> Void)?

    /// Height of the safe area above the sky's content (the sky runs under the status bar).
    var topInset: CGFloat = 0 {
        didSet { if topInset != oldValue { setNeedsLayout() } }
    }

    private let gradient = CAGradientLayer()
    private let starLayers: [CAShapeLayer] = (0..<3).map { _ in CAShapeLayer() }
    private let flareLayers: [CAShapeLayer] = (0..<5).map { _ in CAShapeLayer() }
    private let hazeViolet = CAGradientLayer()
    private let hazeCyan = CAGradientLayer()
    private let halo = CAGradientLayer()
    /// Fades the nebula out before the sky's bottom edge, which the hero card overlaps: the sky clips,
    /// and a cut halo would show through the card's glass as a line.
    private let nebulaFade = CAGradientLayer()
    private let ringBack = PortfolioRingHalf(front: false)
    private let planet = PortfolioPlanet()
    private let ringFront = PortfolioRingHalf(front: true)
    private var model = Model(segments: [], highlightedKey: nil, showsFan: false)
    private var tilt: (x: CGFloat, y: CGFloat) = (0, 0)
    private var laidOutSize: CGSize = .zero
    private var laidOutInset: CGFloat = -1
    private var wantsLoops = false
    private var drawnKeys: [String]?
    private var pendingIntro = false
    private var observers: [NSObjectProtocol] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        clipsToBounds = true
        layer.addSublayer(gradient)
        gradient.locations = PortfolioTheme.skyLocations
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)

        [starsView, glowView, orbitView].forEach {
            $0.isUserInteractionEnabled = false
            addSubview($0)
        }
        (starLayers + flareLayers).forEach { starsView.layer.addSublayer($0) }
        [hazeViolet, hazeCyan, halo].forEach {
            $0.type = .radial
            $0.startPoint = CGPoint(x: 0.5, y: 0.5)
            $0.endPoint = CGPoint(x: 1, y: 1)
            glowView.layer.addSublayer($0)
        }
        nebulaFade.colors = [UIColor.black, UIColor.black, UIColor.clear].map(\.cgColor)
        nebulaFade.locations = [0, 0.78, 1]
        nebulaFade.startPoint = CGPoint(x: 0.5, y: 0)
        nebulaFade.endPoint = CGPoint(x: 0.5, y: 1)
        glowView.layer.mask = nebulaFade
        [ringBack.layer, planet.layer, ringFront.layer].forEach { orbitView.layer.addSublayer($0) }

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)
        let center = NotificationCenter.default
        observers = [
            // Core Animation can drop running animations while the app is in the background.
            center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) {
                [weak self] _ in self?.updateLoops()
            },
            center.addObserver(forName: .neonFxChanged, object: nil, queue: .main) { [weak self] _ in
                self?.applyTheme()
                self?.updateLoops()
            }
        ]
        applyTheme()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    // MARK: Geometry

    /// The planet's centre in the sky's coordinates (before the parallax moves it).
    var planetCenter: CGPoint {
        CGPoint(x: bounds.midX, y: topInset + PortfolioTheme.Sky.planetCenterY)
    }

    /// The ring plane as drawn now: it turns with the tilt.
    var pose: PortfolioRingPose { .at(center: planetCenter, x: tilt.x, y: tilt.y) }

    /// The middle of ray `index` on the ring, in degrees.
    func rayAngle(_ index: Int) -> CGFloat {
        PortfolioRing.start(model.segments) + (CGFloat(index) + 0.5) * PortfolioTheme.Sky.degreesPerRay
    }

    /// The segment layers of the ring's front half, in the fan's order.
    var segmentLayers: [CAShapeLayer] { ringFront.segments }

    // MARK: Updates

    func apply(_ newModel: Model, animated: Bool) {
        let segmentsChanged = newModel.segments != model.segments || newModel.showsFan != model.showsFan
        model = newModel
        if segmentsChanged {
            rebuildRing()
        } else {
            applyHighlight(animated: animated)
        }
    }

    func applyTheme() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let dark = PortfolioTheme.isDark
        let glows = FxPolicy.current.glows
        gradient.colors = PortfolioTheme.skyColors()
        starsView.isHidden = !dark
        starLayers.enumerated().forEach { index, layer in
            layer.fillColor = PortfolioTheme.starColor.withAlphaComponent([0.24, 0.38, 0.56][index]).cgColor
        }
        flareLayers.forEach {
            $0.strokeColor = PortfolioTheme.starColor.withAlphaComponent(0.45).cgColor
            $0.fillColor = PortfolioTheme.starColor.withAlphaComponent(0.7).cgColor
            $0.lineWidth = 0.8
        }
        hazeViolet.colors = [PortfolioTheme.hazeViolet.cgColor, PortfolioTheme.hazeViolet.withAlphaComponent(0).cgColor]
        hazeCyan.colors = [PortfolioTheme.hazeCyan.cgColor, PortfolioTheme.hazeCyan.withAlphaComponent(0).cgColor]
        let glow = PortfolioTheme.glowColor
        halo.colors = [glow.cgColor,
                       PortfolioTheme.soraDeep.withAlphaComponent(glow.cgColor.alpha * 0.44).cgColor,
                       UIColor.clear.cgColor]
        halo.locations = [0, 0.38, 1]
        ringBack.applyTheme(dark: dark, glows: glows)
        ringFront.applyTheme(dark: dark, glows: glows)
        planet.applyTheme(dark: dark, glows: glows)
        CATransaction.commit()
    }

    /// Turns the ring plane, and slides the planet's highlight and the ring's glint, with the deflection.
    func setTilt(x: CGFloat, y: CGFloat) {
        tilt = (x, y)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let pose = self.pose
        ringBack.setPose(pose, glintDeg: 90 - 50 * x)
        ringFront.setPose(pose, glintDeg: 90 - 50 * x)
        planet.setTilt(x: x, y: y)
        CATransaction.commit()
    }

    /// Runs the light round the ring, the stars' twinkle and the halo's breathing while the sky is on
    /// screen (and the effect tier and Reduce Motion allow looping motion).
    func setLooping(_ on: Bool) {
        wantsLoops = on
        updateLoops()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateLoops()
        runIntroIfReady()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != laidOutSize || topInset != laidOutInset else { return }
        laidOutSize = bounds.size
        laidOutInset = topInset
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = bounds
        [starsView, glowView, orbitView].forEach { view in
            view.bounds = CGRect(origin: .zero, size: bounds.size)
            view.center = CGPoint(x: bounds.midX, y: bounds.midY)
        }
        layoutStars()
        // Wider than the sky, so the parallax never slides an unmasked edge into view.
        nebulaFade.frame = CGRect(x: -24, y: 0, width: bounds.width + 48, height: bounds.height)
        let center = planetCenter
        place(hazeViolet, at: CGPoint(x: bounds.width * 0.1, y: bounds.height * 0.32), radius: bounds.width * 0.62)
        place(hazeCyan, at: CGPoint(x: bounds.width * 0.92, y: bounds.height * 0.12), radius: bounds.width * 0.5)
        place(halo, at: center, radius: 175)
        [ringBack.layer, planet.layer, ringFront.layer].forEach { $0.position = center }
        CATransaction.commit()
        setTilt(x: tilt.x, y: tilt.y)
    }

    private func place(_ layer: CALayer, at center: CGPoint, radius: CGFloat) {
        layer.bounds = CGRect(x: 0, y: 0, width: radius * 2, height: radius * 2)
        layer.position = center
    }

    private func layoutStars() {
        // Deterministic speckle, the same on every device and every launch.
        var seed: UInt32 = 11
        func next() -> CGFloat {
            seed = (seed &* 9301 &+ 49297) % 233_280
            return CGFloat(seed) / 233_280
        }
        let paths = starLayers.map { _ in UIBezierPath() }
        for index in 0..<30 {
            let x = next() * bounds.width
            let y = topInset * 0.4 + next() * (bounds.height - topInset * 0.4) * 0.78
            let radius: CGFloat = index % 6 == 0 ? 1.3 : 0.8
            let bucket = Int(next() * 3) % 3
            paths[bucket].append(UIBezierPath(ovalIn: CGRect(x: x - radius, y: y - radius,
                                                            width: radius * 2, height: radius * 2)))
        }
        zip(starLayers, paths).forEach { layer, path in
            layer.frame = bounds
            layer.path = path.cgPath
        }
        // A few brighter stars with a cross flare; they twinkle while the sky loops.
        for (index, flare) in flareLayers.enumerated() {
            let p = CGPoint(x: next() * bounds.width,
                            y: topInset * 0.4 + (0.08 + next() * 0.5) * (bounds.height - topInset * 0.4))
            let arm: CGFloat = index % 2 == 0 ? 5 : 7
            let path = UIBezierPath()
            path.move(to: CGPoint(x: p.x - arm, y: p.y))
            path.addLine(to: CGPoint(x: p.x + arm, y: p.y))
            path.move(to: CGPoint(x: p.x, y: p.y - arm))
            path.addLine(to: CGPoint(x: p.x, y: p.y + arm))
            path.append(UIBezierPath(ovalIn: CGRect(x: p.x - 1.4, y: p.y - 1.4, width: 2.8, height: 2.8)))
            flare.frame = bounds
            flare.path = path.cgPath
        }
    }

    private func rebuildRing() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let arcs = model.showsFan ? PortfolioRing.arcs(model.segments) : []
        let gap = arcs.count > 1 ? PortfolioTheme.Sky.gapDeg : 0
        let drawn = arcs.map { (key: $0.segment.key, color: PortfolioTheme.color(for: $0.segment.slot),
                                start: $0.start, sweep: $0.sweep) }
        ringBack.setSegments(drawn, gap: gap)
        ringFront.setSegments(drawn, gap: gap)
        CATransaction.commit()
        applyHighlight(animated: false)
        let keys = arcs.map(\.segment.key)
        if keys != drawnKeys {
            drawnKeys = keys
            pendingIntro = !keys.isEmpty
            runIntroIfReady()
        }
    }

    /// The ring draws itself in once per set of segments (first data, a new lens), when on screen.
    private func runIntroIfReady() {
        guard pendingIntro, window != nil else { return }
        pendingIntro = false
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        // One ease-out over the whole ring: each segment draws over its own stretch of the curve.
        func time(_ fraction: CGFloat) -> CFTimeInterval {
            PortfolioTheme.Sky.intro * CFTimeInterval(1 - pow(1 - min(max(fraction, 0), 1), 1.0 / 3))
        }
        var done: CGFloat = 0
        let timings = model.segments.filter { $0.rays > 0 }.map { segment -> (CFTimeInterval, CFTimeInterval) in
            let share = CGFloat(segment.rays) / CGFloat(PortfolioAllocation.rayCount)
            defer { done += share }
            let begin = time(done)
            return (begin, max(time(done + share) - begin, 0.01))
        }
        let now = CACurrentMediaTime()
        ringBack.drawIn(timings, at: now)
        ringFront.drawIn(timings, at: now)
    }

    private func applyHighlight(animated: Bool) {
        let duration = animated && !UIAccessibility.isReduceMotionEnabled ? NeonMotion.base : 0
        let glows = FxPolicy.current.glows
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        CATransaction.setAnimationTimingFunction(NeonMotion.standard)
        if duration == 0 { CATransaction.setDisableActions(true) }
        ringBack.applyHighlight(model.highlightedKey, duration: duration, glows: glows)
        ringFront.applyHighlight(model.highlightedKey, duration: duration, glows: glows)
        CATransaction.commit()
    }

    private var loopsAllowed: Bool {
        let fx = FxPolicy.current
        return !fx.reduceMotion && fx.tier != .minimal
    }

    private func updateLoops() {
        guard wantsLoops, loopsAllowed, window != nil else {
            ringBack.stopComet()
            ringFront.stopComet()
            flareLayers.forEach { $0.removeAnimation(forKey: "twinkle") }
            halo.removeAnimation(forKey: "breath")
            return
        }
        guard !ringFront.isCometRunning else { return }
        let now = CACurrentMediaTime()
        ringBack.startComet(at: now)
        ringFront.startComet(at: now)
        for (index, flare) in flareLayers.enumerated() {
            let twinkle = CABasicAnimation(keyPath: "opacity")
            twinkle.fromValue = 1
            twinkle.toValue = 0.25
            twinkle.duration = 1.3 + 0.5 * Double(index)
            twinkle.timeOffset = 0.37 * Double(index)
            twinkle.autoreverses = true
            twinkle.repeatCount = .infinity
            twinkle.isRemovedOnCompletion = false
            flare.add(twinkle, forKey: "twinkle")
        }
        let breath = CABasicAnimation(keyPath: "opacity")
        breath.fromValue = 1
        breath.toValue = 0.78
        breath.duration = 3
        breath.autoreverses = true
        breath.repeatCount = .infinity
        breath.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        breath.isRemovedOnCompletion = false
        halo.add(breath, forKey: "breath")
    }

    // MARK: Touch

    /// The segment under a point: on the ring's band or within the tap slop of it on screen, and not on
    /// the part of the ring behind the planet. The planet itself takes no taps.
    func segmentKey(at point: CGPoint) -> String? {
        guard model.showsFan, !model.segments.isEmpty else { return nil }
        // The parallax moves the planet and its ring together.
        let p = orbitView.convert(point, from: self)
        let pose = self.pose
        let q = pose.toPlane(p)
        let r = (q.x * q.x + q.y * q.y).squareRoot()
        guard r > 0 else { return nil }
        var deg = atan2(q.y, q.x) * 180 / .pi
        if deg < 0 { deg += 360 }
        let t = deg * .pi / 180
        // Screen length of one plane unit along the radius at this angle: the plane is flattened.
        let radial = (cos(t) * cos(t) + pose.aspect * pose.aspect * sin(t) * sin(t)).squareRoot()
        guard abs(r - pose.radius) <= PortfolioTheme.Sky.ringWidth / 2 + PortfolioTheme.Sky.tapSlop / radial else {
            return nil
        }
        if sin(t) < 0, hypot(p.x - pose.center.x, p.y - pose.center.y) < PortfolioTheme.Sky.planetRadius {
            return nil
        }
        var offset = (deg - PortfolioRing.start(model.segments)).truncatingRemainder(dividingBy: 360)
        if offset < 0 { offset += 360 }
        let index = min(Int(offset / PortfolioTheme.Sky.degreesPerRay), PortfolioAllocation.rayCount - 1)
        var start = 0
        for segment in model.segments {
            if index >= start && index < start + segment.rays { return segment.key }
            start += segment.rays
        }
        return nil
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let key = segmentKey(at: recognizer.location(in: self)) else { return }
        onSegmentTap?(key)
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // Only the ring takes touches; everything else falls through to the controls above.
        segmentKey(at: point) != nil
    }
}

/// One half of the ring plane, behind or in front of the planet: a layer centred on the planet that is
/// flattened and rolled with the plane and masked to its half. The back half fades towards its far
/// edge, which is in the planet's shadow.
private final class PortfolioRingHalf {
    static let side = 2 * (PortfolioTheme.Sky.orbitOuter + 16)

    let layer = CALayer()
    private(set) var segments: [CAShapeLayer] = []
    private let front: Bool
    private let mask = CAGradientLayer()
    private let outer = CAShapeLayer()
    private let inner = CAShapeLayer()
    private let track = CAShapeLayer()
    private let pulses = [CAShapeLayer(), CAShapeLayer(), CAShapeLayer()]
    private let glints = [CAShapeLayer(), CAShapeLayer(), CAShapeLayer()]
    private let carrier = CALayer()
    private let beadGlow = CAGradientLayer()
    private let beadCore = CALayer()
    private var mid: CGPoint { CGPoint(x: Self.side / 2, y: Self.side / 2) }

    init(front: Bool) {
        self.front = front
        layer.bounds = CGRect(x: 0, y: 0, width: Self.side, height: Self.side)
        mask.frame = layer.bounds
        mask.startPoint = CGPoint(x: 0.5, y: 0)
        mask.endPoint = CGPoint(x: 0.5, y: 1)
        if front {
            mask.colors = [UIColor.clear, UIColor.clear, UIColor.black, UIColor.black].map(\.cgColor)
            mask.locations = [0, 0.5, 0.5, 1]
        } else {
            let far = (Self.side / 2 - PortfolioTheme.Sky.ringRadius) / Self.side
            let dim = UIColor.black.withAlphaComponent(0.6).cgColor
            mask.colors = [dim, dim, UIColor.black.cgColor, UIColor.clear.cgColor, UIColor.clear.cgColor]
            mask.locations = [0, NSNumber(value: Double(far)), 0.5, 0.5, 1]
        }
        layer.mask = mask

        let r = PortfolioTheme.Sky.ringRadius
        let band = PortfolioTheme.Sky.ringWidth
        for (shape, radius, width) in [(outer, PortfolioTheme.Sky.orbitOuter, 1.4),
                                       (inner, PortfolioTheme.Sky.orbitInner, 1.2),
                                       (track, r, band)] as [(CAShapeLayer, CGFloat, CGFloat)] {
            shape.frame = layer.bounds
            shape.fillColor = nil
            shape.lineWidth = width
            shape.path = UIBezierPath(arcCenter: mid, radius: radius, startAngle: 0, endAngle: 2 * .pi,
                                      clockwise: true).cgPath
            layer.addSublayer(shape)
        }
        outer.lineDashPattern = [4, 9]
        for (pulse, alpha) in zip(pulses, [0.10, 0.14, 0.22] as [CGFloat]) {
            pulse.frame = layer.bounds
            pulse.fillColor = nil
            pulse.lineWidth = band
            pulse.strokeColor = UIColor.white.withAlphaComponent(alpha).cgColor
            pulse.isHidden = true
            layer.addSublayer(pulse)
        }
        // The glint sits in front, centred at 90 degrees; turning the layer slides it round the ring.
        for (glint, (span, alpha)) in zip(glints, [(28, 0.06), (15, 0.09), (6, 0.13)] as [(CGFloat, CGFloat)]) {
            glint.frame = layer.bounds
            glint.fillColor = nil
            glint.lineWidth = band
            glint.strokeColor = UIColor.white.withAlphaComponent(alpha).cgColor
            glint.path = UIBezierPath(arcCenter: mid, radius: r, startAngle: (90 - span / 2) * .pi / 180,
                                      endAngle: (90 + span / 2) * .pi / 180, clockwise: true).cgPath
            glint.isHidden = !front
            layer.addSublayer(glint)
        }
        // The comet's head: a round bead that the carrier moves round the band.
        beadGlow.type = .radial
        beadGlow.startPoint = CGPoint(x: 0.5, y: 0.5)
        beadGlow.endPoint = CGPoint(x: 1, y: 1)
        beadGlow.colors = [UIColor.white.withAlphaComponent(0.9), PortfolioTheme.soraGlow.withAlphaComponent(0.45),
                           UIColor.clear].map(\.cgColor)
        beadGlow.locations = [0, 0.35, 1]
        beadGlow.bounds = CGRect(x: 0, y: 0, width: 20, height: 20)
        beadCore.bounds = CGRect(x: 0, y: 0, width: 4.4, height: 4.4)
        beadCore.cornerRadius = 2.2
        beadCore.backgroundColor = UIColor.white.cgColor
        [beadGlow, beadCore].forEach {
            $0.position = .zero
            carrier.addSublayer($0)
        }
        carrier.isHidden = true
        layer.addSublayer(carrier)
    }

    var isCometRunning: Bool { carrier.animation(forKey: "comet") != nil }

    func applyTheme(dark: Bool, glows: Bool) {
        let line = PortfolioTheme.ringLine
        outer.strokeColor = line.withAlphaComponent(dark ? 0.16 : 0.12).cgColor
        inner.strokeColor = line.withAlphaComponent(dark ? 0.09 : 0.07).cgColor
        track.strokeColor = line.withAlphaComponent(dark ? 0.07 : 0.06).cgColor
        glints.forEach { $0.isHidden = !front || !glows || segments.isEmpty }
    }

    func setPose(_ pose: PortfolioRingPose, glintDeg: CGFloat) {
        layer.transform = pose.transform
        // The bead stays round: undo the plane's flattening.
        carrier.sublayerTransform = CATransform3DMakeScale(1, 1 / pose.aspect, 1)
        let turn = CATransform3DMakeRotation((glintDeg - 90) * .pi / 180, 0, 0, 1)
        glints.forEach { $0.transform = turn }
    }

    func setSegments(_ arcs: [(key: String, color: UIColor, start: CGFloat, sweep: CGFloat)], gap: CGFloat) {
        segments.forEach { $0.removeFromSuperlayer() }
        segments = arcs.map { arc in
            let shape = CAShapeLayer()
            shape.frame = layer.bounds
            shape.fillColor = nil
            shape.lineCap = .butt
            shape.lineWidth = PortfolioTheme.Sky.ringWidth
            shape.strokeColor = arc.color.cgColor
            shape.shadowColor = arc.color.cgColor
            shape.shadowOffset = .zero
            shape.shadowRadius = 6
            let start = (arc.start + gap / 2) * .pi / 180
            let end = (arc.start + max(arc.sweep - gap / 2, gap / 2 + 0.6)) * .pi / 180
            shape.path = UIBezierPath(arcCenter: mid, radius: PortfolioTheme.Sky.ringRadius, startAngle: start,
                                      endAngle: end, clockwise: true).cgPath
            shape.name = arc.key
            layer.insertSublayer(shape, below: pulses[0])
            return shape
        }
        glints.forEach { $0.isHidden = !front || !FxPolicy.current.glows || segments.isEmpty }
    }

    func applyHighlight(_ key: String?, duration: CFTimeInterval, glows: Bool) {
        for shape in segments {
            let selected = key == shape.name
            let width = PortfolioTheme.Sky.ringWidth * (selected ? PortfolioTheme.Sky.selectedWidth : 1)
            if duration > 0 {
                let animation = CABasicAnimation(keyPath: "lineWidth")
                animation.fromValue = shape.presentation()?.lineWidth ?? shape.lineWidth
                animation.toValue = width
                animation.duration = duration
                animation.timingFunction = NeonMotion.standard
                shape.add(animation, forKey: "highlight")
            }
            shape.lineWidth = width
            shape.opacity = key != nil && !selected ? PortfolioTheme.Sky.dimmedAlpha : 1
            shape.shadowOpacity = selected && glows ? 0.7 : 0
        }
    }

    /// Draws the segments in, each over its own stretch of time (seconds from `now`).
    func drawIn(_ timings: [(CFTimeInterval, CFTimeInterval)], at now: CFTimeInterval) {
        for (shape, timing) in zip(segments, timings) {
            let draw = CABasicAnimation(keyPath: "strokeEnd")
            draw.fromValue = 0
            draw.toValue = 1
            draw.beginTime = now + timing.0
            draw.duration = timing.1
            draw.fillMode = .backwards
            shape.add(draw, forKey: "intro")
        }
    }

    /// One lap of light from the front, clockwise, every `PortfolioTheme.Sky.cometLap` seconds. Both
    /// halves start at the same instant, so the light passes behind the planet and out again.
    func startComet(at beginTime: CFTimeInterval) {
        let lap = PortfolioTheme.Sky.cometLap
        let r = PortfolioTheme.Sky.ringRadius
        let frontAngle: CGFloat = .pi / 2
        let move = CAKeyframeAnimation(keyPath: "position")
        move.path = UIBezierPath(arcCenter: mid, radius: r, startAngle: frontAngle, endAngle: frontAngle + 2 * .pi,
                                 clockwise: true).cgPath
        move.calculationMode = .paced
        move.duration = lap
        move.repeatCount = .infinity
        move.beginTime = beginTime
        move.isRemovedOnCompletion = false
        carrier.add(move, forKey: "comet")
        carrier.isHidden = false
        // Two laps, so the tail of the light never wraps round the path's start.
        let twoLaps = UIBezierPath(arcCenter: mid, radius: r, startAngle: frontAngle - 2 * .pi,
                                   endAngle: frontAngle + 2 * .pi, clockwise: true).cgPath
        for (pulse, span) in zip(pulses, [34, 20, 9] as [CGFloat]) {
            pulse.path = twoLaps
            let tail = span / 720
            let head = CABasicAnimation(keyPath: "strokeEnd")
            head.fromValue = 0.5
            head.toValue = 1
            let rear = CABasicAnimation(keyPath: "strokeStart")
            rear.fromValue = 0.5 - tail
            rear.toValue = 1 - tail
            let lapAnimation = CAAnimationGroup()
            lapAnimation.animations = [head, rear]
            lapAnimation.duration = lap
            lapAnimation.repeatCount = .infinity
            lapAnimation.beginTime = beginTime
            lapAnimation.isRemovedOnCompletion = false
            pulse.add(lapAnimation, forKey: "comet")
            pulse.isHidden = false
        }
    }

    func stopComet() {
        carrier.removeAnimation(forKey: "comet")
        carrier.isHidden = true
        pulses.forEach {
            $0.removeAnimation(forKey: "comet")
            $0.isHidden = true
        }
    }
}

/// The SORA planet: the brand's red disc with the 天 mark, shaded as a sphere lit from the top left,
/// a specular highlight that slides against the tilt, and a cool rim on the shadow side.
private final class PortfolioPlanet {
    let layer = CALayer()
    private let atmosphere = CAGradientLayer()
    private let body = CAGradientLayer()
    private let mark = CAShapeLayer()
    private let shade = CAGradientLayer()
    private let gloss = CALayer()
    private let highlight = CAGradientLayer()
    private let rim = CAGradientLayer()
    private let rimMask = CAShapeLayer()
    private let radius = PortfolioTheme.Sky.planetRadius

    init() {
        let r = radius
        let disc = CGRect(x: 0, y: 0, width: 2 * r, height: 2 * r)
        layer.bounds = disc

        atmosphere.type = .radial
        atmosphere.bounds = CGRect(x: 0, y: 0, width: 2.6 * r, height: 2.6 * r)
        atmosphere.position = CGPoint(x: r, y: r)
        atmosphere.startPoint = CGPoint(x: 0.5, y: 0.5)
        atmosphere.endPoint = CGPoint(x: 1, y: 1)
        atmosphere.locations = [0, 0.72, 0.79, 1]

        // Lit from the top left: the gradient's centre is 0.34 r left of and 0.38 r above the centre.
        for sphere in [body, shade] {
            sphere.type = .radial
            sphere.frame = disc
            sphere.cornerRadius = r
            sphere.masksToBounds = true
            sphere.startPoint = CGPoint(x: 0.33, y: 0.31)
            sphere.endPoint = CGPoint(x: 0.33 + 0.81, y: 0.31 + 0.81)
        }
        body.colors = [PortfolioTheme.soraLight, PortfolioTheme.soraRed, PortfolioTheme.soraDeep,
                       PortfolioTheme.soraEdge].map(\.cgColor)
        body.locations = [0, 0.42, 0.84, 1]
        // The mark is printed on the sphere, so the shade turns it away with the body.
        shade.colors = [UIColor.clear, UIColor.clear, UIColor.black.withAlphaComponent(0.34)].map(\.cgColor)
        shade.locations = [0, 0.55, 1]

        mark.frame = disc
        mark.fillColor = UIColor.white.cgColor
        mark.path = PortfolioGlyphs.soraMarkPath(in: disc).cgPath

        gloss.frame = disc
        gloss.cornerRadius = r
        gloss.masksToBounds = true
        highlight.type = .radial
        highlight.bounds = CGRect(x: 0, y: 0, width: r, height: r * 0.58)
        highlight.startPoint = CGPoint(x: 0.5, y: 0.5)
        highlight.endPoint = CGPoint(x: 1, y: 1)
        highlight.colors = [UIColor.white.withAlphaComponent(0.55), UIColor.clear].map(\.cgColor)
        highlight.transform = CATransform3DMakeRotation(-32 * .pi / 180, 0, 0, 1)
        gloss.addSublayer(highlight)

        rim.frame = disc
        rim.startPoint = .zero
        rim.endPoint = CGPoint(x: 1, y: 1)
        rim.locations = [0, 0.4, 1]
        rimMask.frame = disc
        rimMask.fillColor = nil
        rimMask.strokeColor = UIColor.black.cgColor
        rimMask.lineWidth = 1.5
        rimMask.path = UIBezierPath(ovalIn: disc.insetBy(dx: 0.75, dy: 0.75)).cgPath
        rim.mask = rimMask

        // The gloss sits under the mark, so the 天 stays crisp.
        [atmosphere, body, gloss, mark, shade, rim].forEach { layer.addSublayer($0) }
        setTilt(x: 0, y: 0)
    }

    func applyTheme(dark: Bool, glows: Bool) {
        atmosphere.isHidden = !glows
        atmosphere.colors = [UIColor.clear, UIColor.clear,
                             PortfolioTheme.soraRed.withAlphaComponent(dark ? 0.6 : 0.32), UIColor.clear].map(\.cgColor)
        rim.colors = [UIColor.clear, UIColor.clear, PortfolioTheme.rimColor].map(\.cgColor)
    }

    /// The highlight slides against the tilt, a little more than the planet moves.
    func setTilt(x: CGFloat, y: CGFloat) {
        highlight.position = CGPoint(x: radius * (1 - 0.4 - 0.14 * x), y: radius * (1 - 0.5 - 0.1 * y))
    }
}

/// A plain container whose transform the parallax controller drives.
final class PortfolioLayerView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
