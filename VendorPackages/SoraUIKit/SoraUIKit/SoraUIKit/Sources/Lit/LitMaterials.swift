import CoreMotion
import CoreText
import UIKit

// One world, one light, two colours. The app is white and SORA red: a washi page, sheets of frosted glass
// lying over it, soft controls raised from or let into those sheets, and cut red glass for the one thing a
// screen is for. Everything is lit by the same window at the top left: light gathers on the near
// edges, shade falls to the bottom right. The materials are rendered per pixel once and cached, so nothing
// here costs an offscreen pass while the page scrolls.

/// The material palette: white paper and glass, sumi ink, SORA red.
public enum Lit {
    // White
    public static let page = UIColor(litHex: 0xECE9E3)
    /// Frosted glass over the page, as one flat colour: for surfaces with no sheet of their own.
    public static let surface = UIColor(litHex: 0xF6F4F0)
    /// A raised pad, where it faces the light and where it turns away.
    public static let padLit = UIColor(litHex: 0xFDFCFA)
    public static let padShade = UIColor(litHex: 0xEFEDE8)
    public static let wellFloor = UIColor(litHex: 0xE4E1DA)

    // Ink
    public static let ink = UIColor(litHex: 0x232220)
    public static let inkSecondary = UIColor(litHex: 0x4C4A45)
    public static let inkTertiary = UIColor(litHex: 0x66625A)
    /// A ruled line between rows.
    public static let rule = UIColor(litHex: 0x232220, alpha: 0.10)
    /// The boundary of something that takes input.
    public static let outline = UIColor(litHex: 0x817B70)

    // Red: the red of the SORA mark, a tone deeper where white type sits on it
    public static let brandRed = UIColor(litHex: 0xE3232C)
    public static let lacquerRed = UIColor(litHex: 0xDA2530)
    public static let lacquerDeep = UIColor(litHex: 0x9E1620)
    public static let lacquerBright = UIColor(litHex: 0xF2403F)
    /// The red as ink: glyphs and labels on white.
    public static let lacquerText = UIColor(litHex: 0xC21C26)
    /// The white set into red: glyphs and labels on it.
    public static let inlay = UIColor(litHex: 0xFFFAF2)

    /// The key light in the page's plane (towards the light), unit length.
    public static let keyX: CGFloat = -0.6
    public static let keyY: CGFloat = -0.8

    /// Corners: a sheet of glass, and a control on it.
    public static let sheetRadius: CGFloat = 18
    public static let controlRadius: CGFloat = 12
}

public extension UIColor {
    convenience init(litHex rgb: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255, green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255, alpha: alpha)
    }
}

// MARK: - The pixel renderer

/// Renders small images per pixel. `shade` returns premultiplied sRGB in 0...1.
enum LitBaker {
    static func render(pointSize: CGSize, scale: CGFloat, shade: (_ x: Float, _ y: Float) -> SIMD4<Float>) -> CGImage? {
        let width = Int((pointSize.width * scale).rounded(.up))
        let height = Int((pointSize.height * scale).rounded(.up))
        guard width > 0, height > 0 else { return nil }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let step = Float(1 / scale)
        pixels.withUnsafeMutableBufferPointer { buffer in
            for row in 0..<height {
                let y = (Float(row) + 0.5) * step
                for column in 0..<width {
                    let x = (Float(column) + 0.5) * step
                    let value = shade(x, y)
                    let index = (row * width + column) * 4
                    buffer[index] = UInt8(clamping: Int(value.x * 255 + 0.5))
                    buffer[index + 1] = UInt8(clamping: Int(value.y * 255 + 0.5))
                    buffer[index + 2] = UInt8(clamping: Int(value.z * 255 + 0.5))
                    buffer[index + 3] = UInt8(clamping: Int(value.w * 255 + 0.5))
                }
            }
        }
        let data = Data(pixels) as CFData
        guard let provider = CGDataProvider(data: data) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                       space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    /// Signed distance to a rounded rectangle (negative inside), with the outward direction.
    @inline(__always)
    static func roundedRect(_ x: Float, _ y: Float, width: Float, height: Float, radius: Float)
        -> (distance: Float, nx: Float, ny: Float) {
        let hx = width / 2, hy = height / 2
        let px = x - hx, py = y - hy
        let qx = abs(px) - hx + radius, qy = abs(py) - hy + radius
        let ox = max(qx, 0), oy = max(qy, 0)
        let outside = (ox * ox + oy * oy).squareRoot()
        let distance = outside + min(max(qx, qy), 0) - radius
        var nx: Float, ny: Float
        if outside > 0.0001 {
            nx = ox / outside * (px < 0 ? -1 : 1)
            ny = oy / outside * (py < 0 ? -1 : 1)
        } else if qx > qy {
            nx = px < 0 ? -1 : 1
            ny = 0
        } else {
            nx = 0
            ny = py < 0 ? -1 : 1
        }
        return (distance, nx, ny)
    }

    @inline(__always) static func sat(_ v: Float) -> Float { min(max(v, 0), 1) }

    @inline(__always) static func smooth(_ a: Float, _ b: Float, _ v: Float) -> Float {
        let t = sat((v - a) / (b - a))
        return t * t * (3 - 2 * t)
    }

    @inline(__always) static func over(_ top: SIMD4<Float>, _ bottom: SIMD4<Float>) -> SIMD4<Float> {
        top + bottom * (1 - top.w)
    }

    /// A straight colour at an opacity, premultiplied.
    @inline(__always) static func tint(_ r: Float, _ g: Float, _ b: Float, _ a: Float) -> SIMD4<Float> {
        SIMD4(r * a, g * a, b * a, a)
    }

    @inline(__always) static func tint(_ c: SIMD3<Float>, _ a: Float) -> SIMD4<Float> {
        SIMD4(c.x * a, c.y * a, c.z * a, a)
    }

    @inline(__always) static func mix(_ a: Float, _ b: Float, _ t: Float) -> Float { a + (b - a) * t }

    @inline(__always) static func mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ t: Float) -> SIMD3<Float> { a + (b - a) * t }

    @inline(__always) static func unit(_ v: SIMD3<Float>) -> SIMD3<Float> { v / max((v * v).sum().squareRoot(), 1e-6) }

    @inline(__always) static func dot(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float { (a * b).sum() }

    static func linear(_ c: SIMD3<Float>) -> SIMD3<Float> { SIMD3(pow(c.x, 2.2), pow(c.y, 2.2), pow(c.z, 2.2)) }

    static func srgb(_ c: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3(pow(sat(c.x), 1 / 2.2), pow(sat(c.y), 1 / 2.2), pow(sat(c.z), 1 / 2.2))
    }

    /// A gentle shoulder, so highlights roll off instead of clipping.
    @inline(__always) static func film(_ c: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3(c.x / (1 + 0.18 * c.x), c.y / (1 + 0.18 * c.y), c.z / (1 + 0.18 * c.z)) * 1.14
    }

    /// An integer hash, the same on both apps (wrapping 32-bit arithmetic), in 0...1.
    @inline(__always) static func hash(_ x: Int32, _ y: Int32) -> Float {
        var h = UInt32(bitPattern: x) &* 374_761_393 &+ UInt32(bitPattern: y) &* 668_265_263
        h = (h ^ (h >> 13)) &* 1_274_126_177
        h ^= h >> 16
        return Float(h & 0xFFFFFF) / 16_777_215
    }

    /// Value noise in 0...1 that repeats every `period` cells.
    static func noise(_ x: Float, _ y: Float, period: Int32, seed: Int32) -> Float {
        let xf = x.rounded(.down), yf = y.rounded(.down)
        let fx = x - xf, fy = y - yf
        let xi = Int32(xf), yi = Int32(yf)
        @inline(__always) func wrap(_ v: Int32) -> Int32 { ((v % period) + period) % period }
        let a = hash(wrap(xi) &+ seed, wrap(yi)), b = hash(wrap(xi + 1) &+ seed, wrap(yi))
        let c = hash(wrap(xi) &+ seed, wrap(yi + 1)), d = hash(wrap(xi + 1) &+ seed, wrap(yi + 1))
        let ux = fx * fx * (3 - 2 * fx), uy = fy * fy * (3 - 2 * fy)
        return mix(mix(a, b, ux), mix(c, d, ux), uy)
    }

    /// Towards the window, with z towards the viewer.
    static let key = unit(SIMD3<Float>(-0.46, -0.62, 0.63))
    static let half = unit(key + SIMD3<Float>(0, 0, 1))
}

/// A coverage mask, row 0 at the top. Blurred, its slope is the relief of an inlay.
struct LitMask {
    let width: Int
    let height: Int
    let scale: Float
    var a: [Float]

    @inline(__always) func at(_ x: Float, _ y: Float) -> Float {
        let fx = x * scale - 0.5, fy = y * scale - 0.5
        let x0 = Int(fx.rounded(.down)), y0 = Int(fy.rounded(.down))
        let tx = fx - Float(x0), ty = fy - Float(y0)
        @inline(__always) func sample(_ xx: Int, _ yy: Int) -> Float {
            guard xx >= 0, yy >= 0, xx < width, yy < height else { return 0 }
            return a[yy * width + xx]
        }
        let top = sample(x0, y0) + (sample(x0 + 1, y0) - sample(x0, y0)) * tx
        let bottom = sample(x0, y0 + 1) + (sample(x0 + 1, y0 + 1) - sample(x0, y0 + 1)) * tx
        return top + (bottom - top) * ty
    }

