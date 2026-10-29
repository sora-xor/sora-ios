// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

import CoreMotion
import SoraUIKit
import UIKit

/// UIKit and CoreMotion glue for the portfolio sky and the token orbit, ported from the dashboard
/// reference (`reference/ios/TiltParallaxController.swift`). Only the transforms of the supplied
/// layer views change; labels, rows and balances never move. Nothing runs while the phone is still:
/// the display link starts on input and stops once the value has settled, and the sensor stops
/// whenever a gate closes (Reduce Motion, Low Power or reduced effects, app inactive, surface off
/// screen). Layers move opposite to the tilt and nearer layers move more.
final class PortfolioParallaxController {
    struct Layer {
        let view: UIView
        /// Points at full deflection.
        let depthX: CGFloat
        let depthY: CGFloat
        /// Degrees at full horizontal deflection.
        let rotateDeg: CGFloat

        init(view: UIView, depth: CGFloat, yFactor: CGFloat = PortfolioTheme.Depth.yFactor, rotateDeg: CGFloat = 0) {
            self.view = view
            depthX = depth
            depthY = depth * yFactor
            self.rotateDeg = rotateDeg
        }
    }

    /// Called on every rendered frame with the smoothed deflection (sheen angle, glow).
    var onRender: ((CGFloat, CGFloat) -> Void)?

    private let layers: [Layer]
    typealias MotionPolicy = (enabled: Bool, reduceMotion: Bool, lowPower: Bool)

    private let manager: CMMotionManager
    private let motionPolicy: () -> MotionPolicy
    private var baseline = PortfolioTilt.Baseline()
    private var smooth = PortfolioTilt.Smooth2D(tauMs: PortfolioTilt.Constants.phoneSmoothTauMs)
    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var reference: CMAttitude?
    private var heroVisible = false
    private var appActive = UIApplication.shared.applicationState == .active
    private var observers: [NSObjectProtocol] = []
    private var started = false
    /// A fixed deflection injected for screenshots in non-production builds.
    private var injected: (x: Double, y: Double)?

    init(layers: [Layer], manager: CMMotionManager = CMMotionManager(),
         motionPolicy: @escaping () -> MotionPolicy = {
             let fx = FxPolicy.current
             return (fx.tier == .full, fx.reduceMotion, ProcessInfo.processInfo.isLowPowerModeEnabled)
         }) {
        self.layers = layers
        self.manager = manager
        self.motionPolicy = motionPolicy
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        manager.stopDeviceMotionUpdates()
        link?.invalidate()
    }

    var gate: PortfolioTilt.Gate {
        let policy = motionPolicy()
        return PortfolioTilt.Gate(enabled: policy.enabled,
                                  reduceMotion: policy.reduceMotion,
                                  lowPower: policy.lowPower,
                                  hidden: !appActive,
                                  heroVisible: heroVisible)
    }

    /// The current smoothed deflection.
    var deflection: (x: Double, y: Double) { (smooth.x, smooth.y) }

    /// Call when the surface scrolls into or out of view.
    func setHeroVisible(_ visible: Bool) {
        guard visible != heroVisible else { return }
        heroVisible = visible
        refresh()
    }

