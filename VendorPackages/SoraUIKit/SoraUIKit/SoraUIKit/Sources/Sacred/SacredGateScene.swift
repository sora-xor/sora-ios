import CoreGraphics
import Foundation

/// The flight a cold start takes: down a line of gates to the planet.
///
/// The planet sits at the origin and the camera comes along the axis towards it. Each gate is a flat figure
/// standing across the axis. The camera stops once, in front of the inner gate, until the wallet is ready;
/// then it goes through. These are only the numbers: `SacredGateView` plays them, and Android draws the
/// same ones.
public struct SacredGateScene {
    public enum Phase {
        /// From the far end to the stop in front of the inner gate.
        case intro
        /// Through the inner gate to the planet.
        case outro
    }

    public struct Gate {
        public let figure: SacredGeometry.Figure
        /// How far in front of the planet it stands, as a share of the flight's starting distance.
        public let station: CGFloat
        /// Radius in the scene's own units.
        public let radius: CGFloat
        /// The turn it starts with; it comes square as the camera reaches it.
        public let roll: CGFloat
        public let isGold: Bool
        public let weight: CGFloat
    }

    public static let gates: [Gate] = [
        Gate(figure: .shippo, station: 0.84, radius: 4.6, roll: -0.50, isGold: false, weight: 0.9),
        Gate(figure: .kagome, station: 0.70, radius: 5.0, roll: 0.62, isGold: true, weight: 1.2),
        Gate(figure: .compass, station: 0.56, radius: 5.4, roll: -0.80, isGold: false, weight: 0.9),
        Gate(figure: .coin, station: 0.42, radius: 5.6, roll: 0.90, isGold: true, weight: 1.2),
        Gate(figure: .kagome, station: 0.28, radius: 5.2, roll: -0.70, isGold: false, weight: 0.9)
    ]
    /// The gate the camera waits in front of.
    public static let innerGate = gates.count - 1

    public static let endDistance: CGFloat = 14.1
    public static let startDistance: CGFloat = endDistance * 5.6
    /// The share of the way at which the camera waits.
    public static let holdProgress: CGFloat = 0.584
    public static let introDuration: TimeInterval = 1.0
    public static let outroDuration: TimeInterval = SacredGeometry.beat(4)
    /// A gate nearer than this is behind the lens.
    static let nearPlane: CGFloat = 0.6

    public let size: CGSize
    /// Where the planet lands, its radius there and the radius of the ring round it, in points.
    public let landing: CGPoint
    public let planetRadius: CGFloat
    public let ringRadius: CGFloat
    /// Lens length in points. It follows the width, so the picture is the same on every phone.
    public let focal: CGFloat

    public init(size: CGSize, landing: CGPoint, planetRadius: CGFloat, ringRadius: CGFloat) {
        self.size = size
        self.landing = landing
        self.planetRadius = planetRadius
        self.ringRadius = ringRadius
        focal = 620 * min(max(size.width, 280), 500) / 402
    }

    public struct Pose: Equatable {
        public var distance: CGFloat
        public var yaw: CGFloat
        public var pitch: CGFloat
        public var vanishing: CGPoint
        /// Everything fades up from the plain launch page.
        public var fade: CGFloat
        /// How much of the ring round the planet has appeared.
        public var lock: CGFloat
    }

    public struct Stroke {
        public let path: CGPath
        public let opacity: CGFloat
        public let lineWidth: CGFloat
    }

    public struct Frame {
        public let gates: [Stroke]
        public let lock: Stroke
        public let planetCentre: CGPoint
        public let planetRadius: CGFloat
        public let planetOpacity: CGFloat
        public let vanishing: CGPoint
    }

    static func easeInOut(_ t: CGFloat) -> CGFloat {
        t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
    }

    static func easeOut(_ t: CGFloat) -> CGFloat { 1 - pow(1 - t, 3) }

    static func unit(_ value: CGFloat) -> CGFloat { min(1, max(0, value)) }

    public func pose(_ phase: Phase, at time: CGFloat) -> Pose {
        let t = Self.unit(time)
        let middle = CGPoint(x: size.width / 2, y: size.height / 2)
        let span = Self.endDistance - Self.startDistance
        switch phase {
        case .intro:
            let settle = 1 - Self.easeOut(t)
            return Pose(distance: Self.startDistance + span * Self.holdProgress * Self.easeInOut(t),
                        yaw: 0.085 * settle, pitch: -0.06 * settle, vanishing: middle,
                        fade: Self.unit(t / 0.18), lock: 0)
        case .outro:
            let move = Self.easeInOut(t)
            let progress = Self.holdProgress + (1 - Self.holdProgress) * move
            return Pose(distance: Self.startDistance + span * progress, yaw: 0, pitch: 0,
                        vanishing: CGPoint(x: middle.x + (landing.x - middle.x) * move,
                                           y: middle.y + (landing.y - middle.y) * move),
                        fade: 1, lock: Self.easeOut(Self.unit((t - 0.25) / 0.75)))
        }
    }