    func blurred(_ radius: Int) -> LitMask {
        guard radius > 0 else { return self }
        var out = self
        var scratch = a
        let window = Float(2 * radius + 1)
        for _ in 0..<2 {
            for y in 0..<height {
                for x in 0..<width {
                    var sum: Float = 0
                    for k in -radius...radius { sum += out.a[y * width + min(max(x + k, 0), width - 1)] }
                    scratch[y * width + x] = sum / window
                }
            }
            for y in 0..<height {
                for x in 0..<width {
                    var sum: Float = 0
                    for k in -radius...radius { sum += scratch[min(max(y + k, 0), height - 1) * width + x] }
                    out.a[y * width + x] = sum / window
                }
            }
        }
        return out
    }

    /// The coverage of `image`, centred in a box of `size` points.
    static func of(_ image: UIImage, in size: CGSize, scale: CGFloat) -> LitMask? {
        let width = Int((size.width * scale).rounded(.up)), height = Int((size.height * scale).rounded(.up))
        guard width > 0, height > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        let drawn = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let fitted = image.size
            image.draw(in: CGRect(x: (size.width - fitted.width) / 2, y: (size.height - fitted.height) / 2,
                                  width: fitted.width, height: fitted.height))
        }
        guard let source = drawn.cgImage,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = context.data else { return nil }
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
        let bytes = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        var coverage = [Float](repeating: 0, count: width * height)
        for index in 0..<(width * height) { coverage[index] = Float(bytes[index * 4 + 3]) / 255 }
        return LitMask(width: width, height: height, scale: Float(scale), a: coverage)
    }
}

// MARK: - Cached images

enum LitImages {
    private static let cache = NSCache<NSString, UIImage>()

    private static func cached(_ key: String, make: () -> CGImage?) -> CGImage? {
        if let image = cache.object(forKey: key as NSString) { return image.cgImage }
        guard let image = make() else { return nil }
        cache.setObject(UIImage(cgImage: image), forKey: key as NSString)
        return image
    }

    private static func color(_ c: UIColor) -> SIMD3<Float> {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return SIMD3(Float(r), Float(g), Float(b))
    }

    // MARK: Glass

    /// What a sheet of frosted glass casts on the page. Glass lets light through, so its shadow is wide,
    /// soft and lighter than a solid thing's, with a line of contact; along its near edges a little light
    /// spills onto the page. Empty where the sheet lies. Stretches in its centre.
    static func glassShadow(radius: CGFloat, lift: CGFloat, scale: CGFloat) -> (image: CGImage, margin: CGFloat)? {
        let margin = ceil(22 * lift / 16) + 4
        let inner = 2 * radius + 2
        let side = inner + 2 * margin
        let bakeScale = min(scale, 2)
        let key = "glassShadow|\(radius)|\(lift)|\(bakeScale)"
        let made = cached(key) {
            let k = Float(lift / 16), m = Float(margin), s = Float(inner), r = Float(radius)
            let aa = 0.6 / Float(bakeScale)
            return LitBaker.render(pointSize: CGSize(width: side, height: side), scale: bakeScale) { x, y in
                let px = x - m, py = y - m
                let shape = LitBaker.roundedRect(px, py, width: s, height: s, radius: r)
                let coverage = LitBaker.smooth(aa, -aa, shape.distance)
                guard coverage < 1 else { return .zero }
                let far = LitBaker.roundedRect(px - 2.5 * k, py - 7 * k, width: s, height: s, radius: r)
                let near = LitBaker.roundedRect(px - 0.6, py - 1.3, width: s, height: s, radius: r)
                let spill = LitBaker.roundedRect(px + 1.2, py + 1.6, width: s, height: s, radius: r)
                var out = LitBaker.tint(0.30, 0.24, 0.18, 0.17 * LitBaker.smooth(20 * k, -6 * k, far.distance))
                out = LitBaker.over(LitBaker.tint(0.26, 0.20, 0.15, 0.16 * LitBaker.smooth(2.0, -0.6, near.distance)), out)
                out = LitBaker.over(LitBaker.tint(1, 1, 1, 0.55 * LitBaker.smooth(3.0, -0.5, spill.distance)), out)
                return out * (1 - coverage)
            }
        }
        guard let made else { return nil }
        return (made, margin)
    }

    /// How far an edge overlay reaches into a face.
    static let edgeInset: CGFloat = 4

    /// The polished edge of a glass sheet, as an overlay on its face: a bright line where it faces the light
    /// and just inside it the dark hairline of the glass's own thickness; on the far sides a dim rim with a
    /// line of light leaving the glass.
    static func glassEdge(radius: CGFloat, scale: CGFloat) -> CGImage? {
        let side = 2 * radius + 2 * edgeInset + 2
        let key = "glassEdge|\(radius)|\(scale)"
        return cached(key) {
            let s = Float(side), r = Float(radius)
            let aa = 0.6 / Float(scale)
            return LitBaker.render(pointSize: CGSize(width: side, height: side), scale: scale) { x, y in
                let shape = LitBaker.roundedRect(x, y, width: s, height: s, radius: r)
                let coverage = LitBaker.smooth(aa, -aa, shape.distance)
                let d = shape.distance
                guard coverage > 0, d > -3.4 else { return .zero }
                let facing = shape.nx * LitBaker.key.x + shape.ny * LitBaker.key.y
                var out: SIMD4<Float>
                if facing > 0 {
                    out = LitBaker.tint(1, 1, 1, LitBaker.smooth(-1.6, -0.2, d) * (0.70 + 0.30 * facing))
                    out = LitBaker.over(LitBaker.tint(0.35, 0.30, 0.26, LitBaker.smooth(-3.0, -2.3, d) * LitBaker.smooth(-1.5, -2.2, d) * 0.16 * facing), out)
                } else {
                    out = LitBaker.tint(0.42, 0.36, 0.30, LitBaker.smooth(-1.2, -0.1, d) * 0.16 * -facing)
                    out = LitBaker.over(LitBaker.tint(1, 1, 1, LitBaker.smooth(-2.4, -1.8, d) * LitBaker.smooth(-1.1, -1.7, d) * 0.60 * -facing), out)
                }
                return out * coverage
            }
        }
    }

    // MARK: Soft pads

    /// What a soft raised pad does to the surface round it: light spills up and left of it, shade falls
    /// down and right, and it touches the surface along its far edge. Empty where the pad is.
    static func padShadow(radius: CGFloat, lift: CGFloat, scale: CGFloat) -> (image: CGImage, margin: CGFloat)? {
        let margin = ceil(lift) + 3
        let inner = 2 * radius + 2
        let side = inner + 2 * margin
        let key = "padShadow|\(radius)|\(lift)|\(scale)"
        let made = cached(key) {
            let k = Float(lift / 14), m = Float(margin), s = Float(inner), r = Float(radius)
            let aa = 0.6 / Float(scale)
            return LitBaker.render(pointSize: CGSize(width: side, height: side), scale: scale) { x, y in
                let px = x - m, py = y - m
                let shape = LitBaker.roundedRect(px, py, width: s, height: s, radius: r)
                let coverage = LitBaker.smooth(aa, -aa, shape.distance)
                guard coverage < 1 else { return .zero }
                let light = LitBaker.roundedRect(px + 2.5 * k, py + 3.0 * k, width: s, height: s, radius: r)
                let shade = LitBaker.roundedRect(px - 3.5 * k, py - 4.5 * k, width: s, height: s, radius: r)
                let contact = LitBaker.roundedRect(px - 0.6, py - 1.0, width: s, height: s, radius: r)
                var out = LitBaker.tint(1, 1, 1, 0.92 * LitBaker.smooth(8 * k, -1, light.distance))
                out = LitBaker.over(LitBaker.tint(0.40, 0.34, 0.28, 0.27 * LitBaker.smooth(12 * k, -2, shade.distance)), out)
                out = LitBaker.over(LitBaker.tint(0.30, 0.24, 0.18, 0.20 * LitBaker.smooth(1.6, -0.5, contact.distance)), out)
                return out * (1 - coverage)
            }
        }
        guard let made else { return nil }
        return (made, margin)
    }

    /// A raised pad's soft quarter-round edge, as an overlay on its face.
    static func padEdge(radius: CGFloat, scale: CGFloat) -> CGImage? {
        let side = 2 * radius + 2 * edgeInset + 2
        let key = "padEdge|\(radius)|\(scale)"
        return cached(key) {
            let s = Float(side), r = Float(radius)
            let aa = 0.6 / Float(scale)
            return LitBaker.render(pointSize: CGSize(width: side, height: side), scale: scale) { x, y in
                let shape = LitBaker.roundedRect(x, y, width: s, height: s, radius: r)
                let coverage = LitBaker.smooth(aa, -aa, shape.distance)
                guard coverage > 0, shape.distance > -3.4 else { return .zero }
                let facing = shape.nx * LitBaker.key.x + shape.ny * LitBaker.key.y
                let edge = LitBaker.smooth(-3.2, 0, shape.distance)
                let out = facing > 0 ? LitBaker.tint(1, 1, 1, edge * facing * 0.9) : LitBaker.tint(0.62, 0.57, 0.52, edge * -facing * 0.20)
                return out * coverage
            }
        }
    }

    /// The corner a well's image stretches from.
    static func wellCorner(radius: CGFloat, depth: CGFloat) -> CGFloat { max(radius, depth * 4) }

