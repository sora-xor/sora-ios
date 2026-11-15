import CoreText
import UIKit

// One world, one light. Every surface of the app is lit by the same rig: a window at the top left
// (the key), the room as fill, and the SORA planet as a coloured light. Shadows fall to the bottom
// right, the top-left edges catch the light, wells are shaded from their top-left lip, and glossy
// things mirror the same window. The materials are rendered per pixel once and cached, so nothing
// here costs an offscreen pass while the page scrolls.

/// The material palette: warm porcelain, a little lighter where a plate faces the light.
public enum Lit {
    public static let page = UIColor(litHex: 0xE8E2DE)
    public static let plateLit = UIColor(litHex: 0xFAF7F5)
    public static let plateDeep = UIColor(litHex: 0xF0EBE7)
    /// A flat fill between the two, for surfaces with no plate of their own.
    public static let surface = UIColor(litHex: 0xF6F2EF)
    public static let wellFloor = UIColor(litHex: 0xE7E1DD)
    public static let ink = UIColor(litHex: 0x2A1A1C)
    public static let inkSecondary = UIColor(litHex: 0x6F5D5E)
    public static let inkTertiary = UIColor(litHex: 0x8A7675)
    public static let engraveDark = UIColor(litHex: 0x6B4B40, alpha: 0.16)
    public static let engraveLight = UIColor(white: 1, alpha: 0.85)

    /// The key light in the page's plane (towards the light), unit length.
    public static let keyX: CGFloat = -0.6
    public static let keyY: CGFloat = -0.8

    /// The shadow colours: warm, as light bounced off porcelain is.
    public static let lacquerRed = UIColor(litHex: 0xE3232C)

    fileprivate static let shadowWarm = UIColor(litHex: 0x6B4A40)
    fileprivate static let shadowContact = UIColor(litHex: 0x3C2A26)
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