    /// A point of the scene on the screen. `z` is negative in front of the planet.
    public func project(_ point: CGPoint, z: CGFloat, pose: Pose) -> CGPoint {
        let cosYaw = cos(pose.yaw), sinYaw = sin(pose.yaw)
        let x = point.x * cosYaw + z * sinYaw
        let turned = -point.x * sinYaw + z * cosYaw
        let cosPitch = cos(pose.pitch), sinPitch = sin(pose.pitch)
        let y = point.y * cosPitch - turned * sinPitch
        let depth = max(0.2, point.y * sinPitch + turned * cosPitch + pose.distance)
        let scale = focal / depth
        return CGPoint(x: pose.vanishing.x + x * scale, y: pose.vanishing.y + y * scale)
    }

    private static let unitPaths: [SacredGeometry.Figure: CGPath] = {
        var paths: [SacredGeometry.Figure: CGPath] = [:]
        SacredGeometry.Figure.allCases.forEach { paths[$0] = SacredGeometry.path(for: $0, radius: 1) }
        return paths
    }()

    /// How visible a gate is at a distance from the lens: faint far off, gone as it passes.
    public static func gateOpacity(depth: CGFloat) -> CGFloat {
        let far = unit(1 - (depth - endDistance) / (startDistance * 0.95))
        let near = unit((depth - nearPlane) / 2.2)
        return (0.10 + 0.75 * far) * near
    }

    func gateStroke(_ gate: Gate, pose: Pose) -> Stroke {
        let z = -Self.startDistance * gate.station
        // A gate behind the lens keeps the shape it left with, so its points stay finite.
        var held = pose
        held.distance = max(pose.distance, Self.nearPlane - z)
        let depth = z + pose.distance
        let reach = Self.unit(1 - (max(depth, Self.nearPlane) - 1) / (Self.startDistance * 0.55))
        let roll = gate.roll * (1 - Self.easeOut(reach))
        let cosRoll = cos(roll), sinRoll = sin(roll)
        let path = (Self.unitPaths[gate.figure] ?? CGMutablePath()).mapPoints { point in
            project(CGPoint(x: (point.x * cosRoll - point.y * sinRoll) * gate.radius,
                            y: (point.x * sinRoll + point.y * cosRoll) * gate.radius), z: z, pose: held)
        }
        let visibleDepth = max(depth, Self.nearPlane)
        let width = max(0.5, gate.weight * min(2, focal / visibleDepth / 44 * 0.8 + 0.5))
        return Stroke(path: path, opacity: depth > Self.nearPlane ? Self.gateOpacity(depth: depth) * pose.fade : 0,
                      lineWidth: width)
    }

    public func frame(_ phase: Phase, at time: CGFloat) -> Frame {
        let pose = pose(phase, at: time)
        let worldRing = ringRadius * Self.endDistance / focal
        let lockPath = (Self.unitPaths[.seed] ?? CGMutablePath()).mapPoints { point in
            project(CGPoint(x: point.x * worldRing, y: point.y * worldRing), z: 0, pose: pose)
        }
        return Frame(gates: Self.gates.map { gateStroke($0, pose: pose) },
                     lock: Stroke(path: lockPath, opacity: 0.5 * pose.lock, lineWidth: 0.8),
                     planetCentre: project(.zero, z: 0, pose: pose),
                     planetRadius: planetRadius * Self.endDistance / pose.distance,
                     planetOpacity: pose.fade,
                     vanishing: pose.vanishing)
    }
}

extension CGPath {
    /// The same path with every point moved. The elements stay as they are, so two results can be blended.
    func mapPoints(_ move: (CGPoint) -> CGPoint) -> CGPath {
        let result = CGMutablePath()
        applyWithBlock { pointer in
            let element = pointer.pointee
            switch element.type {
            case .moveToPoint:
                result.move(to: move(element.points[0]))
            case .addLineToPoint:
                result.addLine(to: move(element.points[0]))
            case .addQuadCurveToPoint:
                result.addQuadCurve(to: move(element.points[1]), control: move(element.points[0]))
            case .addCurveToPoint:
                result.addCurve(to: move(element.points[2]), control1: move(element.points[0]),
                                control2: move(element.points[1]))
            case .closeSubpath:
                result.closeSubpath()
            @unknown default:
                break
            }
        }
        return result
    }
}