    /// A pad let into the surface: a floor a shade darker, shaded under its near lip, its far lip lit.
    /// `floor` is nil for the usual floor; `ruled` adds a solid boundary.
    static func well(radius: CGFloat, depth: CGFloat, scale: CGFloat, floor: UIColor?, ruled: Bool) -> CGImage? {
        let corner = wellCorner(radius: radius, depth: depth)
        let side = 2 * corner + 2 / scale
        let tintKey = floor.map { "\($0.cgColor.components ?? [])" } ?? "none"
        let key = "well|\(radius)|\(depth)|\(scale)|\(tintKey)|\(ruled)"
        return cached(key) {
            let s = Float(side), r = Float(radius), d = Float(depth)
            let base = floor.map(color) ?? color(Lit.wellFloor)
            let outline = color(Lit.outline)
            let aa = 0.6 / Float(scale)
            return LitBaker.render(pointSize: CGSize(width: side, height: side), scale: scale) { x, y in
                let shape = LitBaker.roundedRect(x, y, width: s, height: s, radius: r)
                let coverage = LitBaker.smooth(aa, -aa, shape.distance)
                guard coverage > 0 else { return .zero }
                let facing = shape.nx * LitBaker.key.x + shape.ny * LitBaker.key.y
                let inward = -shape.distance
                let cast = exp(-inward / (d * 1.3)) * LitBaker.sat(facing * 0.8 + 0.35)
                var c = LitBaker.mix(base, SIMD3<Float>(0.45, 0.39, 0.33), cast * 0.38)
                let lip = exp(-inward / (d * 0.65)) * LitBaker.sat(-facing)
                c = LitBaker.mix(c, SIMD3<Float>(1, 1, 1), lip * 0.75)
                // Something that takes input keeps a boundary that does not depend on the light.
                if ruled { c = LitBaker.mix(c, outline, LitBaker.smooth(-1.25, -0.85, shape.distance) * 0.92) }
                return SIMD4<Float>(c, 1) * coverage
            }
        }
    }

    // MARK: Cut glass

    /// Cut glass of a colour: a slab with four polished facets. The table is deep where the light enters and
    /// bright where it gathers low in the glass; each facet is flat, so it has one brightness, set by which
    /// way it faces; and the light that went through comes out as a pool of the glass's colour on the surface
    /// beyond its far edge. `mask` is inlaid in white, centred. The image adds `margin` round the slab.
    private static func cutGlass(width: CGFloat, height: CGFloat, radius: CGFloat, base: UIColor, pressed: Bool, mask: LitMask?,
                                 scale: CGFloat, margin: CGFloat) -> CGImage? {
        let w = Float(width), h = Float(height), r = Float(radius), m = Float(margin)
        let aa = 0.6 / Float(scale)
        let bevel = min(1.9, Float(min(width, height)) * 0.08)
        let red = LitBaker.linear(color(base))
        let deep = red * 0.47
        let bright = red * 1.34 + SIMD3<Float>(repeating: 0.022)
        let table = red * 0.90
        let low = red * 1.14 + SIMD3<Float>(repeating: 0.006)
        let facetLit = LitBaker.mix(bright, SIMD3<Float>(1, 0.84, 0.76), 0.30)
        let glow = bright * 0.30
        let pool = LitBaker.srgb(LitBaker.mix(bright, SIMD3<Float>(1, 1, 1), 0.10))
        let white = LitBaker.linear(color(Lit.inlay))
        let bed = mask?.blurred(max(1, Int((scale * 0.4).rounded())))
        let lift: Float = pressed ? 0.4 : 1
        return LitBaker.render(pointSize: CGSize(width: width + 2 * margin, height: height + 2 * margin), scale: scale) { x, y in
            let px = x - m, py = y - m
            let near = LitBaker.roundedRect(px - 0.7 * lift, py - 1.4 * lift, width: w, height: h, radius: r)
            let far = LitBaker.roundedRect(px - 1.6 * lift, py - 4.2 * lift, width: w, height: h, radius: r)
            var out = LitBaker.tint(0.20, 0.08, 0.05, 0.32 * LitBaker.smooth(1.8, -0.7, near.distance))
            out = LitBaker.over(LitBaker.tint(0.28, 0.10, 0.06, 0.15 * lift * LitBaker.smooth(7, -2.5, far.distance)), out)
            let spread = LitBaker.roundedRect(px - 3 - 2.2 * lift, py - 2 - 5.5 * lift, width: w - 6, height: h - 4, radius: max(r - 2, 1))
            out = LitBaker.over(out, LitBaker.tint(pool, 0.15 * lift * LitBaker.smooth(8, -1, spread.distance)))
            let shape = LitBaker.roundedRect(px, py, width: w, height: h, radius: r)
            let coverage = LitBaker.smooth(aa, -aa, shape.distance)
            guard coverage > 0 else { return out }
            let facing = shape.nx * LitBaker.key.x + shape.ny * LitBaker.key.y
            var c: SIMD3<Float>
            if shape.distance > -bevel {
                c = LitBaker.mix(deep * 0.55, facetLit, LitBaker.smooth(0.15, 0.95, facing * 0.5 + 0.5))
                // The arris between facet and table glints on the lit sides.
                let arris = LitBaker.smooth(-bevel - 0.45, -bevel + 0.1, shape.distance) * LitBaker.smooth(-bevel + 0.75, -bevel + 0.15, shape.distance)
                c += SIMD3<Float>(1, 0.92, 0.86) * (arris * LitBaker.sat(facing) * 0.55)
                c *= 1 - arris * LitBaker.sat(-facing) * 0.35
            } else {
                c = LitBaker.mix(table, low, LitBaker.smooth(0, 1, py / h))
                let inward = -shape.distance - bevel
                c += glow * (exp(-inward / 3.5) * LitBaker.sat(-facing * 0.9 + 0.1) * 0.8)
            }
            if pressed { c *= 0.86 }
            var pixel = SIMD4<Float>(LitBaker.srgb(LitBaker.film(c * 1.02)), 1)
            if let mask, let bed { pixel = LitBaker.over(inlay(mask, bed, px, py, base: white, cast: 0.10), pixel) }
            return LitBaker.over(pixel * coverage, out)
        }
    }

    /// What a cut-glass image adds round the slab.
    static let cutGlassMargin: CGFloat = 16
    /// How far in from a button's ends its cut-glass image stops varying, beyond its corner.
    static let cutGlassCap: CGFloat = 4

    /// A filled button's face in cut glass, stretched in its centre along its length.
    static func cutGlassBar(height: CGFloat, radius: CGFloat, base: UIColor, pressed: Bool, scale: CGFloat) -> CGImage? {
        let key = "cutBar|\(height)|\(radius)|\(base.cgColor.components ?? [])|\(pressed)|\(scale)"
        return cached(key) {
            cutGlass(width: 2 * (radius + cutGlassCap) + 2, height: height, radius: radius, base: base, pressed: pressed, mask: nil,
                     scale: scale, margin: cutGlassMargin)
        }
    }

    /// A cut-glass piece of a fixed size with a glyph inlaid in white.
    static func cutGlassPiece(size: CGSize, radius: CGFloat, base: UIColor, glyph: UIImage?, glyphKey: String, pressed: Bool,
                              scale: CGFloat) -> CGImage? {
        let key = "cutPiece|\(size.width)|\(size.height)|\(radius)|\(base.cgColor.components ?? [])|\(glyphKey)|\(pressed)|\(scale)"
        return cached(key) {
            cutGlass(width: size.width, height: size.height, radius: radius, base: base, pressed: pressed,
                     mask: glyph.flatMap { LitMask.of($0, in: size, scale: scale) }, scale: scale, margin: cutGlassMargin)
        }
    }

    /// A bead of red glass: dark toward the light, bright where the light comes out low on the far
    /// side, with its small shadow and the red it throws. For a PIN place that has been filled.
    static func bead(diameter: CGFloat, scale: CGFloat) -> (image: CGImage, margin: CGFloat)? {
        let margin: CGFloat = 6
        let side = diameter + 2 * margin
        let key = "bead|\(diameter)|\(scale)"
        let made = cached(key) {
            let R = Float(diameter / 2), c = Float(side / 2)
            let aa = 0.6 / Float(scale)
            let deep = LitBaker.linear(color(Lit.lacquerDeep)), bright = LitBaker.linear(color(Lit.lacquerBright))
            return LitBaker.render(pointSize: CGSize(width: side, height: side), scale: scale) { x, y in
                let dx = x - c, dy = y - c
                let dist = (dx * dx + dy * dy).squareRoot()
                let sx = dx - R * 0.16, sy = dy - R * 0.30
                var out = LitBaker.tint(0.25, 0.08, 0.05, 0.36 * LitBaker.smooth(R * 1.25, R * 0.70, (sx * sx + sy * sy).squareRoot()))
                let gx = dx - R * 0.30, gy = dy - R * 0.55
                out = LitBaker.over(out, LitBaker.tint(0.96, 0.30, 0.18, 0.34 * LitBaker.smooth(R * 1.5, R * 0.5, (gx * gx + gy * gy).squareRoot())))
                let coverage = LitBaker.smooth(R + aa, R - aa, dist)
                guard coverage > 0 else { return out }
                let q = dist / R
                let nz = max(1 - q * q, 0).squareRoot()
                let n = SIMD3<Float>(dx / R, dy / R, nz)
                let gather = LitBaker.sat(0.5 + 0.55 * (n.x * 0.6 + n.y * 0.8))
                var col = LitBaker.mix(deep, bright, pow(gather, 1.3)) * (1 - 0.45 * pow(q, 4))
                let fresnel = 0.05 + 0.95 * pow(1 - nz, 5)
                col += SIMD3<Float>(1, 0.97, 0.94) * (pow(LitBaker.sat(LitBaker.dot(n, LitBaker.half)), 48) * 0.85) + SIMD3<Float>(repeating: 0.10 * fresnel)
                return LitBaker.over(SIMD4<Float>(LitBaker.srgb(LitBaker.film(col)), 1) * coverage, out)
            }
        }
        guard let made else { return nil }
        return (made, margin)
    }