    private static func color(_ c: UIColor) -> (r: Float, g: Float, b: Float) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Float(r), Float(g), Float(b))
    }

    /// What a plate casts on the page: the broad room shadow, the key's shadow to the bottom right, a tight
    /// contact shadow, and the lit halo on the top left. Empty where the plate itself sits.
    /// Returned with the margin round the shape, and stretches in its centre.
    static func plateShadow(radius: CGFloat, spread: CGFloat, halo: CGFloat, scale: CGFloat) -> (image: CGImage, margin: CGFloat)? {
        let margin = ceil(spread * 3.2)
        let side = 2 * (radius + margin) + 2
        let size = CGSize(width: side, height: side)
        let key = "shadow|\(radius)|\(spread)|\(halo)|\(scale)"
        let made = cached(key) {
            let format = UIGraphicsImageRendererFormat()
            format.scale = scale
            format.opaque = false
            let renderer = UIGraphicsImageRenderer(size: size, format: format)
            // Circular corners, the same curve as the edge overlay's distance field and the face.
            let shape = UIBezierPath(cgPath: CGPath(roundedRect: CGRect(x: margin, y: margin, width: side - 2 * margin, height: side - 2 * margin),
                                                    cornerWidth: radius, cornerHeight: radius, transform: nil))
            let image = renderer.image { context in
                let cg = context.cgContext
                // Only outside the shape: the plate's face covers the rest.
                let outside = UIBezierPath(rect: CGRect(origin: .zero, size: size))
                outside.append(shape)
                outside.usesEvenOddFillRule = true
                outside.addClip()
                // The casting shape sits outside the image: only its shadow lands here. Drawn inside, the
                // clip's soft edge would let a dark hairline of the shape through.
                let away = side * 2
                let layers: [(UIColor, CGFloat, CGSize, CGFloat)] = [
                    (Lit.shadowWarm, 0.13, CGSize(width: 0, height: spread * 1.15), spread * 2.3),
                    (Lit.shadowWarm, 0.34, CGSize(width: spread * 0.42, height: spread * 0.6), spread * 1.1),
                    (Lit.shadowContact, 0.20, CGSize(width: spread * 0.09, height: spread * 0.15), spread * 0.16),
                    (UIColor.white, 0.95 * halo, CGSize(width: -spread * 0.30, height: -spread * 0.38), spread * 0.7)
                ]
                for (shadowColor, alpha, offset, blur) in layers {
                    cg.saveGState()
                    cg.setShadow(offset: CGSize(width: offset.width + away, height: offset.height), blur: blur,
                                 color: shadowColor.withAlphaComponent(alpha).cgColor)
                    cg.translateBy(x: -away, y: 0)
                    UIColor.black.setFill()
                    shape.fill()
                    cg.restoreGState()
                }
            }
            return image.cgImage
        }
        guard let made else { return nil }
        return (made, margin)
    }

    /// The plate's rounded edge: a quarter-round bullnose lit by the key, as an overlay on its face.
    static func plateEdge(radius: CGFloat, bevel: CGFloat, scale: CGFloat) -> CGImage? {
        let side = 2 * radius + 2 * bevel + 2
        let key = "edge|\(radius)|\(bevel)|\(scale)"
        return cached(key) {
            let s = Float(side), r = Float(radius), b = Float(bevel)
            let lx: Float = -0.46, ly: Float = -0.62, lz: Float = 0.63
            return LitBaker.render(pointSize: CGSize(width: side, height: side), scale: scale) { x, y in
                let shape = LitBaker.roundedRect(x, y, width: s, height: s, radius: r)
                let coverage = LitBaker.sat(0.5 - shape.distance * Float(scale))
                guard coverage > 0, shape.distance > -b else { return .zero }
                let t = (shape.distance + b) / b
                let angle = t * t * Float.pi / 2 * 0.92
                let sinA = sin(angle), cosA = cos(angle)
                let nx = shape.nx * sinA, ny = shape.ny * sinA, nz = cosA
                let lambert = nx * lx + ny * ly + nz * lz
                let relative = lambert - lz
                var out = SIMD4<Float>.zero
                if relative > 0 {
                    out = LitBaker.tint(1, 1, 1, min(relative * 1.9, 0.95))
                } else {
                    out = LitBaker.tint(0.42, 0.29, 0.25, min(-relative * 0.30, 0.34))
                }
                // The window in the glaze: a thin line of light along the top-left turn of the edge.
                let hx = lx, hy = ly, hz = lz + 1
                let hl = (hx * hx + hy * hy + hz * hz).squareRoot()
                let spec = pow(LitBaker.sat((nx * hx + ny * hy + nz * hz) / hl), 42) * 0.8 * LitBaker.smooth(0.15, 0.6, t)
                out = LitBaker.over(LitBaker.tint(1, 1, 1, spec), out)
                return out * coverage
            }
        }
    }

    /// A well pressed into the plate: darker floor, its top-left lip shadowing the floor, its bottom-right
    /// lip catching the light. `floor` is nil for a recess of the plate's own colour.
    static func well(radius: CGFloat, depth: CGFloat, scale: CGFloat, floor: UIColor?) -> (image: CGImage, margin: CGFloat)? {
        let margin: CGFloat = 2
        let corner = max(radius, depth * 3)
        let inner = 2 * corner + 2 / scale
        let side = inner + 2 * margin
        let tintKey = floor.map { "\($0.cgColor.components ?? [])" } ?? "none"
        let key = "well|\(radius)|\(depth)|\(scale)|\(tintKey)"
        let made = cached(key) {
            let s = Float(inner), r = Float(radius), d = Float(depth), m = Float(margin)
            let base = floor.map(color) ?? color(Lit.wellFloor)
            return LitBaker.render(pointSize: CGSize(width: side, height: side), scale: scale) { x, y in
                let shape = LitBaker.roundedRect(x - m, y - m, width: s, height: s, radius: r)
                let aa = 0.5 / Float(scale)
                let inside = LitBaker.smooth(aa, -aa, shape.distance)
                let facing = shape.nx * Float(Lit.keyX) + shape.ny * Float(Lit.keyY)
                // Outside: the lip. Lit on the bottom-right, a hairline of shade on the top-left.
                var out = SIMD4<Float>.zero
                if shape.distance > -aa {
                    let lipBand = LitBaker.smooth(1.6, 0.0, shape.distance)
                    let lit = LitBaker.sat(-facing) * lipBand * 0.95
                    let shade = LitBaker.sat(facing) * lipBand * 0.12
                    out = LitBaker.over(LitBaker.tint(1, 1, 1, lit), LitBaker.tint(0.42, 0.29, 0.25, shade)) * (1 - inside)
                }
                guard inside > 0 else { return out }
                let dist = -shape.distance
                let cast = exp(-dist / (d * 0.95)) * LitBaker.sat(facing * 0.75 + 0.5)
                let occlusion = exp(-dist / (d * 2.6)) * 0.18
                let bounce = exp(-dist / (d * 0.9)) * LitBaker.sat(-facing) * 0.32
                let darken = min(cast * 0.40 + occlusion, 0.85)
                let r0 = base.r * (1 - darken) + 0.30 * darken
                let g0 = base.g * (1 - darken) + 0.18 * darken
                let b0 = base.b * (1 - darken) + 0.16 * darken
                let lift = bounce
                let floorPixel = SIMD4<Float>(r0 + (1 - r0) * lift, g0 + (1 - g0) * lift, b0 + (1 - b0) * lift, 1) * inside
                return LitBaker.over(floorPixel, out)
            }
        }
        guard let made else { return nil }
        return (made, margin)
    }

    /// A polished glass cabochon of a colour: mirrors the window, glows where the light gathers low in the
    /// glass, darkens at its edge. Includes its shadow on the floor below. `margin` is what the image
    /// adds round the dome.
    static func cabochon(lit: UIColor, deep: UIColor, diameter: CGFloat, scale: CGFloat) -> (image: CGImage, margin: CGFloat)? {
        let margin: CGFloat = ceil(diameter * 0.46)
        let side = diameter + 2 * margin
        let key = "dome|\(lit.cgColor.components ?? [])|\(deep.cgColor.components ?? [])|\(diameter)|\(scale)"
        let made = cached(key) {
            let litC = color(lit), deepC = color(deep)
            func linear(_ v: Float) -> Float { pow(v, 2.2) }
            let litL = SIMD3<Float>(linear(litC.r), linear(litC.g), linear(litC.b))
            let deepL = SIMD3<Float>(linear(deepC.r), linear(deepC.g), linear(deepC.b))
            let R = Float(diameter / 2), c = Float(side / 2)
            let aa = 0.6 / Float(scale)
            return LitBaker.render(pointSize: CGSize(width: side, height: side), scale: scale) { x, y in
                let dx = x - c, dy = y - c
                let dist = (dx * dx + dy * dy).squareRoot()
                // The shadow on the floor: tight and dark, then a wash of the dome's own colour.
                let sx = dx - R * 0.10, sy = dy - R * 0.16
                let sd = (sx * sx + sy * sy).squareRoot()
                let shadowA = 0.46 * LitBaker.smooth(R * 1.20, R * 0.72, sd)
                let gx = dx - R * 0.12, gy = dy - R * 0.28
                let gd = (gx * gx + gy * gy).squareRoot()
                let glowA = 0.50 * LitBaker.smooth(R * 1.44, R * 0.72, gd)
                var out = LitBaker.over(LitBaker.tint(0.20, 0.11, 0.10, shadowA),
                                        LitBaker.tint(pow(litL.x, 0.45), pow(litL.y, 0.45), pow(litL.z, 0.45), glowA))
                let coverage = LitBaker.smooth(R + aa, R - aa, dist)
                guard coverage > 0 else { return out }

                // A low dome: the normal turns less than a full sphere's would, until the rolled edge.
                let u = min(dist / R, 1)
                let turn = 0.78 * u + 0.22 * pow(u, 6)
                let lengthN = max(dist, 0.0001)
                let nx = dx / lengthN * turn, ny = dy / lengthN * turn
                let nz = (1 - min(turn * turn, 0.9995)).squareRoot()
                let nv = nz

                // The body: colour gathers low on the far side from the light, as in glass.
                let gather = LitBaker.sat(0.5 + 0.62 * (nx * 0.6 + ny * 0.8) / max(turn, 0.001) * u)
                let bodyMix = pow(gather, 1.4)
                var body = deepL + (litL - deepL) * bodyMix
                let edgeDark = 1 - 0.52 * pow(u, 4.0)
                body *= edgeDark
                let keyDiffuse = LitBaker.sat(0.5 + 0.5 * (-0.5 * nx - 0.68 * ny + 0.54 * nz))
                body *= 0.62 + 0.62 * keyDiffuse
                // Where the light comes out again, low on the far side.
                let causticX = dx / R - 0.20, causticY = dy / R - 0.40
                let caustic = exp(-(causticX * causticX * 3.2 + causticY * causticY * 5.5))
                body += (litL * 0.9 + SIMD3<Float>(repeating: 0.12)) * caustic * 0.75

                // The clear surface: Fresnel, the room and the window's reflection.
                let fresnel = 0.045 + 0.955 * pow(1 - nv, 5)
                let rx = 2 * nz * nx, ry = 2 * nz * ny, rz = 2 * nz * nz - 1
                let up = -ry
                let room = 0.16 + 0.34 * LitBaker.smooth(-0.2, 0.9, up)
                var mirror = SIMD3<Float>(repeating: room)
                var colour = body * (1 - fresnel) + mirror * fresnel
                // Filmic shoulder, to sRGB.
                colour = SIMD3<Float>(colour.x / (1 + 0.22 * colour.x), colour.y / (1 + 0.22 * colour.y), colour.z / (1 + 0.22 * colour.z)) * 1.16
                let srgb = SIMD3<Float>(pow(LitBaker.sat(colour.x), 1 / 2.2), pow(LitBaker.sat(colour.y), 1 / 2.2),
                                        pow(LitBaker.sat(colour.z), 1 / 2.2))
                var dome = SIMD4<Float>(srgb.x, srgb.y, srgb.z, 1)
                // The window on the glass: a soft cap high on the lit side, brightest along its top.
                let qx = dx / R + 0.20, qy = dy / R + 0.47
                let cosT: Float = 0.92, sinT: Float = -0.39
                let ax = qx * cosT - qy * sinT, ay = qx * sinT + qy * cosT
                let cap = (ax * ax / (0.56 * 0.56) + ay * ay / (0.29 * 0.29)).squareRoot()
                let capShape = LitBaker.smooth(1.0, 0.72, cap)
                let capFade = 0.30 + 0.62 * LitBaker.smooth(0.28, -0.26, ay)
                dome = LitBaker.over(LitBaker.tint(1, 1, 1, capShape * capFade), dome)
                // A thin bright line on the rolled edge, on the side the light leaves through.
                let edgeRing = LitBaker.smooth(0.90, 0.985, u) * LitBaker.sat((dx * 0.6 + dy * 0.8) / max(dist, 0.001)) * 0.35
                dome = LitBaker.over(LitBaker.tint(1, 0.92, 0.9, edgeRing), dome)
                out = LitBaker.over(dome * coverage, out)
                return out
            }
        }
        guard let made else { return nil }
        return (made, margin)
    }

    /// The light on a coin: drawn over a flat round icon it becomes a domed, polished token with a turned rim.
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
                let u = min(dist / R, 1)
                let l = max(dist, 0.0001)
                let facing = (dx / l * Float(Lit.keyX) + dy / l * Float(Lit.keyY))
                // Shade across the dome: lighter to the light, deeper away from it.
                var out = SIMD4<Float>.zero
                let across = (dx * Float(Lit.keyX) + dy * Float(Lit.keyY)) / R
                let shade = LitBaker.sat(-across) * 0.26 * pow(u, 1.5)
                out = LitBaker.tint(0.10, 0.03, 0.05, shade)
                // The rolled rim, about a point and a half wide.
                let rimWidth = max(1.3, R * 0.075) / R
                let rim = LitBaker.smooth(1 - rimWidth * 1.6, 1 - rimWidth * 0.5, u)
                if facing > 0 {
                    out = LitBaker.over(LitBaker.tint(1, 1, 1, rim * facing * 0.62), out)
                } else {
                    out = LitBaker.over(LitBaker.tint(0.08, 0.02, 0.04, rim * -facing * 0.36), out)
                }
                out = LitBaker.over(LitBaker.tint(1, 1, 1, rim * 0.10), out)
                // The window, soft, high on the left.
                let wx = dx / R + 0.34, wy = dy / R + 0.46
                let gloss = LitBaker.smooth(0.62, 0.18, ((wx * wx) / 0.60 + (wy * wy) / 0.24).squareRoot())
                out = LitBaker.over(LitBaker.tint(1, 1, 1, gloss * 0.46), out)
                // A little light gathering low on the far side.
                let lx = dx / R - 0.30, ly = dy / R - 0.44
                let low = LitBaker.smooth(0.8, 0.1, (lx * lx + ly * ly).squareRoot()) * 0.14
                out = LitBaker.over(LitBaker.tint(1, 1, 1, low), out)
                return out * coverage
            }
        }
    }

    /// A coin's shadow on the plate, offset away from the light. Stretched to fit round the coin.
    static func coinShadow(diameter: CGFloat, scale: CGFloat) -> (image: CGImage, margin: CGFloat)? {
        let margin = ceil(diameter * 0.26)
        let side = diameter + 2 * margin
        let key = "coinShadow|\(diameter)|\(scale)"
        let made = cached(key) {
            let R = Float(diameter / 2), c = Float(side / 2)
            return LitBaker.render(pointSize: CGSize(width: side, height: side), scale: min(scale, 2)) { x, y in
                let dx = x - c - R * 0.10, dy = y - c - R * 0.18
                let d = (dx * dx + dy * dy).squareRoot()
                let contact = 0.40 * LitBaker.smooth(R * 1.12, R * 0.82, d)
                let soft = 0.20 * LitBaker.smooth(R * 1.5, R * 0.7, d)
                return LitBaker.over(LitBaker.tint(0.25, 0.14, 0.12, contact), LitBaker.tint(0.35, 0.22, 0.2, soft))
            }
        }
        guard let made else { return nil }
        return (made, margin)
    }

    /// A small lit LED: a coloured dome with a hot core. For status and legend dots.
    static func led(color c: UIColor, diameter: CGFloat, scale: CGFloat) -> (image: CGImage, margin: CGFloat)? {
        let margin = ceil(diameter * 0.8)
        let side = diameter + 2 * margin
        let key = "led|\(c.cgColor.components ?? [])|\(diameter)|\(scale)"
        let made = cached(key) {
            let col = color(c)
            let R = Float(diameter / 2), mid = Float(side / 2)
            let aa = 0.6 / Float(scale)
            return LitBaker.render(pointSize: CGSize(width: side, height: side), scale: scale) { x, y in
                let dx = x - mid, dy = y - mid
                let d = (dx * dx + dy * dy).squareRoot()
                let glow = 0.42 * pow(LitBaker.sat(1 - (d - R) / (R * 1.5)), 2)
                var out = LitBaker.tint(col.r, col.g, col.b, glow)
                let coverage = LitBaker.smooth(R + aa, R - aa, d)
                guard coverage > 0 else { return out }
                let u = min(d / R, 1)
                let shade = 1 - 0.34 * u * u
                let hot = LitBaker.sat(1 - ((dx + R * 0.2) * (dx + R * 0.2) + (dy + R * 0.3) * (dy + R * 0.3)).squareRoot() / (R * 0.75))
                let r = min(col.r * shade + hot * 0.7, 1), g = min(col.g * shade + hot * 0.7, 1), b = min(col.b * shade + hot * 0.7, 1)
                out = LitBaker.over(SIMD4(r, g, b, 1) * coverage, out)
                return out
            }
        }
        guard let made else { return nil }
        return (made, margin)
    }

    /// Lacquer on a pill: the top half's soft sheen, the light gathering at the bottom, a lit top lip.
    /// Drawn over the button's own colour, stretched in its centre.
    static func lacquer(height: CGFloat, radius: CGFloat, scale: CGFloat) -> CGImage? {
        let width = 2 * radius + 2
        let key = "lacquer|\(height)|\(radius)|\(scale)"
        return cached(key) {
            let w = Float(width), h = Float(height), r = Float(radius)
            return LitBaker.render(pointSize: CGSize(width: width, height: height), scale: scale) { x, y in
                let shape = LitBaker.roundedRect(x, y, width: w, height: h, radius: r)
                let aa = 0.6 / Float(scale)
                let coverage = LitBaker.smooth(aa, -aa, shape.distance)
                guard coverage > 0 else { return .zero }
                let v = y / h
                let sheen = LitBaker.smooth(0.58, 0.12, v) * 0.30
                let low = LitBaker.smooth(0.55, 1.0, v) * 0.22
                let shadeSide = LitBaker.sat(-(shape.nx * Float(Lit.keyX) + shape.ny * Float(Lit.keyY))) * LitBaker.smooth(-4, 0, shape.distance) * 0.26
                let lip = LitBaker.smooth(-1.5, -0.3, shape.distance) * LitBaker.sat(shape.nx * Float(Lit.keyX) + shape.ny * Float(Lit.keyY)) * 0.65
                var out = LitBaker.tint(1, 1, 1, sheen)
                out = LitBaker.over(LitBaker.tint(1, 0.78, 0.72, low), out)
                out = LitBaker.over(LitBaker.tint(0.18, 0.0, 0.03, shadeSide), out)
                out = LitBaker.over(LitBaker.tint(1, 1, 1, lip), out)
                return out * coverage
            }
        }
    }

    /// Grain below one code value, to keep the long gradients from banding.
    static let grain: UIImage? = {
        var state: UInt32 = 0x2F6E2B1
        func next() -> UInt32 {
            state ^= state << 13
            state ^= state >> 17
            state ^= state << 5
            return state
        }
        let image = LitBaker.render(pointSize: CGSize(width: 96, height: 96), scale: 1) { _, _ in
            let v = Float(next() & 0xFF) / 255
            return v > 0.5 ? LitBaker.tint(1, 1, 1, (v - 0.5) * 0.030) : LitBaker.tint(0.25, 0.15, 0.12, (0.5 - v) * 0.030)
        }
        return image.map { UIImage(cgImage: $0) }
    }()
}

