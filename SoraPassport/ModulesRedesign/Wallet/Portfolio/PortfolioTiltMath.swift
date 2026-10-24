// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import Foundation

/// Pure parallax maths (Foundation only), ported from the portfolio dashboard reference
/// (`reference/ios/TiltMath.swift`). `PortfolioTiltMathTests` replays the shared golden vectors
/// (`parallax-vectors.json`) within 1e-6. Constants and formulas here are the specification.
enum PortfolioTilt {
    enum Constants {
        /// Degrees from the resting pose that give full deflection.
        static let tiltRangeDeg = 18.0
        /// How slowly the resting pose follows the real pose.
        static let baselineTauMs = 2500.0
        static let deadzone = 0.02
        static let phoneSmoothTauMs = 110.0
        static let settleEps = 0.0006
    }

    /// A sensor quaternion: x, y, z, w (device-to-world rotation; device axes x right, y up,
    /// z out of the screen).
    typealias Quaternion = (x: Double, y: Double, z: Double, w: Double)

    static func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(upper, max(lower, value))
    }

    /// One exponential smoothing step toward the target.
    static func smoothStep(value: Double, target: Double, dtMs: Double, tauMs: Double) -> Double {
        value + (target - value) * (1 - exp(-dtMs / tauMs))
    }

    /// Layer translation in points: opposite to the input, nearer layers (larger depth) move more.
    static func layerOffset(x: Double, y: Double, depthX: Double, depthY: Double,
                            scale: Double) -> (dx: Double, dy: Double) {
        (-x * depthX * scale, -y * depthY * scale)
    }

    /// Viewer-oriented tilt in degrees: rotation of the device since the resting pose about its own
    /// long axis (roll) and short axis (pitch), from quaternions, so a phone held upright causes no
    /// Euler gimbal problem. x > 0 when the screen has turned toward the user's left, y > 0 when the
    /// screen has tilted up. Feed the result to `Baseline.normalise`.
    static func viewerTilt(from q0: Quaternion, to q: Quaternion) -> (xDeg: Double, yDeg: Double) {
        let (ax, ay, az, aw) = (-q0.x, -q0.y, -q0.z, q0.w) // conjugate of q0
        var w = aw * q.w - ax * q.x - ay * q.y - az * q.z
        var x = aw * q.x + ax * q.w + ay * q.z - az * q.y
        var y = aw * q.y - ax * q.z + ay * q.w + az * q.x
        var z = aw * q.z + ax * q.y - ay * q.x + az * q.w
        if w < 0 { w = -w; x = -x; y = -y; z = -z }
        let n = (x * x + y * y + z * z).squareRoot()
        if n < 1e-12 { return (0, 0) }
        let k = 2 * atan2(n, w) / n
        let deg = 180 / Double.pi
        // Rotation about +y is roll and about +x is pitch; negate to viewer orientation.
        return (-(y * k) * deg, -(x * k) * deg)
    }

    /// Parallax moves only when every condition holds.
    struct Gate: Equatable {
        /// The portfolio flag is on (the reference calls this the Full effects tier).
        var enabled: Bool
        /// `UIAccessibility.isReduceMotionEnabled`.
        var reduceMotion: Bool
        /// `ProcessInfo.isLowPowerModeEnabled`.
        var lowPower: Bool
        /// App inactive or the screen not visible.
        var hidden: Bool
        /// The parallax surface is on screen.
        var heroVisible: Bool

        var isOpen: Bool { enabled && !reduceMotion && !lowPower && !hidden && heroVisible }
    }

    /// Resting-pose tracker: a slow high-pass so a new holding angle becomes the new centre.
    struct Baseline {
        private let tauMs: Double
        private var rest: (roll: Double, pitch: Double)?
        private var lastMs = 0.0

        init(tauMs: Double = Constants.baselineTauMs) { self.tauMs = tauMs }

        mutating func reset() { rest = nil }

        /// `rollDeg` and `pitchDeg` are viewer-oriented degrees; returns the deviation in [-1, 1].
        mutating func normalise(rollDeg: Double, pitchDeg: Double, nowMs: Double) -> (x: Double, y: Double) {
            if rest == nil {
                rest = (rollDeg, pitchDeg)
                lastMs = nowMs
            }
            let dt = max(0, nowMs - lastMs)
            lastMs = nowMs
            let k = 1 - exp(-dt / tauMs)
            var current = rest ?? (rollDeg, pitchDeg)
            current.roll += (rollDeg - current.roll) * k
            current.pitch += (pitchDeg - current.pitch) * k
            rest = current
            func dead(_ value: Double) -> Double { abs(value) < Constants.deadzone ? 0 : value }
            return (dead(PortfolioTilt.clamp((rollDeg - current.roll) / Constants.tiltRangeDeg, -1, 1)),
                    dead(PortfolioTilt.clamp((pitchDeg - current.pitch) / Constants.tiltRangeDeg, -1, 1)))
        }
    }

    /// Smoothed 2D value. The display link runs only while `step` has not returned true.
    struct Smooth2D {
        var x = 0.0, y = 0.0, tx = 0.0, ty = 0.0
        private let tauMs: Double

        init(tauMs: Double) { self.tauMs = tauMs }

        /// Advances by `dtMs` and returns true once the value has settled on the target.
        mutating func step(dtMs: Double) -> Bool {
            x = PortfolioTilt.smoothStep(value: x, target: tx, dtMs: dtMs, tauMs: tauMs)
            y = PortfolioTilt.smoothStep(value: y, target: ty, dtMs: dtMs, tauMs: tauMs)
            let settled = abs(tx - x) < Constants.settleEps && abs(ty - y) < Constants.settleEps
            if settled {
                x = tx
                y = ty
            }
            return settled
        }
    }
}