    /// A white inlay set flush in coloured glass: soft-edged, its far side shaded, with the faint shade it
    /// casts beside itself. `x`, `y` are in the mask's points.
    @inline(__always)
    private static func inlay(_ crisp: LitMask, _ bed: LitMask, _ x: Float, _ y: Float, base: SIMD3<Float>, cast shade: Float) -> SIMD4<Float> {
        let a = crisp.at(x, y)
        let cast = bed.at(x - 0.35, y - 0.55) * shade
        let out = LitBaker.tint(0.16, 0.03, 0.02, cast * (1 - a))
        guard a > 0.002 else { return out }
        let e = 1 / crisp.scale
        let gx = (bed.at(x + e, y) - bed.at(x - e, y)) / (2 * e)
        let gy = (bed.at(x, y + e) - bed.at(x, y - e)) / (2 * e)
        let n = LitBaker.unit(SIMD3(-gx * 1.5, -gy * 1.5, 1))
        var c = base * (0.80 + 0.26 * (LitBaker.dot(n, LitBaker.key) - LitBaker.key.z))
        c *= 0.985 + 0.03 * LitBaker.hash(Int32(x * crisp.scale), Int32(y * crisp.scale))
        return LitBaker.over(LitBaker.tint(LitBaker.srgb(c), a), out)
    }

    /// The die-cut edge of a round printed mark: lit on the near side, shaded on the far side. Flat otherwise.
    static func coin(diameter: CGFloat, scale: CGFloat) -> CGImage? {
        let key = "coin|\(diameter)|\(scale)"
        return cached(key) {
            let R = Float(diameter / 2)
            let aa = 0.6 / Float(scale)
            return LitBaker.render(pointSize: CGSize(width: diameter, height: diameter), scale: scale) { x, y in
                let dx = x - R, dy = y - R
                let dist = (dx * dx + dy * dy).squareRoot()
                let coverage = LitBaker.smooth(R + aa, R - aa, dist)
                guard coverage > 0 else { return .zero }
                let l = max(dist, 0.0001)
                let facing = dx / l * LitBaker.key.x + dy / l * LitBaker.key.y
                let rim = LitBaker.smooth(R - 1.1, R - 0.2, dist)
                let out = facing > 0 ? LitBaker.tint(1, 1, 1, rim * facing * 0.55) : LitBaker.tint(0.16, 0.10, 0.06, rim * -facing * 0.26)
                return out * coverage
            }
        }
    }

    /// A printed mark's contact shadow on the sheet.
    static func coinShadow(diameter: CGFloat, scale: CGFloat) -> (image: CGImage, margin: CGFloat)? {
        let margin: CGFloat = 3
        let side = diameter + 2 * margin
        let key = "coinShadow|\(diameter)|\(scale)"
        let made = cached(key) {
            let R = Float(diameter / 2), c = Float(side / 2)
            return LitBaker.render(pointSize: CGSize(width: side, height: side), scale: scale) { x, y in
                let dx = x - c - 0.35, dy = y - c - 0.8
                let d = (dx * dx + dy * dy).squareRoot()
                return LitBaker.tint(0.20, 0.14, 0.09, 0.26 * LitBaker.smooth(R + 1.3, R - 0.9, d))
            }
        }
        guard let made else { return nil }
        return (made, margin)
    }

    /// A dot of ink on paper: flat, a touch fuller at its edge where the ink pools. For status and legend marks.
    static func dot(color c: UIColor, diameter: CGFloat, scale: CGFloat) -> (image: CGImage, margin: CGFloat)? {
        let margin: CGFloat = 1
        let side = diameter + 2 * margin
        let key = "dot|\(c.cgColor.components ?? [])|\(diameter)|\(scale)"
        let made = cached(key) {
            let ink = color(c)
            let R = Float(diameter / 2), mid = Float(side / 2)
            let aa = 0.6 / Float(scale)
            return LitBaker.render(pointSize: CGSize(width: side, height: side), scale: scale) { x, y in
                let dx = x - mid, dy = y - mid
                let d = (dx * dx + dy * dy).squareRoot()
                let coverage = LitBaker.smooth(R + aa, R - aa, d)
                guard coverage > 0 else { return .zero }
                let pooled = 1 - 0.10 * LitBaker.smooth(R * 0.55, R, d)
                return SIMD4<Float>(ink * pooled, 1) * coverage
            }
        }
        guard let made else { return nil }
        return (made, margin)
    }

    /// A tile of handmade paper: clouded pulp, long kōzo fibres, a few flecks of bark. Repeats every `tile` points.
    static let paperTile: CGFloat = 192

    static func washi(base: UIColor, fibres: Int, flecks: Int, strength: CGFloat, seed: Int32) -> UIImage? {
        let tile = paperTile
        let scale = min(UIScreen.main.scale, 2)
        let stock = color(base)
        let cells = Int32(tile)
        let amount = Float(strength)
        let pixelScale = Float(scale)
        guard let pulp = LitBaker.render(pointSize: CGSize(width: tile, height: tile), scale: scale, shade: { x, y in
            // Pulp gathers unevenly as the sheet is formed.
            let cloud = LitBaker.noise(x / 32, y / 32, period: cells / 32, seed: seed) * 0.6
                + LitBaker.noise(x / 8, y / 8, period: cells / 8, seed: seed &+ 7) * 0.4
            let grain = LitBaker.hash(Int32(x * pixelScale) &+ seed, Int32(y * pixelScale))
            let v = 1 + ((cloud - 0.5) * 0.030 + (grain - 0.5) * 0.016) * amount
            return SIMD4<Float>(LitBaker.sat(stock.x * v), LitBaker.sat(stock.y * v), LitBaker.sat(stock.z * v), 1)
        }) else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        var state = UInt32(bitPattern: seed) &+ 0x9E37_79B9
        func next() -> CGFloat {
            state ^= state << 13
            state ^= state >> 17
            state ^= state << 5
            return CGFloat(state & 0xFFFFFF) / 16_777_215
        }
        let offsets: [CGFloat] = [-tile, 0, tile]
        return UIGraphicsImageRenderer(size: CGSize(width: tile, height: tile), format: format).image { context in
            let cg = context.cgContext
            UIImage(cgImage: pulp, scale: scale, orientation: .up).draw(in: CGRect(x: 0, y: 0, width: tile, height: tile))
            cg.setLineCap(.round)
            for index in 0..<fibres {
                let x0 = next() * tile, y0 = next() * tile
                let angle = next() * .pi * 2
                let length = 20 + next() * next() * 120
                let bend = (next() - 0.5) * length * 0.14
                let width = 0.20 + next() * 0.35
                let light = index % 5 != 0
                let alpha = (light ? 0.12 + next() * 0.20 : 0.025 + next() * 0.035) * strength
                let dx = cos(angle) * length, dy = sin(angle) * length
                let cx = x0 + dx / 2 - sin(angle) * bend, cy = y0 + dy / 2 + cos(angle) * bend
                cg.setStrokeColor(light ? UIColor(red: 1, green: 0.995, blue: 0.97, alpha: alpha).cgColor
                    : UIColor(red: 0.42, green: 0.33, blue: 0.22, alpha: alpha).cgColor)
                cg.setLineWidth(width)
                for ox in offsets {
                    for oy in offsets {
                        cg.move(to: CGPoint(x: x0 + ox, y: y0 + oy))
                        cg.addQuadCurve(to: CGPoint(x: x0 + dx + ox, y: y0 + dy + oy), control: CGPoint(x: cx + ox, y: cy + oy))
                        cg.strokePath()
                    }
                }
            }
            for _ in 0..<flecks {
                let x0 = next() * tile, y0 = next() * tile
                let w = 0.5 + next() * 1.1, h = 0.3 + next() * 0.5
                let angle = next() * .pi
                cg.setFillColor(UIColor(red: 0.36, green: 0.27, blue: 0.17, alpha: (0.10 + next() * 0.16) * strength).cgColor)
                for ox in offsets {
                    for oy in offsets {
                        cg.saveGState()
                        cg.translateBy(x: x0 + ox, y: y0 + oy)
                        cg.rotate(by: angle)
                        cg.fillEllipse(in: CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
                        cg.restoreGState()
                    }
                }
            }
        }
    }

    /// The page: washi, its fibres only just showing.
    static let pagePaper: UIColor = washi(base: Lit.page, fibres: 110, flecks: 5, strength: 0.6, seed: 11).map(UIColor.init(patternImage:)) ?? Lit.page

    /// Shippō, interlocked circles, as a print in mica: a lit line and, a hair down and right of it, a shaded
    /// one. Clear between the lines; repeats every `paperTile` points.
    static let shippoPaper: UIColor? = {
        let tile = paperTile, cell: CGFloat = 32
        let format = UIGraphicsImageRendererFormat()
        format.scale = min(UIScreen.main.scale, 2)
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: CGSize(width: tile, height: tile), format: format).image { context in
            let cg = context.cgContext
            let count = Int(tile / cell)
            for pass in 0..<2 {
                cg.setStrokeColor(pass == 0 ? UIColor(red: 0.35, green: 0.30, blue: 0.24, alpha: 0.045).cgColor
                    : UIColor.white.withAlphaComponent(0.62).cgColor)
                cg.setLineWidth(pass == 0 ? 0.7 : 0.6)
                let shift: CGFloat = pass == 0 ? 0.45 : 0
                for i in -1...(count + 1) {
                    for j in -1...(count + 1) where (i + j) % 2 == 0 {
                        cg.strokeEllipse(in: CGRect(x: CGFloat(i) * cell - cell + shift, y: CGFloat(j) * cell - cell + shift,
                                                    width: 2 * cell, height: 2 * cell))
                    }
                }
            }
        }
        return UIColor(patternImage: image)
    }()
}

// MARK: - The light, moved by the phone

public protocol LitLightListener: AnyObject {
    /// The light moved. Both axes run -1...1.
    func lightDidMove(x: CGFloat, y: CGFloat)
}

/// The key light, moved by how the phone is held. While the app is in front and anything listens, the rig
/// reads the phone's tilt and every surface answers: sheets of glass slide their sheen and shift their
/// shadows, glints run along their edges, the mica print on the page catches the light. Whatever posture
/// the phone is held in becomes "straight" within a few seconds, so the light rests where it was designed
/// and moves only when the phone does. Reduce Motion, Low Power and a hot phone leave the light still.
public final class LitLightRig: NSObject {
    public static let shared = LitLightRig()