// MARK: - Moving the light with the phone

/// The key light, nudged by how the phone is held. Whoever owns the motion sensor (the Wallet home's parallax,
/// which runs only while the hero is on screen and stops for Reduce Motion and Low Power) feeds it here;
/// every plate shifts its shadows and sheen a little. Nothing else runs: at rest the light is still.
public final class LitLightRig {
    public static let shared = LitLightRig()

    public private(set) var x: CGFloat = 0
    public private(set) var y: CGFloat = 0
    private let listeners = NSHashTable<AnyObject>.weakObjects()

    private init() {}

    public func add(_ listener: LitLightListener) {
        listeners.add(listener)
        if x != 0 || y != 0 { listener.lightDidMove(x: x, y: y) }
    }

    public func remove(_ listener: LitLightListener) {
        listeners.remove(listener)
    }

    /// Both axes run -1...1.
    public func set(x newX: CGFloat, y newY: CGFloat) {
        guard newX != x || newY != y else { return }
        x = newX
        y = newY
        for case let listener as LitLightListener in listeners.allObjects {
            listener.lightDidMove(x: x, y: y)
        }
    }
}

public protocol LitLightListener: AnyObject {
    /// The light moved. Both axes run -1...1.
    func lightDidMove(x: CGFloat, y: CGFloat)
}

