import Foundation
import simd

/// The flight through the gate of heaven (天門), as the numbers the shader is given each frame.
///
/// The camera comes down a corridor of torii, stops in front of the last seal (the diviner's board, whose
/// inner plate turns while the wallet gets ready), then goes through to the planet as day breaks into the
/// page. Android computes the same numbers.
public struct SacredTenmonScene: Equatable {
    public enum Phase: Equatable {
        case intro
        case hold
        case outro
    }

    // The scene's measures, in metres. They match the constants in the shader.
    public static let planetZ: Float = 58
    public static let planetRadius: Float = 1.25
    /// Where the camera waits: in front of the last two gates and the board between them.
    public static let holdZ: Float = 30
    public static let eyeHeight: Float = 1.6

    public static let introDuration: TimeInterval = 1.0
    public static let outroDuration: TimeInterval = SacredGeometry.beat(4)
    /// The board's inner plate has twelve marks; it moves on by one each this many seconds.
    public static let hourPeriod: Float = 1.45
    static let hour: Float = .pi / 6

    /// The drawable's size in pixels, and how many of them make a point.
    public let size: SIMD2<Float>
    public let pixelsPerPoint: Float
    /// Where the planet lands and its radius there, in pixels.
    public let landing: SIMD2<Float>
    public let landingRadius: Float
    /// The page day breaks into, as sRGB.
    public let page: SIMD3<Float>
    /// Whether the planet stays when everything else has given way to the page.
    public let keepsPlanet: Bool

    public init(size: SIMD2<Float>, pixelsPerPoint: Float, landing: SIMD2<Float>, landingRadius: Float,
                page: SIMD3<Float>, keepsPlanet: Bool) {
        self.size = size
        self.pixelsPerPoint = pixelsPerPoint
        self.landing = landing
        self.landingRadius = max(1, landingRadius)
        self.page = page
        self.keepsPlanet = keepsPlanet
    }

    /// Lens length in pixels: a wide lens, so the gates rush past. It is set by the width on every
    /// phone. A window that is wide for its height (an unfolded screen, a folded cover) would crop
    /// the gates' beams with that lens, so there it is set by the height: the corridor is seen as
    /// tall as on a phone, with more of the night to either side. No classic iPhone is wider than
    /// 0.6 of its height, so none changes.
    public var focal: Float { 1.15 * min(size.x, size.y * Self.widestFrame) }
    static let widestFrame: Float = 0.6
    /// Where the camera ends: as far from the planet as shows it at its landing size.
    public var endZ: Float { Self.planetZ - focal * Self.planetRadius / landingRadius }

    static func easeInOut(_ t: Float) -> Float { t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2 }
    static func easeOut(_ t: Float) -> Float { 1 - pow(1 - t, 3) }
    static func unit(_ value: Float) -> Float { min(1, max(0, value)) }
    static func smooth(_ from: Float, _ to: Float, _ value: Float) -> Float {
        let t = unit((value - from) / (to - from))
        return t * t * (3 - 2 * t)
    }

    /// The inner plate's turn after waiting `seconds`.
    public static func turn(holding seconds: Float) -> Float { max(0, seconds) / hourPeriod * hour }

    /// The turn during the way through: the plate runs on to its next mark and stops there.
    public static func settledTurn(from turn: Float, progress: Float) -> Float {
        let target = (turn / hour).rounded(.up) * hour
        return turn + (target - turn) * easeOut(unit(progress / 0.4))
    }

    /// - Parameters:
    ///   - progress: 0...1 through the phase (unused while holding).
    ///   - clock: seconds since the scene first drew; the stars and the armillary run on it.
    ///   - turn: the board's inner plate, in radians.
    public func uniforms(_ phase: Phase, progress: Float, clock: Float, turn: Float) -> SacredTenmonUniforms {
        let t = Self.unit(progress)
        let middle = size / 2
        var result = SacredTenmonUniforms()
        result.view = SIMD4(size.x, size.y, clock, pixelsPerPoint)
        result.page = SIMD4(page.x, page.y, page.z, keepsPlanet ? 0 : 1)
        switch phase {
        case .intro:
            let settle = 1 - Self.easeOut(t)
            result.flight = SIMD4(Self.holdZ * Self.easeInOut(t), Self.eyeHeight, 0.05 * settle, 0.035 * settle)
            result.lens = SIMD4(middle.x, middle.y, focal, -0.05 * settle)
            result.state = SIMD4(Self.unit(t / 0.22), 0, turn, 0)
        case .hold:
            result.flight = SIMD4(Self.holdZ, Self.eyeHeight, 0, 0)
            result.lens = SIMD4(middle.x, middle.y, focal, 0)
            result.state = SIMD4(1, 0, turn, 0)
        case .outro:
            let move = Self.easeInOut(t)
            let centre = middle + (landing - middle) * move
            result.flight = SIMD4(Self.holdZ + (endZ - Self.holdZ) * move, Self.eyeHeight, 0, 0)
            result.lens = SIMD4(centre.x, centre.y, focal, 0)
            result.state = SIMD4(1, Self.easeOut(Self.unit((t - 0.15) / 0.7)), turn, Self.smooth(0.62, 1, t))
        }
        return result
    }
}