    public private(set) var x: CGFloat = 0
    public private(set) var y: CGFloat = 0

    private let listeners = NSHashTable<AnyObject>.weakObjects()
    private let motion = CMMotionManager()
    private var link: CADisplayLink?
    private var restX: Double?
    private var restY: Double?
    private var inFront = true
    private var demoStart: CFTimeInterval?

    private override init() {
        super.init()
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(cameToFront), name: UIApplication.didBecomeActiveNotification, object: nil)
        center.addObserver(self, selector: #selector(leftFront), name: UIApplication.willResignActiveNotification, object: nil)
        center.addObserver(self, selector: #selector(policyChanged), name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(policyChanged), name: .NSProcessInfoPowerStateDidChange, object: nil)
        center.addObserver(self, selector: #selector(policyChanged), name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
        #if DEBUG
        // Films on a simulator, which has no tilt: `-LitTiltDemo 1` carries the light round slowly.
        if UserDefaults.standard.bool(forKey: "LitTiltDemo") { demoStart = CACurrentMediaTime() }
        #endif
    }

    public func add(_ listener: LitLightListener) {
        listeners.add(listener)
        if x != 0 || y != 0 { listener.lightDidMove(x: x, y: y) }
        refresh()
    }

    public func remove(_ listener: LitLightListener) {
        listeners.remove(listener)
    }

    /// Places the light. Both axes run -1...1. The rig calls this itself from the phone's tilt.
    public func set(x newX: CGFloat, y newY: CGFloat) {
        guard newX != x || newY != y else { return }
        x = newX
        y = newY
        for case let listener as LitLightListener in listeners.allObjects {
            listener.lightDidMove(x: x, y: y)
        }
    }

    private var allowed: Bool {
        let info = ProcessInfo.processInfo
        let hot = info.thermalState == .serious || info.thermalState == .critical
        return inFront && !UIAccessibility.isReduceMotionEnabled && !info.isLowPowerModeEnabled && !hot
    }

    private func refresh() {
        let wanted = allowed && listeners.count > 0 && (motion.isDeviceMotionAvailable || demoStart != nil)
        if wanted, link == nil {
            if motion.isDeviceMotionAvailable {
                motion.deviceMotionUpdateInterval = 1.0 / 30.0
                motion.startDeviceMotionUpdates()
            }
            let created = CADisplayLink(target: self, selector: #selector(tick))
            created.preferredFramesPerSecond = 30
            created.add(to: .main, forMode: .common)
            link = created
        } else if !wanted, link != nil {
            link?.invalidate()
            link = nil
            motion.stopDeviceMotionUpdates()
            restX = nil
            restY = nil
            if !allowed { set(x: 0, y: 0) }
        }
    }

    @objc private func cameToFront() {
        inFront = true
        refresh()
    }

    @objc private func leftFront() {
        inFront = false
        refresh()
    }

    @objc private func policyChanged() {
        DispatchQueue.main.async { self.refresh() }
    }

    @objc private func tick() {
        if listeners.count == 0 {
            refresh()
            return
        }
        var targetX = 0.0, targetY = 0.0
        if let start = demoStart {
            let t = CACurrentMediaTime() - start
            targetX = 0.85 * sin(t * 2 * .pi / 6)
            targetY = 0.60 * sin(t * 2 * .pi / 9 + 1.1)
        } else if let gravity = motion.deviceMotion?.gravity {
            // The posture the phone is held in drifts to "straight" in a few seconds.
            let baseX = restX ?? gravity.x, baseY = restY ?? gravity.y
            restX = baseX + (gravity.x - baseX) * 0.012
            restY = baseY + (gravity.y - baseY) * 0.012
            targetX = max(-1, min(1, (gravity.x - baseX) * 3.4))
            targetY = max(-1, min(1, (baseY - gravity.y) * 3.4))
        }
        let nextX = x + (CGFloat(targetX) - x) * 0.22
        let nextY = y + (CGFloat(targetY) - y) * 0.22
        // A phone lying still draws no frames.
        guard abs(nextX - x) > 0.003 || abs(nextY - y) > 0.003 else { return }
        set(x: nextX, y: nextY)
    }
}

/// Depth: things nearer the eye move further when the phone tilts. The system does the moving, off the
/// main thread, and leaves it out under Reduce Motion.
public enum LitParallax {
    private static var marked = NSHashTable<UIView>.weakObjects()

    /// `depth` is how many points the view travels at full tilt.
    public static func attach(to view: UIView, depth: CGFloat) {
        guard !marked.contains(view) else { return }
        marked.add(view)
        let across = UIInterpolatingMotionEffect(keyPath: "center.x", type: .tiltAlongHorizontalAxis)
        across.minimumRelativeValue = -depth
        across.maximumRelativeValue = depth
        let along = UIInterpolatingMotionEffect(keyPath: "center.y", type: .tiltAlongVerticalAxis)
        along.minimumRelativeValue = -depth
        along.maximumRelativeValue = depth
        let group = UIMotionEffectGroup()
        group.motionEffects = [across, along]
        view.addMotionEffect(group)
    }
}

// MARK: - Sheets and pads

/// What a view stands on. As glass it is a sheet of frosted glass lying over the page: its milk, the window
/// lying across it as soft streaks that slide when the phone tilts, a polished edge with glints that run
/// along it, and the light shadow glass casts. As a pad it is a soft raised piece of the surface's own white.
public final class LitPlateLayer: CALayer, LitLightListener {
    public enum Material {
        case glass
        case pad
    }

    public var cornerRadiusValue: CGFloat = Lit.sheetRadius { didSet { if oldValue != cornerRadiusValue { rebuild() } } }
    /// How far it stands off what is under it, in points: sizes its shadows.
    public var elevation: CGFloat = 16 { didSet { if oldValue != elevation { rebuild() } } }
    /// Glass or pad; by default large things are glass and small ones pads.
    public var material: Material? { didSet { if oldValue != material { rebuild() } } }
    public var isPressedIn = false { didSet { if oldValue != isPressedIn { applyPress() } } }
    /// A sheet of another colour: for one that means something, like a warning.
    public var faceColor: UIColor? { didSet { applyFace() } }
    /// True when something live is blurred under the sheet, so its milk is thinner.
    public var isOverBackdrop = false { didSet { if oldValue != isOverBackdrop { applyFace() } } }

    private let shadow = CALayer()
    private let face = CAGradientLayer()
    private let bounce = CAGradientLayer()
    private let sweepClip = CALayer()
    private let sweep = CAGradientLayer()
    private let edge = CALayer()
    private let glintTop = CAGradientLayer()
    private let glintSide = CAGradientLayer()
    private var shadowMargin: CGFloat = 0
    private var light = CGPoint.zero
    private var showsSheen = false
    private var bounceCenter: CGFloat = 0.5
    private var observer: NSObjectProtocol?

    private var resolved: Material { material ?? (elevation >= 12 ? .glass : .pad) }

    public override init() {
        super.init()
        masksToBounds = false
        needsDisplayOnBoundsChange = false
        face.masksToBounds = true
        bounce.type = .radial
        bounce.startPoint = CGPoint(x: 0.5, y: 0.5)
        bounce.endPoint = CGPoint(x: 1, y: 1)
        bounce.isHidden = true
        sweepClip.masksToBounds = true
        sweepClip.isHidden = true
        sweep.startPoint = CGPoint(x: 0, y: 0.2)
        sweep.endPoint = CGPoint(x: 1, y: 0.8)
        sweep.colors = [UIColor.white.withAlphaComponent(0).cgColor, UIColor.white.withAlphaComponent(0.50).cgColor,
                        UIColor.white.withAlphaComponent(0).cgColor]
        sweep.locations = [0.36, 0.5, 0.64]
        sweep.opacity = 0
        sweepClip.addSublayer(sweep)
        let glint = [UIColor.white.withAlphaComponent(0).cgColor, UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor]
        glintTop.startPoint = CGPoint(x: 0, y: 0.5)
        glintTop.endPoint = CGPoint(x: 1, y: 0.5)
        glintTop.colors = glint
        glintSide.startPoint = CGPoint(x: 0.5, y: 0)
        glintSide.endPoint = CGPoint(x: 0.5, y: 1)
        glintSide.colors = glint
        [shadow, face, bounce, sweepClip, edge, glintTop, glintSide].forEach { addSublayer($0) }
        observer = NotificationCenter.default.addObserver(forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil,
                                                          queue: .main) { [weak self] _ in self?.applyFace() }
        rebuild()
        LitLightRig.shared.add(self)
    }

    public override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        observer.map(NotificationCenter.default.removeObserver)
    }

    /// Lets fresh light cross the sheet (`sweepSheen`). For the largest sheets only.
    public func setShowsSheen(_ on: Bool) {
        showsSheen = on
        sweepClip.isHidden = !on
    }

    /// A band of light crosses the sheet once: fresh data has arrived.
    public func sweepSheen() {
        guard showsSheen, LitMotion.allowed, bounds.width > 0 else { return }
        let move = CABasicAnimation(keyPath: "transform.translation.x")
        move.fromValue = -bounds.width * 1.3
        move.toValue = bounds.width * 1.3
        let show = CAKeyframeAnimation(keyPath: "opacity")
        show.values = [0, 1, 1, 0]
        show.keyTimes = [0, 0.15, 0.8, 1]
        let group = CAAnimationGroup()
        group.animations = [move, show]
        group.duration = 1.05
        group.timingFunction = CAMediaTimingFunction(controlPoints: 0.3, 0.1, 0.3, 1)
        sweep.add(group, forKey: "sweep")
    }

    /// A coloured light falling on the sheet's top edge from above, centred at `centerX` (0...1): the sun's
    /// red on the glass under it.
    public func setBounce(color: UIColor?, centerX: CGFloat = 0.5, strength: CGFloat = 1) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if let color {
            bounce.isHidden = false
            bounce.colors = [color.withAlphaComponent(0.16 * strength).cgColor, color.withAlphaComponent(0.05 * strength).cgColor,
                             color.withAlphaComponent(0).cgColor]
            bounce.locations = [0, 0.45, 1]
            bounceCenter = centerX
            layoutBounce()
        } else {
            bounce.isHidden = true
        }
        CATransaction.commit()
    }

    private func layoutBounce() {
        let width = bounds.width
        let radius = width * 0.62
        let center = bounceCenter + light.x * 0.10
        bounce.frame = CGRect(x: width * center - radius, y: -0.42 * radius, width: 2 * radius, height: 0.84 * radius)
        bounce.cornerRadius = 0
    }

    private func rebuild() {
        let scale = UIScreen.main.scale
        let radius = cornerRadiusValue
        let glass = resolved == .glass
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let cast = glass ? LitImages.glassShadow(radius: radius, lift: elevation, scale: scale)
            : LitImages.padShadow(radius: radius, lift: elevation, scale: scale)
        if let cast {
            shadow.contents = cast.image
            shadowMargin = cast.margin
            shadow.contentsScale = CGFloat(cast.image.width) / (2 * (radius + cast.margin) + 2)
            let side = 2 * (radius + cast.margin) + 2
            let middle = (radius + cast.margin) / side
            shadow.contentsCenter = CGRect(x: middle, y: middle, width: 2 / side, height: 2 / side)
        }
        edge.contents = glass ? LitImages.glassEdge(radius: radius, scale: scale) : LitImages.padEdge(radius: radius, scale: scale)
        edge.contentsScale = scale
        let side = 2 * radius + 2 * LitImages.edgeInset + 2
        let middle = (radius + LitImages.edgeInset) / side
        edge.contentsCenter = CGRect(x: middle, y: middle, width: 2 / side, height: 2 / side)
        face.cornerRadius = radius
        sweepClip.cornerRadius = radius
        glintTop.isHidden = !glass
        glintSide.isHidden = !glass
        CATransaction.commit()
        applyFace()
        setNeedsLayout()
    }

    private func applyFace() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        face.startPoint = CGPoint(x: 0, y: 0)
        face.endPoint = CGPoint(x: 1, y: 1)
        if let faceColor {
            face.colors = [faceColor.cgColor, faceColor.cgColor]
            face.locations = [0, 1]
        } else if resolved == .pad {
            face.colors = [Lit.padLit.cgColor, Lit.padShade.cgColor]
            face.locations = [0, 1]
        } else if UIAccessibility.isReduceTransparencyEnabled {
            face.colors = [Lit.surface.cgColor, Lit.surface.cgColor]
            face.locations = [0, 1]
        } else {
            // The milk, thicker towards the window, and the window itself as two soft streaks across the sheet.
            let thin: CGFloat = isOverBackdrop ? 0.24 : 0
            let stops: [(CGFloat, CGFloat)] = [(0, 0.72), (0.20, 0.66), (0.24, 0.72), (0.32, 0.70), (0.36, 0.61), (0.42, 0.575),
                                               (0.44, 0.615), (0.48, 0.61), (0.50, 0.56), (0.60, 0.54), (1, 0.54)]
            face.colors = stops.map { UIColor.white.withAlphaComponent($0.1 - thin).cgColor }
            face.locations = stops.map { NSNumber(value: Double($0.0)) }
        }
        CATransaction.commit()
        placeLight()
    }