// MARK: - Plates

/// A raised porcelain plate behind a view's content: its shadows on the page, a face turned a little to the
/// light, a rounded lit edge and, when asked, a colour bouncing onto its top edge from the planet above.
public final class LitPlateLayer: CALayer, LitLightListener {
    public var cornerRadiusValue: CGFloat = 24 { didSet { if oldValue != cornerRadiusValue { rebuild() } } }
    /// The size of the shadows, in points: bigger plates stand higher off the page.
    public var elevation: CGFloat = 16 { didSet { if oldValue != elevation { rebuild() } } }
    /// How brightly the page catches the light on the plate's lit side. Lower it under something drawn above.
    public var haloStrength: CGFloat = 1 { didSet { if oldValue != haloStrength { rebuild() } } }
    public var isPressedIn = false { didSet { if oldValue != isPressedIn { applyPress() } } }

    private let shadow = CALayer()
    private let face = CAGradientLayer()
    private let grain = CALayer()
    private let edge = CALayer()
    private let sheenClip = CALayer()
    private let sheen = CAGradientLayer()
    private let bounce = CAGradientLayer()
    private var shadowMargin: CGFloat = 0
    private var shadowShift = CGPoint.zero
    private var showsSheen = false

    public override init() {
        super.init()
        masksToBounds = false
        needsDisplayOnBoundsChange = false
        face.startPoint = CGPoint(x: 0.08, y: 0)
        face.endPoint = CGPoint(x: 0.92, y: 1)
        face.colors = [Lit.plateLit.cgColor, Lit.plateDeep.cgColor]
        face.masksToBounds = true
        grain.contentsScale = 1
        if let tile = LitImages.grain {
            grain.backgroundColor = UIColor(patternImage: tile).cgColor
        }
        sheenClip.masksToBounds = true
        sheen.startPoint = CGPoint(x: 0, y: 0.2)
        sheen.endPoint = CGPoint(x: 1, y: 0.8)
        sheen.colors = [UIColor.white.withAlphaComponent(0).cgColor, UIColor.white.withAlphaComponent(0.55).cgColor,
                        UIColor.white.withAlphaComponent(0).cgColor]
        sheen.locations = [0.34, 0.48, 0.64]
        sheenClip.addSublayer(sheen)
        bounce.type = .radial
        bounce.startPoint = CGPoint(x: 0.5, y: 0.5)
        bounce.endPoint = CGPoint(x: 1, y: 1)
        bounce.isHidden = true
        [shadow, face, grain, sheenClip, bounce, edge].forEach { addSublayer($0) }
        sheenClip.isHidden = true
        rebuild()
        LitLightRig.shared.add(self)
    }