    func start() {
        guard !started else { return }
        started = true
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) {
                [weak self] _ in
                self?.appActive = true
                self?.refresh()
            },
            center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) {
                [weak self] _ in
                self?.appActive = false
                self?.refresh()
            },
            center.addObserver(forName: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil,
                               queue: .main) { [weak self] _ in self?.refresh() },
            center.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) {
                [weak self] _ in self?.refresh()
            },
            center.addObserver(forName: .neonFxChanged, object: nil, queue: .main) { [weak self] _ in self?.refresh() }
        ]
        refresh()
    }

    func stop() {
        started = false
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        manager.stopDeviceMotionUpdates()
        link?.invalidate()
        link = nil
        smooth.tx = 0
        smooth.ty = 0
        smooth.x = 0
        smooth.y = 0
        apply()
    }

    /// Holds a fixed deflection (screenshots of the moved state). Not reachable in production builds.
    func inject(x: Double, y: Double) {
        guard PortfolioFeature.allowsDebugInjection else { return }
        injected = (PortfolioTilt.clamp(x, -1, 1), PortfolioTilt.clamp(y, -1, 1))
        manager.stopDeviceMotionUpdates()
        link?.invalidate()
        link = nil
        smooth.x = injected?.x ?? 0
        smooth.y = injected?.y ?? 0
        smooth.tx = smooth.x
        smooth.ty = smooth.y
        apply()
    }

    /// Starts or stops the sensor so that nothing runs while the gate is closed.
    private func refresh() {
        guard injected == nil else { return }
        if started && gate.isOpen {
            guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
            baseline.reset()
            reference = nil
            manager.deviceMotionUpdateInterval = 1.0 / 60.0
            manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
                // CoreMotion may already have queued a sample when updates stop.
                // A late callback must not restart rendering after the surface closes.
                guard let self, self.started, self.gate.isOpen,
                      let attitude = motion?.attitude else { return }
                // Rotation since the first sample about the device's own axes (no gimbal problem upright).
                guard let reference = self.reference else {
                    self.reference = attitude.copy() as? CMAttitude
                    return
                }
                guard let relative = attitude.copy() as? CMAttitude else { return }
                relative.multiply(byInverseOf: reference)
                // CoreMotion roll and pitch are right-handed about the device y and x axes. The viewer
                // orientation is the opposite: x > 0 when the screen turned left, y > 0 when it tilted up.
                let value = self.baseline.normalise(rollDeg: -relative.roll * 180 / .pi,
                                                    pitchDeg: -relative.pitch * 180 / .pi,
                                                    nowMs: CACurrentMediaTime() * 1000)
                self.smooth.tx = value.x
                self.smooth.ty = value.y
                // The frame loop runs only while the value is moving towards a new target.
                let eps = PortfolioTilt.Constants.settleEps
                if abs(value.x - self.smooth.x) >= eps || abs(value.y - self.smooth.y) >= eps {
                    self.startLink()
                }
            }
        } else {
            manager.stopDeviceMotionUpdates()
            smooth.tx = 0
            smooth.ty = 0
            if smooth.x != 0 || smooth.y != 0 {
                startLink() // glide back to rest, then stop
            }
        }
    }

    private func startLink() {
        guard link == nil else { return }
        lastTimestamp = CACurrentMediaTime()
        let displayLink = CADisplayLink(target: PortfolioWeakTarget(self), selector: #selector(PortfolioWeakTarget.tick(_:)))
        displayLink.add(to: .main, forMode: .common)
        link = displayLink
    }

    fileprivate func frame(_ displayLink: CADisplayLink) {
        let dtMs = min(64, (displayLink.timestamp - lastTimestamp) * 1000)
        lastTimestamp = displayLink.timestamp
        let settled = smooth.step(dtMs: dtMs)
        apply()
        if settled {
            displayLink.invalidate()
            link = nil
        }
    }

    private func apply() {
        for layer in layers {
            let offset = PortfolioTilt.layerOffset(x: smooth.x, y: smooth.y, depthX: Double(layer.depthX),
                                                   depthY: Double(layer.depthY), scale: 1)
            var transform = CGAffineTransform(translationX: CGFloat(offset.dx), y: CGFloat(offset.dy))
            if layer.rotateDeg != 0 {
                transform = transform.rotated(by: CGFloat(smooth.x) * layer.rotateDeg * .pi / 180)
            }
            layer.view.transform = transform
        }
        onRender?(CGFloat(smooth.x), CGFloat(smooth.y))
    }
}

/// Breaks the display link's strong reference to its target.
private final class PortfolioWeakTarget {
    weak var owner: PortfolioParallaxController?

    init(_ owner: PortfolioParallaxController) {
        self.owner = owner
    }

    @objc func tick(_ link: CADisplayLink) {
        guard let owner else {
            link.invalidate()
            return
        }
        owner.frame(link)
    }
}