    private func applyPress() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(isPressedIn ? 0.07 : 0.14)
        shadow.opacity = isPressedIn ? 0.35 : 1
        CATransaction.commit()
    }

    public override func layoutSublayers() {
        super.layoutSublayers()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        face.frame = bounds
        // Depth alone is not enough under Increase Contrast: the sheet gets a real edge.
        let contrast = UIAccessibility.isDarkerSystemColorsEnabled
        face.borderWidth = contrast ? 1.5 : 0
        face.borderColor = contrast ? Lit.inkSecondary.cgColor : nil
        edge.frame = bounds
        sweepClip.frame = bounds
        sweep.frame = bounds
        if !bounce.isHidden { layoutBounce() }
        CATransaction.commit()
        placeLight()
    }

    /// Shifts the shadows against the light, slides the window's streaks over the glass and runs the glints
    /// along its near edges.
    private func placeLight() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let reach = elevation * (resolved == .glass ? 0.26 : 0.18)
        let m = shadowMargin
        shadow.frame = bounds.insetBy(dx: -m, dy: -m).offsetBy(dx: -light.x * reach, dy: -light.y * reach)
        if resolved == .glass, faceColor == nil {
            let slide = CGPoint(x: light.x * 0.22, y: light.y * 0.22)
            face.startPoint = CGPoint(x: slide.x, y: slide.y)
            face.endPoint = CGPoint(x: 1 + slide.x, y: 1 + slide.y)
            let radius = cornerRadiusValue
            let across = max(0.12, min(0.88, 0.30 + light.x * 0.42))
            glintTop.frame = CGRect(x: radius, y: 0.2, width: max(bounds.width - 2 * radius, 0), height: 1.2)
            glintTop.locations = [NSNumber(value: Double(across) - 0.16), NSNumber(value: Double(across)), NSNumber(value: Double(across) + 0.16)]
            let down = max(0.12, min(0.88, 0.26 + light.y * 0.42))
            glintSide.frame = CGRect(x: 0.2, y: radius, width: 1.2, height: max(bounds.height - 2 * radius, 0))
            glintSide.locations = [NSNumber(value: Double(down) - 0.20), NSNumber(value: Double(down)), NSNumber(value: Double(down) + 0.20)]
        }
        if !bounce.isHidden { layoutBounce() }
        CATransaction.commit()
    }

    public func lightDidMove(x: CGFloat, y: CGFloat) {
        light = CGPoint(x: x, y: y)
        placeLight()
    }
}

// MARK: - Wells

/// A pad let into the surface. Stretched from a baked corner, so any width costs nothing.
public final class LitWellLayer: CALayer {
    public var cornerRadiusValue: CGFloat = 12 { didSet { if oldValue != cornerRadiusValue { rebuild() } } }
    public var depth: CGFloat = 2.5 { didSet { if oldValue != depth { rebuild() } } }
    public var floorColor: UIColor? { didSet { rebuild() } }
    /// A solid boundary round it: for a well that takes input or counts something.
    public var isRuled = false { didSet { if oldValue != isRuled { rebuild() } } }

    public override init() {
        super.init()
        contentsScale = UIScreen.main.scale
        rebuild()
    }

    public override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func rebuild() {
        let scale = UIScreen.main.scale
        guard let baked = LitImages.well(radius: cornerRadiusValue, depth: depth, scale: scale, floor: floorColor, ruled: isRuled) else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        contents = baked
        let side = CGFloat(baked.width) / scale
        let corner = LitImages.wellCorner(radius: cornerRadiusValue, depth: depth)
        contentsCenter = CGRect(x: corner / side, y: corner / side, width: (2 / scale) / side, height: (2 / scale) / side)
        CATransaction.commit()
    }

    /// Lays the well over `rect`.
    public func place(in rect: CGRect) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        frame = rect
        CATransaction.commit()
    }
}

// MARK: - Cut glass

/// A piece of cut red glass with a glyph inlaid in white: the one loud thing where it stands. Pressing
/// sets it down on the surface; its pool of red light tightens under it.
public final class LitCutGlassView: UIView, LitLightListener {
    private let piece = CALayer()
    private let glintClip = CALayer()
    private let glint = CAGradientLayer()
    private let size: CGSize
    private let radius: CGFloat
    private var glyph: UIImage?
    private var glyphKey = ""
    private var pressedIn = false