    public override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The window's reflection sliding over the glaze with the light. For the largest plates only.
    public func setShowsSheen(_ on: Bool) {
        showsSheen = on
        sheenClip.isHidden = !on
    }

    /// A glaze of another colour: for a plate that means something, like a warning.
    public func setFace(top: UIColor, bottom: UIColor) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        face.colors = [top.cgColor, bottom.cgColor]
        CATransaction.commit()
    }

    /// The window's reflection crosses the plate once and settles: a flash of fresh light after new data.
    public func sweepSheen() {
        guard showsSheen, LitMotion.allowed else { return }
        let sweep = CABasicAnimation(keyPath: "transform.translation.x")
        sweep.fromValue = -bounds.width * 1.2
        sweep.toValue = 0
        sweep.duration = 0.95
        sweep.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.7, 0.2, 1)
        sweep.isAdditive = true
        sheen.add(sweep, forKey: "sweep")
    }

    /// A coloured light falling on the plate's top edge from above, centred at `centerX` (0...1).
    public func setBounce(color: UIColor?, centerX: CGFloat = 0.5, strength: CGFloat = 1) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if let color {
            bounce.isHidden = false
            bounce.colors = [color.withAlphaComponent(0.20 * strength).cgColor, color.withAlphaComponent(0.06 * strength).cgColor,
                             color.withAlphaComponent(0).cgColor]
            bounce.locations = [0, 0.45, 1]
            bounceCenter = centerX
            layoutBounce()
        } else {
            bounce.isHidden = true
        }
        CATransaction.commit()
    }

    private var bounceCenter: CGFloat = 0.5

    private func layoutBounce() {
        let width = bounds.width
        let radius = width * 0.62
        bounce.frame = CGRect(x: width * bounceCenter - radius, y: -0.42 * radius, width: 2 * radius, height: 0.84 * radius)
    }

    private func rebuild() {
        let scale = UIScreen.main.scale
        let radius = cornerRadiusValue
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if let baked = LitImages.plateShadow(radius: radius, spread: elevation, halo: haloStrength, scale: scale) {
            shadow.contents = baked.image
            shadowMargin = baked.margin
            shadow.contentsScale = scale
            let side = CGFloat(baked.image.width) / scale
            let middle = (radius + baked.margin) / side
            shadow.contentsCenter = CGRect(x: middle, y: middle, width: 2 / side, height: 2 / side)
        }
        let bevel = min(max(5, radius * 0.34), 9)
        edge.contents = LitImages.plateEdge(radius: radius, bevel: bevel, scale: scale)
        edge.contentsScale = scale
        let side = 2 * radius + 2 * bevel + 2
        let middle = (radius + bevel) / side
        edge.contentsCenter = CGRect(x: middle, y: middle, width: 2 / side, height: 2 / side)
        face.cornerRadius = radius
        grain.cornerRadius = radius
        grain.masksToBounds = true
        sheenClip.cornerRadius = radius
        CATransaction.commit()
        setNeedsLayout()
    }

    private func applyPress() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(isPressedIn ? 0.09 : 0.22)
        shadow.opacity = isPressedIn ? 0.45 : 1
        CATransaction.commit()
    }

    public override func layoutSublayers() {
        super.layoutSublayers()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let m = shadowMargin
        shadow.frame = bounds.insetBy(dx: -m, dy: -m).offsetBy(dx: shadowShift.x, dy: shadowShift.y)
        face.frame = bounds
        // Depth alone is not enough under Increase Contrast: the plate gets a real edge.
        let contrast = UIAccessibility.isDarkerSystemColorsEnabled
        face.borderWidth = contrast ? 1.5 : 0
        face.borderColor = contrast ? Lit.inkSecondary.cgColor : nil
        grain.frame = bounds
        edge.frame = bounds
        sheenClip.frame = bounds
        sheen.frame = bounds.insetBy(dx: -bounds.width * 0.6, dy: -bounds.height * 0.2)
        if !bounce.isHidden { layoutBounce() }
        CATransaction.commit()
    }

    /// Moves the shadows against the light and the sheen with it.
    public func lightDidMove(x: CGFloat, y: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let reach = elevation * 0.16
        shadowShift = CGPoint(x: x * reach, y: y * reach)
        let m = shadowMargin
        shadow.frame = bounds.insetBy(dx: -m, dy: -m).offsetBy(dx: shadowShift.x, dy: shadowShift.y)
        if showsSheen {
            sheen.transform = CATransform3DMakeTranslation(x * bounds.width * 0.52, y * bounds.height * 0.5, 0)
        }
        CATransaction.commit()
    }
}