    public init(size: CGSize, cornerRadius: CGFloat) {
        self.size = size
        radius = min(cornerRadius, min(size.width, size.height) / 2)
        super.init(frame: CGRect(origin: .zero, size: size))
        isUserInteractionEnabled = false
        backgroundColor = .clear
        layer.addSublayer(piece)
        glintClip.masksToBounds = true
        glintClip.cornerRadius = radius
        glint.colors = [UIColor.white.withAlphaComponent(0).cgColor, UIColor.white.withAlphaComponent(0.20).cgColor,
                        UIColor.white.withAlphaComponent(0).cgColor]
        glint.locations = [0.30, 0.5, 0.70]
        glint.startPoint = CGPoint(x: 0, y: 0.35)
        glint.endPoint = CGPoint(x: 1, y: 0.65)
        glintClip.addSublayer(glint)
        layer.addSublayer(glintClip)
        bake()
        LitLightRig.shared.add(self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The glyph inlaid in the glass. `key` names it for the cache.
    public func setGlyph(_ image: UIImage?, key: String) {
        glyph = image
        glyphKey = key
        bake()
    }

    public override var intrinsicContentSize: CGSize { size }

    private func bake() {
        let scale = UIScreen.main.scale
        guard let baked = LitImages.cutGlassPiece(size: size, radius: radius, base: Lit.lacquerRed, glyph: glyph, glyphKey: glyphKey,
                                                  pressed: pressedIn, scale: scale) else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        piece.contents = baked
        piece.contentsScale = scale
        let margin = LitImages.cutGlassMargin
        piece.bounds = CGRect(x: 0, y: 0, width: size.width + 2 * margin, height: size.height + 2 * margin)
        CATransaction.commit()
        setNeedsLayout()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let middle = CGPoint(x: bounds.midX, y: bounds.midY + (pressedIn ? 1 : 0))
        piece.position = middle
        glintClip.bounds = CGRect(origin: .zero, size: size)
        glintClip.position = middle
        glint.frame = CGRect(x: -size.width, y: 0, width: size.width * 3, height: size.height)
        CATransaction.commit()
        lightDidMove(x: LitLightRig.shared.x, y: LitLightRig.shared.y)
    }

    public func setPressed(_ pressed: Bool) {
        guard pressed != pressedIn else { return }
        pressedIn = pressed
        bake()
        layoutIfNeeded()
    }

    /// The window's reflection slides over the table as the phone tilts.
    public func lightDidMove(x: CGFloat, y: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        glint.transform = CATransform3DMakeTranslation((x * 0.75 - 0.30) * size.width, 0, 0)
        CATransaction.commit()
    }
}

/// A filled button's face in cut glass of the button's colour, stretched along its length. Add `layer` under
/// the button's content.
public final class LitCutGlass: LitLightListener {
    public let layer = CALayer()
    private let glintClip = CALayer()
    private let glint = CAGradientLayer()
    private var built: String?
    private var width: CGFloat = 0

    public init() {
        glintClip.masksToBounds = true
        glint.colors = [UIColor.white.withAlphaComponent(0).cgColor, UIColor.white.withAlphaComponent(0.16).cgColor,
                        UIColor.white.withAlphaComponent(0).cgColor]
        glint.locations = [0.42, 0.5, 0.58]
        glint.startPoint = CGPoint(x: 0, y: 0.2)
        glint.endPoint = CGPoint(x: 1, y: 0.8)
        glintClip.addSublayer(glint)
        layer.addSublayer(glintClip)
        LitLightRig.shared.add(self)
    }

    public func layout(in host: UIView, radius: CGFloat, color: UIColor, pressed: Bool = false) {
        let scale = UIScreen.main.scale
        let height = host.bounds.height
        guard height > 0 else { return }
        let r = min(radius, height / 2)
        let margin = LitImages.cutGlassMargin
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let key = "\(height)|\(r)|\(color.cgColor.components ?? [])|\(pressed)"
        if built != key {
            built = key
            layer.contents = LitImages.cutGlassBar(height: height, radius: r, base: color, pressed: pressed, scale: scale)
            layer.contentsScale = scale
            let imageWidth = 2 * (r + LitImages.cutGlassCap) + 2 + 2 * margin
            layer.contentsCenter = CGRect(x: (margin + r + LitImages.cutGlassCap) / imageWidth, y: 0, width: 2 / imageWidth, height: 1)
        }
        layer.frame = host.bounds.insetBy(dx: -margin, dy: -margin)
        width = host.bounds.width
        glintClip.frame = CGRect(x: margin, y: margin, width: host.bounds.width, height: height)
        glintClip.cornerRadius = r
        glint.frame = CGRect(x: -width, y: 0, width: width * 3, height: height)
        CATransaction.commit()
        lightDidMove(x: LitLightRig.shared.x, y: LitLightRig.shared.y)
    }

    public func lightDidMove(x: CGFloat, y: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        glint.transform = CATransform3DMakeTranslation((x * 0.55 - 0.22) * width, 0, 0)
        CATransaction.commit()
    }
}

/// A cut-glass fill of a colour: for buttons that take a background view.
public final class LitCutGlassFill: UIView {
    private let glass = LitCutGlass()
    private var color = Lit.lacquerRed
    public var isPressed = false { didSet { if oldValue != isPressed { setNeedsLayout() } } }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        backgroundColor = .clear
        layer.addSublayer(glass.layer)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The glass takes the fill's colour (a gradient's first stop).
    public func apply(_ colors: NeonGradient) {
        color = colors.colors.first ?? Lit.lacquerRed
        setNeedsLayout()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        glass.layout(in: self, radius: Lit.controlRadius, color: color, pressed: isPressed)
    }
}

// MARK: - Marks

/// A printed mark's die-cut edge and contact shadow, for a flat round icon. Add `shadow` behind the icon and
/// `light` over it.
public final class LitCoinLayers {
    public let shadow = CALayer()
    public let light = CALayer()
    private var margin: CGFloat = 0

    public init() {}

    public func configure(diameter: CGFloat) {
        let scale = UIScreen.main.scale
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        light.contents = LitImages.coin(diameter: diameter, scale: scale)
        light.contentsScale = scale
        if let baked = LitImages.coinShadow(diameter: diameter, scale: scale) {
            shadow.contents = baked.image
            shadow.contentsScale = scale
            margin = baked.margin
        }
        CATransaction.commit()
    }

    public func layout(iconFrame: CGRect) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        light.frame = iconFrame
        shadow.frame = iconFrame.insetBy(dx: -margin, dy: -margin)
        CATransaction.commit()
    }
}

/// A round image as a printed mark.
public final class LitCoinImageView: UIView {
    public let imageView = UIImageView()
    private let coin = LitCoinLayers()

    public init(diameter: CGFloat) {
        super.init(frame: CGRect(x: 0, y: 0, width: diameter, height: diameter))
        imageView.frame = bounds
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = diameter / 2
        imageView.clipsToBounds = true
        // A picture that has not loaded leaves a plain white mark, not a hole over its shadow.
        imageView.backgroundColor = Lit.padLit
        layer.addSublayer(coin.shadow)
        addSubview(imageView)
        layer.addSublayer(coin.light)
        coin.configure(diameter: diameter)
        coin.layout(iconFrame: bounds)
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// A dot of ink in a colour: status and legend marks. `pulse(true)` breathes it, which means work is really
/// going on.
public final class LitDotView: UIView {
    private let mark = CALayer()
    private let diameter: CGFloat
    private var margin: CGFloat = 0

    public init(diameter: CGFloat) {
        self.diameter = diameter
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        layer.addSublayer(mark)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setColor(_ color: UIColor) {
        let scale = UIScreen.main.scale
        guard let baked = LitImages.dot(color: color, diameter: diameter, scale: scale) else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        mark.contents = baked.image
        mark.contentsScale = scale
        margin = baked.margin
        mark.bounds = CGRect(x: 0, y: 0, width: diameter + 2 * margin, height: diameter + 2 * margin)
        mark.position = CGPoint(x: bounds.midX, y: bounds.midY)
        CATransaction.commit()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        mark.position = CGPoint(x: bounds.midX, y: bounds.midY)
        CATransaction.commit()
    }

    public func pulse(_ on: Bool) {
        if on && !UIAccessibility.isReduceMotionEnabled && !ProcessInfo.processInfo.isLowPowerModeEnabled {
            guard mark.animation(forKey: "pulse") == nil else { return }
            let breath = CABasicAnimation(keyPath: "opacity")
            breath.fromValue = 1
            breath.toValue = 0.35
            breath.duration = 0.7
            breath.autoreverses = true
            breath.repeatCount = .infinity
            breath.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            mark.add(breath, forKey: "pulse")
        } else {
            mark.removeAnimation(forKey: "pulse")
        }
    }
}

/// A bead of red glass. `drop()` lets it fall into place with the flash of light it catches.
public final class LitBeadView: UIView {
    private let bead = CALayer()
    private let flash = CAGradientLayer()
    private let diameter: CGFloat

    public init(diameter: CGFloat) {
        self.diameter = diameter
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        let scale = UIScreen.main.scale
        if let baked = LitImages.bead(diameter: diameter, scale: scale) {
            bead.contents = baked.image
            bead.contentsScale = scale
            bead.bounds = CGRect(x: 0, y: 0, width: diameter + 2 * baked.margin, height: diameter + 2 * baked.margin)
        }
        flash.type = .radial
        flash.startPoint = CGPoint(x: 0.5, y: 0.5)
        flash.endPoint = CGPoint(x: 1, y: 1)
        flash.colors = [Lit.lacquerBright.withAlphaComponent(0.55).cgColor, Lit.lacquerBright.withAlphaComponent(0).cgColor]
        flash.bounds = CGRect(x: 0, y: 0, width: diameter * 3.4, height: diameter * 3.4)
        flash.opacity = 0
        layer.addSublayer(flash)
        layer.addSublayer(bead)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override var intrinsicContentSize: CGSize { CGSize(width: diameter, height: diameter) }

    public override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        bead.position = CGPoint(x: bounds.midX, y: bounds.midY)
        flash.position = bead.position
        CATransaction.commit()
    }

    /// Settles into its place; the red it throws flares once as it lands. The digit counts before this starts.
    public func drop() {
        guard LitMotion.allowed else { return }
        let fall = CABasicAnimation(keyPath: "transform.translation.y")
        fall.fromValue = -diameter * 0.35
        fall.toValue = 0
        fall.duration = 0.11
        fall.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.75, 0.25, 1)
        bead.add(fall, forKey: "drop")
        let appear = CABasicAnimation(keyPath: "opacity")
        appear.fromValue = 0
        appear.toValue = 1
        appear.duration = 0.08
        bead.add(appear, forKey: "appear")
        let flare = CAKeyframeAnimation(keyPath: "opacity")
        flare.values = [0, 1, 0]
        flare.keyTimes = [0, 0.3, 1]
        flare.duration = 0.42
        flare.beginTime = CACurrentMediaTime() + 0.07
        flash.add(flare, forKey: "flare")
    }
}

// MARK: - Page

/// The page: white washi, light falling across it from the top left, and a shippō print in mica that shows
/// most near the top. The print lies a little deeper than the page's content and catches the light as the
/// phone tilts; a soft pool of light moves over the page with it.
public final class LitPageView: UIView, LitLightListener {
    private let print = CALayer()
    private let printFade = CAGradientLayer()
    private let falloff = CAGradientLayer()
    private let pool = CAGradientLayer()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = LitImages.pagePaper
        clipsToBounds = true
        if let pattern = LitImages.shippoPaper {
            print.backgroundColor = pattern.cgColor
            // Fades down the page: built once per size, never while scrolling.
            printFade.colors = [UIColor.black.cgColor, UIColor.black.withAlphaComponent(0.25).cgColor, UIColor.clear.cgColor]
            printFade.locations = [0.04, 0.26, 0.44]
            print.mask = printFade
            layer.addSublayer(print)
        }
        falloff.type = .radial
        falloff.startPoint = CGPoint(x: 0.1, y: 0.0)
        falloff.endPoint = CGPoint(x: 1.2, y: 1.1)
        falloff.colors = [UIColor.white.withAlphaComponent(0.30).cgColor, UIColor.white.withAlphaComponent(0.0).cgColor,
                          UIColor(litHex: 0x4D3D29, alpha: 0.08).cgColor]
        falloff.locations = [0, 0.55, 1]
        layer.addSublayer(falloff)
        pool.type = .radial
        pool.startPoint = CGPoint(x: 0.5, y: 0.5)
        pool.endPoint = CGPoint(x: 1, y: 1)
        pool.colors = [UIColor.white.withAlphaComponent(0.34).cgColor, UIColor.white.withAlphaComponent(0).cgColor]
        pool.opacity = 0
        layer.addSublayer(pool)
        LitLightRig.shared.add(self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        print.frame = bounds.insetBy(dx: -12, dy: -12)
        printFade.frame = print.bounds
        falloff.frame = bounds
        let side = max(bounds.width, 1) * 1.5
        pool.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        CATransaction.commit()
        lightDidMove(x: LitLightRig.shared.x, y: LitLightRig.shared.y)
    }

    public func lightDidMove(x: CGFloat, y: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // The print lies deeper than the content: it moves the other way.
        print.transform = CATransform3DMakeTranslation(-x * 7, -y * 7, 0)
        let tilt = min(1, (x * x + y * y).squareRoot())
        print.opacity = Float(0.72 + 0.28 * tilt)
        pool.position = CGPoint(x: bounds.width * (0.28 + 0.46 * x), y: bounds.height * (0.20 + 0.30 * y))
        pool.opacity = Float(tilt)
        CATransaction.commit()
    }
}

// MARK: - Ruled lines

/// A line ruled into the surface: a dark edge and, just under it, a lit one.
public final class LitEngravedLine: UIView {
    private let dark = CALayer()
    private let light = CALayer()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        dark.backgroundColor = Lit.rule.cgColor
        light.backgroundColor = UIColor.white.withAlphaComponent(0.8).cgColor
        layer.addSublayer(dark)
        layer.addSublayer(light)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override var intrinsicContentSize: CGSize { CGSize(width: UIView.noIntrinsicMetric, height: 2) }

    public override func layoutSubviews() {
        super.layoutSubviews()
        let px = 1 / max(traitCollection.displayScale, 1)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dark.frame = CGRect(x: 0, y: 0, width: bounds.width, height: px * 2)
        light.frame = CGRect(x: 0, y: px * 2, width: bounds.width, height: px * 2)
        CATransaction.commit()
    }
}

// MARK: - Motion

/// The press every soft control shares: set down quickly, let up without a bounce.
public enum LitMotion {
    public static var allowed: Bool { !UIAccessibility.isReduceMotionEnabled }

    public static func press(_ view: UIView, pressed: Bool, scale: CGFloat = 0.97) {
        let target: CGFloat = pressed && allowed ? scale : 1
        UIView.animate(withDuration: pressed ? 0.07 : 0.14, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseOut]) {
            view.transform = pressed ? CGAffineTransform(scaleX: target, y: target).translatedBy(x: 0, y: 1) : .identity
        }
    }

    /// Rises into place and fades in, once. Rows and cards do this the first time they are seen.
    public static func rise(_ view: UIView, by distance: CGFloat = 12, after delay: CFTimeInterval = 0) {
        guard allowed else { return }
        let layer = view.layer
        let begin = CACurrentMediaTime() + delay
        let move = CABasicAnimation(keyPath: "transform.translation.y")
        move.fromValue = distance
        move.toValue = 0
        move.duration = 0.34
        move.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 0.84, 0.3, 1)
        move.beginTime = begin
        move.fillMode = .backwards
        layer.add(move, forKey: "lit.rise")
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        fade.duration = 0.26
        fade.beginTime = begin
        fade.fillMode = .backwards
        layer.add(fade, forKey: "lit.riseFade")
    }
}