// MARK: - Wells

/// A recess pressed into a plate. Stretched from a baked corner, so any width costs nothing.
public final class LitWellLayer: CALayer {
    public var cornerRadiusValue: CGFloat = 18 { didSet { rebuild() } }
    public var depth: CGFloat = 3 { didSet { rebuild() } }
    public var floorColor: UIColor? { didSet { rebuild() } }

    private var margin: CGFloat = 0

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
        guard let baked = LitImages.well(radius: cornerRadiusValue, depth: depth, scale: scale, floor: floorColor) else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        contents = baked.image
        margin = baked.margin
        let side = CGFloat(baked.image.width) / scale
        let corner = max(cornerRadiusValue, depth * 3) + baked.margin
        contentsCenter = CGRect(x: corner / side, y: corner / side, width: (2 / scale) / side, height: (2 / scale) / side)
        CATransaction.commit()
    }

    /// Lays the well over `rect`; its lip extends just outside.
    public func place(in rect: CGRect) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        frame = rect.insetBy(dx: -margin, dy: -margin)
        CATransaction.commit()
    }
}

// MARK: - Glass

/// A glass cabochon button seated in a well: the dome sinks into the well when pressed, its shadow tightens
/// and its light gathers. Put the glyph in `glyphView`.
public final class LitCabochonView: UIView {
    public let glyphView = UIImageView()
    private let well = LitWellLayer()
    private let dome = CALayer()
    private let wellDiameter: CGFloat
    private let domeDiameter: CGFloat
    private var pressedIn = false