/// Changes a number's text like a counter: only the digits that changed roll, the rest stay still.
public enum LitRoller {
    private static var active = NSMapTable<UILabel, UIView>.weakToStrongObjects()

    public static func setText(_ text: NSAttributedString, on label: UILabel, animated: Bool, rollsUp: Bool = true) {
        cancel(on: label)
        guard animated, LitMotion.allowed, let old = label.attributedText, old.length == text.length, old.length > 0,
              old.string != text.string, label.bounds.width > 0, label.window != nil else {
            if animated, LitMotion.allowed, label.window != nil, label.attributedText?.string != text.string {
                let fade = CATransition()
                fade.type = .fade
                fade.duration = 0.22
                label.layer.add(fade, forKey: "lit.fade")
            }
            label.attributedText = text
            return
        }
        let oldChars = Array(old.string.utf16), newChars = Array(text.string.utf16)
        let changed = oldChars.indices.filter { oldChars[$0] != newChars[$0] }
        // The label may have shrunk its text to fit.
        let natural = text.size().width
        let shrink = natural > label.bounds.width ? label.bounds.width / natural : 1
        let line = text.size().height * shrink
        let top = (label.bounds.height - line) / 2

        let holes = NSMutableAttributedString(attributedString: text)
        let overlay = UIView(frame: label.bounds)
        overlay.isUserInteractionEnabled = false
        overlay.clipsToBounds = true
        var pending = changed.count
        let finish = {
            label.attributedText = text
            overlay.removeFromSuperview()
            active.removeObject(forKey: label)
        }
        for (order, index) in changed.reversed().enumerated() {
            let range = NSRange(location: index, length: 1)
            holes.addAttribute(.foregroundColor, value: UIColor.clear, range: range)
            holes.removeAttribute(.shadow, range: range)
            let x = text.attributedSubstring(from: NSRange(location: 0, length: index)).size().width * shrink
            let width = text.attributedSubstring(from: range).size().width * shrink + 1
            let outgoing = UILabel(frame: CGRect(x: x, y: top, width: width, height: line))
            outgoing.attributedText = old.attributedSubstring(from: range)
            let incoming = UILabel(frame: outgoing.frame)
            incoming.attributedText = text.attributedSubstring(from: range)
            [outgoing, incoming].forEach {
                $0.adjustsFontSizeToFitWidth = true
                $0.minimumScaleFactor = 0.4
                $0.textAlignment = .left
                overlay.addSubview($0)
            }
            let travel = line * 0.62 * (rollsUp ? 1 : -1)
            incoming.transform = CGAffineTransform(translationX: 0, y: travel)
            incoming.alpha = 0
            UIView.animate(withDuration: 0.5, delay: Double(order) * 0.035, usingSpringWithDamping: 1, initialSpringVelocity: 0,
                           options: [.allowUserInteraction]) {
                incoming.transform = .identity
                incoming.alpha = 1
                outgoing.transform = CGAffineTransform(translationX: 0, y: -travel)
                outgoing.alpha = 0
            } completion: { _ in
                pending -= 1
                if pending == 0, active.object(forKey: label) === overlay { finish() }
            }
        }
        label.attributedText = holes
        label.addSubview(overlay)
        active.setObject(overlay, forKey: label)
    }

    private static func cancel(on label: UILabel) {
        guard let overlay = active.object(forKey: label) else { return }
        overlay.removeFromSuperview()
        active.removeObject(forKey: label)
    }
}

public extension UIFont {
    /// The same font with digits of one width, so a number's digits can change without the rest moving.
    var litTabularDigits: UIFont {
        let features: [[UIFontDescriptor.FeatureKey: Int]] = [[.type: kNumberSpacingType, .selector: kMonospacedNumbersSelector]]
        return UIFont(descriptor: fontDescriptor.addingAttributes([.featureSettings: features]), size: pointSize)
    }

}

/// Raises any view as a soft pad, or lets it into the surface as a well, behind its content. Call `layout`
/// when its bounds change.
public final class LitBacking {
    public enum Style: Equatable {
        case raised(elevation: CGFloat)
        case pressed(floor: UIColor?, depth: CGFloat)
    }

    private weak var host: UIView?
    private let plate = LitPlateLayer()
    private let well = LitWellLayer()
    private var radius: CGFloat = 0

    public var style: Style = .raised(elevation: 8) {
        didSet { if style != oldValue { apply() } }
    }

    /// A solid boundary round the well: for one that takes input.
    public var isRuled = false { didSet { well.isRuled = isRuled } }

    public init(host: UIView) {
        self.host = host
        host.backgroundColor = .clear
        plate.material = .pad
        host.layer.insertSublayer(plate, at: 0)
        host.layer.insertSublayer(well, at: 0)
        apply()
    }

    private func apply() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        switch style {
        case let .raised(elevation):
            plate.isHidden = false
            well.isHidden = true
            plate.elevation = elevation
        case let .pressed(floor, depth):
            plate.isHidden = true
            well.isHidden = false
            well.depth = depth
            well.floorColor = floor
        }
        CATransaction.commit()
        layout(radius: radius)
    }

    /// Lays the pad or well over the host's bounds, never rounder than a capsule.
    public func layout(radius newRadius: CGFloat) {
        radius = newRadius
        guard let host, host.bounds.width > 0, host.bounds.height > 0 else { return }
        let fitted = min(newRadius, min(host.bounds.width, host.bounds.height) / 2)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        plate.cornerRadiusValue = fitted
        plate.frame = host.bounds
        well.cornerRadiusValue = fitted
        well.place(in: host.bounds)
        CATransaction.commit()
    }
}