    public init(lit: UIColor, deep: UIColor, domeDiameter: CGFloat, wellDiameter: CGFloat) {
        self.domeDiameter = domeDiameter
        self.wellDiameter = wellDiameter
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        if wellDiameter > 0 {
            well.cornerRadiusValue = wellDiameter / 2
            well.depth = 2.5
            layer.addSublayer(well)
        }
        layer.addSublayer(dome)
        setColors(lit: lit, deep: deep)
        glyphView.contentMode = .center
        glyphView.layer.shadowColor = UIColor.black.cgColor
        glyphView.layer.shadowOpacity = 0.32
        glyphView.layer.shadowRadius = 0.8
        glyphView.layer.shadowOffset = CGSize(width: 0.3, height: 0.8)
        addSubview(glyphView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setColors(lit: UIColor, deep: UIColor) {
        let scale = UIScreen.main.scale
        guard let baked = LitImages.cabochon(lit: lit, deep: deep, diameter: domeDiameter, scale: scale) else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dome.contents = baked.image
        dome.contentsScale = scale
        let side = domeDiameter + 2 * baked.margin
        dome.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        CATransaction.commit()
    }

    public override var intrinsicContentSize: CGSize { CGSize(width: wellDiameter, height: wellDiameter) }

    public override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let middle = CGPoint(x: bounds.midX, y: bounds.midY)
        well.place(in: CGRect(x: middle.x - wellDiameter / 2, y: middle.y - wellDiameter / 2, width: wellDiameter, height: wellDiameter))
        dome.position = middle
        glyphView.bounds = CGRect(x: 0, y: 0, width: domeDiameter, height: domeDiameter)
        glyphView.center = middle
        CATransaction.commit()
    }

    public func setPressed(_ pressed: Bool) {
        guard pressed != pressedIn else { return }
        pressedIn = pressed
        let reduce = UIAccessibility.isReduceMotionEnabled
        let scale: CGFloat = pressed && !reduce ? 0.93 : 1
        let brightness: Float = pressed ? 0.86 : 1
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let spring = CASpringAnimation(keyPath: "transform.scale")
        spring.fromValue = dome.presentation()?.value(forKeyPath: "transform.scale") ?? 1
        spring.toValue = scale
        spring.damping = pressed ? 30 : 13
        spring.stiffness = pressed ? 620 : 300
        spring.mass = 1
        spring.initialVelocity = pressed ? 0 : 2
        spring.duration = spring.settlingDuration
        dome.add(spring, forKey: "press")
        dome.transform = CATransform3DMakeScale(scale, scale, 1)
        dome.opacity = brightness
        CATransaction.commit()
        UIView.animate(withDuration: pressed ? 0.09 : 0.25, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
            self.glyphView.transform = CGAffineTransform(scaleX: scale, y: scale)
            self.glyphView.alpha = pressed ? 0.9 : 1
        }
    }

    /// Pops the dome up into the well, as it does the first time it is seen.
    public func popIn(after delay: CFTimeInterval) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let spring = CASpringAnimation(keyPath: "transform.scale")
        spring.fromValue = 0.2
        spring.toValue = 1
        spring.damping = 12
        spring.stiffness = 180
        spring.mass = 1
        spring.duration = spring.settlingDuration
        spring.beginTime = CACurrentMediaTime() + delay
        spring.fillMode = .backwards
        dome.add(spring, forKey: "pop")
        glyphView.layer.add(spring, forKey: "pop")
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        fade.duration = 0.16
        fade.beginTime = spring.beginTime
        fade.fillMode = .backwards
        dome.add(fade, forKey: "popFade")
        glyphView.layer.add(fade, forKey: "popFade")
    }
}

/// A coin's light and shadow for a flat round icon. Add `shadow` behind the icon and `light` over it.
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
            shadow.contentsScale = min(scale, 2)
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

/// A coloured status light. `pulse(true)` breathes it, which means work is really going on.
public final class LitLEDView: UIView {
    private let bulb = CALayer()
    private let diameter: CGFloat
    private var margin: CGFloat = 0

    public init(diameter: CGFloat) {
        self.diameter = diameter
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        layer.addSublayer(bulb)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setColor(_ color: UIColor) {
        let scale = UIScreen.main.scale
        guard let baked = LitImages.led(color: color, diameter: diameter, scale: scale) else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        bulb.contents = baked.image
        bulb.contentsScale = scale
        margin = baked.margin
        bulb.bounds = CGRect(x: 0, y: 0, width: diameter + 2 * margin, height: diameter + 2 * margin)
        bulb.position = CGPoint(x: bounds.midX, y: bounds.midY)
        CATransaction.commit()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        bulb.position = CGPoint(x: bounds.midX, y: bounds.midY)
        CATransaction.commit()
    }

    public func pulse(_ on: Bool) {
        if on && !UIAccessibility.isReduceMotionEnabled && !ProcessInfo.processInfo.isLowPowerModeEnabled {
            guard bulb.animation(forKey: "pulse") == nil else { return }
            let breath = CABasicAnimation(keyPath: "opacity")
            breath.fromValue = 1
            breath.toValue = 0.35
            breath.duration = 0.7
            breath.autoreverses = true
            breath.repeatCount = .infinity
            breath.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            bulb.add(breath, forKey: "pulse")
        } else {
            bulb.removeAnimation(forKey: "pulse")
        }
    }
}

// MARK: - Page

/// The porcelain page: the plain colour, light falling off from the top left, a little grain.
public final class LitPageView: UIView {
    private let falloff = CAGradientLayer()
    private let grain = CALayer()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = Lit.page
        falloff.type = .radial
        falloff.startPoint = CGPoint(x: 0.1, y: 0.0)
        falloff.endPoint = CGPoint(x: 1.2, y: 1.1)
        falloff.colors = [UIColor.white.withAlphaComponent(0.34).cgColor, UIColor.white.withAlphaComponent(0.0).cgColor,
                          UIColor(litHex: 0x6B4A40, alpha: 0.10).cgColor]
        falloff.locations = [0, 0.55, 1]
        layer.addSublayer(falloff)
        if let tile = LitImages.grain {
            grain.backgroundColor = UIColor(patternImage: tile).cgColor
            layer.addSublayer(grain)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        falloff.frame = bounds
        grain.frame = bounds
        CATransaction.commit()
    }
}

// MARK: - Engraved lines and letterpress

public extension NSAttributedString {
    /// Text pressed into a plate: the light catches the far edge of each stroke.
    static func letterpress(_ text: String, attributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        let shadow = NSShadow()
        shadow.shadowColor = UIColor.white.withAlphaComponent(0.9)
        shadow.shadowOffset = CGSize(width: 0.35, height: 0.7)
        shadow.shadowBlurRadius = 0
        var all = attributes
        all[.shadow] = shadow
        return NSAttributedString(string: text, attributes: all)
    }
}

/// A line cut in the glaze: a dark edge and, just under it, a lit one.
public final class LitEngravedLine: UIView {
    private let dark = CALayer()
    private let light = CALayer()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        dark.backgroundColor = Lit.engraveDark.cgColor
        light.backgroundColor = Lit.engraveLight.cgColor
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

// MARK: - Lacquer

/// The gloss on a filled button: a sheen on its top half, light gathering along its bottom, a lit top lip,
/// and a shadow of its own colour on the plate below it. Add `layer` under the button's content.
public final class LitLacquer {
    public let layer = CALayer()
    private var built: (height: CGFloat, radius: CGFloat)?

    public init() {}

    public func layout(in host: UIView, radius: CGFloat, color: UIColor?) {
        let scale = UIScreen.main.scale
        let height = host.bounds.height
        guard height > 0 else { return }
        let r = min(radius, height / 2)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if built?.height != height || built?.radius != r {
            built = (height, r)
            layer.contents = LitImages.lacquer(height: height, radius: r, scale: scale)
            layer.contentsScale = scale
            let width = 2 * r + 2
            layer.contentsCenter = CGRect(x: r / width, y: 0, width: 2 / width, height: 1)
        }
        layer.frame = host.bounds
        let shadowHost = host.layer
        if let color {
            shadowHost.shadowColor = color.cgColor
            shadowHost.shadowOpacity = 0.42
            shadowHost.shadowRadius = 8
            shadowHost.shadowOffset = CGSize(width: 2.5, height: 5)
            shadowHost.shadowPath = UIBezierPath(roundedRect: host.bounds, cornerRadius: r).cgPath
        } else {
            shadowHost.shadowOpacity = 0
        }
        CATransaction.commit()
    }
}

// MARK: - Motion

/// The press every lit control shares: in quickly and firmly, out on a small spring.
public enum LitMotion {
    public static var allowed: Bool { !UIAccessibility.isReduceMotionEnabled }

    public static func press(_ view: UIView, pressed: Bool, scale: CGFloat = 0.965) {
        let target: CGFloat = pressed && allowed ? scale : 1
        if pressed {
            UIView.animate(withDuration: 0.09, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseOut]) {
                view.transform = CGAffineTransform(scaleX: target, y: target)
            }
        } else {
            UIView.animate(withDuration: 0.42, delay: 0, usingSpringWithDamping: 0.52, initialSpringVelocity: 0,
                           options: [.beginFromCurrentState, .allowUserInteraction]) {
                view.transform = .identity
            }
        }
    }

    /// Rises into place and fades in, once. Rows and cards do this the first time they are seen.
    public static func rise(_ view: UIView, by distance: CGFloat = 12, after delay: CFTimeInterval = 0) {
        guard allowed else { return }
        let layer = view.layer
        let begin = CACurrentMediaTime() + delay
        let move = CASpringAnimation(keyPath: "transform.translation.y")
        move.fromValue = distance
        move.toValue = 0
        move.damping = 16
        move.stiffness = 190
        move.mass = 1
        move.duration = move.settlingDuration
        move.beginTime = begin
        move.fillMode = .backwards
        move.isAdditive = false
        layer.add(move, forKey: "lit.rise")
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        fade.duration = 0.28
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
            UIView.animate(withDuration: 0.5, delay: Double(order) * 0.035, usingSpringWithDamping: 0.82, initialSpringVelocity: 0,
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

/// A round image struck as a coin.
public final class LitCoinImageView: UIView {
    public let imageView = UIImageView()
    private let coin = LitCoinLayers()

    public init(diameter: CGFloat) {
        super.init(frame: CGRect(x: 0, y: 0, width: diameter, height: diameter))
        imageView.frame = bounds
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = diameter / 2
        imageView.clipsToBounds = true
        // A picture that has not loaded leaves a plain porcelain coin, not a dark hole over its shadow.
        imageView.backgroundColor = Lit.plateLit
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

/// Stands any view on a plate, or presses it into a well, behind its content. Call `layout` when its bounds change.
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

    public init(host: UIView) {
        self.host = host
        host.backgroundColor = .clear
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

    /// Lays the plate or well over the host's bounds, never rounder than a capsule.
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

/// A lacquered fill: a gradient under the gloss. For buttons that take a background view.
public final class LitLacquerFill: UIView {
    private let gradient = CAGradientLayer()
    private let gloss = LitLacquer()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        layer.addSublayer(gradient)
        layer.addSublayer(gloss.layer)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func apply(_ colors: NeonGradient) {
        gradient.colors = colors.cgColors
        gradient.locations = colors.nsLocations
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let radius = bounds.height / 2
        gradient.frame = bounds
        gradient.cornerRadius = radius
        gloss.layout(in: self, radius: radius, color: nil)
        CATransaction.commit()
    }
}
