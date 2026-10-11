import UIKit

/// Outline of a Neon surface. Used for the fill, the gradient hairline and
/// the `shadowPath`, so all three always agree.
public enum NeonShape: Equatable {
    case rounded(CGFloat)
    case capsule
    /// Hero card (spec §6): rounded corners and a 45° cut on the top-right
    /// corner. Not mirrored in RTL; it is a brand mark.
    case chamfer(radius: CGFloat, cut: CGFloat)

    public func path(in rect: CGRect) -> UIBezierPath {
        switch self {
        case let .rounded(radius):
            return UIBezierPath(roundedRect: rect, cornerRadius: max(0, min(radius, min(rect.width, rect.height) / 2)))
        case .capsule:
            return UIBezierPath(roundedRect: rect, cornerRadius: min(rect.width, rect.height) / 2)
        case let .chamfer(radius, cut):
            let r = max(0, min(radius, min(rect.width, rect.height) / 2))
            let k = max(0, min(cut, min(rect.width, rect.height) / 2))
            let path = UIBezierPath()
            path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - k, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + k))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
            path.addArc(withCenter: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r,
                        startAngle: 0, endAngle: .pi / 2, clockwise: true)
            path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
            path.addArc(withCenter: CGPoint(x: rect.minX + r, y: rect.maxY - r), radius: r,
                        startAngle: .pi / 2, endAngle: .pi, clockwise: true)
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
            path.addArc(withCenter: CGPoint(x: rect.minX + r, y: rect.minY + r), radius: r,
                        startAngle: .pi, endAngle: .pi * 1.5, clockwise: true)
            path.close()
            return path
        }
    }
}

/// Draws the glass sheen and a 135° gradient hairline (spec §4.3.1, §4.4).
///
/// Drawn with Core Graphics into the layer's own backing store once per size
/// or theme change. Unlike a `CAShapeLayer` mask, this needs no offscreen
/// pass while the surface scrolls.
public final class GradientBorderLayer: CALayer {
    public var shape: NeonShape = .rounded(24) { didSet { if shape != oldValue { setNeedsDisplay() } } }
    public private(set) var lineWidth: CGFloat = 1
    /// Optional fill drawn under the sheen (used by `GlassView`).
    public var fill: UIColor? { didSet { setNeedsDisplay() } }
    private var border: NeonGradient?
    private var sheen: NeonGradient?

    public override init() {
        super.init()
        commonInit()
    }

    public override init(layer: Any) {
        super.init(layer: layer)
        if let other = layer as? GradientBorderLayer {
            shape = other.shape
            lineWidth = other.lineWidth
            border = other.border
            sheen = other.sheen
            fill = other.fill
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        isOpaque = false
        needsDisplayOnBoundsChange = true
        contentsScale = UITraitCollection.current.displayScale > 0 ? UITraitCollection.current.displayScale : 2
    }

    /// - Parameters:
    ///   - border: hairline colours; nil draws no hairline.
    ///   - sheen: vertical top highlight; nil draws none.
    public func apply(border: NeonGradient?, lineWidth: CGFloat = 1, sheen: NeonGradient? = nil) {
        self.border = border
        self.lineWidth = lineWidth
        self.sheen = sheen
        setNeedsDisplay()
    }

    public override func action(forKey event: String) -> CAAction? {
        // Frame and contents updates follow the owner without implicit animation.
        NSNull()
    }

    public override func draw(in ctx: CGContext) {
        let rect = bounds
        guard rect.width > 1, rect.height > 1 else { return }
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

        if let fill {
            ctx.saveGState()
            ctx.addPath(shape.path(in: rect).cgPath)
            ctx.setFillColor(fill.cgColor)
            ctx.fillPath()
            ctx.restoreGState()
        }

        if let sheen, let gradient = CGGradient(colorsSpace: space, colors: sheen.cgColors as CFArray,
                                                locations: sheen.locations) {
            ctx.saveGState()
            ctx.addPath(shape.path(in: rect).cgPath)
            ctx.clip()
            ctx.drawLinearGradient(gradient, start: CGPoint(x: rect.minX, y: rect.minY),
                                   end: CGPoint(x: rect.minX, y: rect.maxY), options: [])
            ctx.restoreGState()
        }

        if let border, lineWidth > 0, let gradient = CGGradient(colorsSpace: space, colors: border.cgColors as CFArray,
                                                                 locations: border.locations) {
            let inset = lineWidth / 2
            let strokeShape: NeonShape
            switch shape {
            case let .rounded(radius): strokeShape = .rounded(max(0, radius - inset))
            case .capsule: strokeShape = .capsule
            case let .chamfer(radius, cut): strokeShape = .chamfer(radius: max(0, radius - inset), cut: cut)
            }
            ctx.saveGState()
            ctx.addPath(strokeShape.path(in: rect.insetBy(dx: inset, dy: inset)).cgPath)
            ctx.setLineWidth(lineWidth)
            ctx.replacePathWithStrokedPath()
            ctx.clip()
            ctx.drawLinearGradient(gradient, start: CGPoint(x: rect.minX, y: rect.minY),
                                   end: CGPoint(x: rect.maxX, y: rect.maxY), options: [])
            ctx.restoreGState()
        }
    }
}

/// A view backed by a `CAGradientLayer` (CTA fills, swap disc, chrome lines).
public final class NeonGradientView: UIView {
    public override class var layerClass: AnyClass { CAGradientLayer.self }

    public var gradientLayer: CAGradientLayer {
        // swiftlint:disable:next force_cast
        layer as! CAGradientLayer
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        layer.cornerCurve = .continuous
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    /// Horizontal (90°) by default, like every CTA gradient in the spec.
    public func apply(_ gradient: NeonGradient,
                      start: CGPoint = CGPoint(x: 0, y: 0.5),
                      end: CGPoint = CGPoint(x: 1, y: 0.5)) {
        gradientLayer.colors = gradient.cgColors
        gradientLayer.locations = gradient.nsLocations
        gradientLayer.startPoint = start
        gradientLayer.endPoint = end
    }
}

/// The MINIMAL-tier stand-in for a glow (spec §4.0, §4.5): a 1.5 pt ring in
/// the glow colour at 80 %. It is drawn just outside the control (a 1.5 pt
/// gap), so the control's own fill never hides it. A plain border: no blur,
/// no offscreen pass.
public final class NeonRingLayer: CALayer {
    public static let width: CGFloat = 1.5
    public static let gap: CGFloat = 1.5

    public override init() {
        super.init()
        borderWidth = Self.width
        cornerCurve = .continuous
        backgroundColor = UIColor.clear.cgColor
    }

    public override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    public func apply(_ glow: GlowSpec) {
        borderColor = glow.color.withAlphaComponent(0.8).cgColor
    }

    /// Places the ring around `rect` (in the superlayer's coordinates).
    public func layout(around rect: CGRect, cornerRadius: CGFloat) {
        let outset = Self.width + Self.gap
        frame = rect.insetBy(dx: -outset, dy: -outset)
        self.cornerRadius = cornerRadius + outset
    }

    public override func action(forKey event: String) -> CAAction? {
        NSNull()
    }
}

public extension UIView {
    /// True inside a table or collection cell. Glows are never drawn there
    /// (spec §4.5, §10.3: "0 inside lists").
    var neonIsInsideListCell: Bool {
        var ancestor = superview
        while let current = ancestor {
            if current is UITableViewCell || current is UICollectionViewCell {
                return true
            }
            ancestor = current.superview
        }
        return false
    }
}

public extension CALayer {
    /// Applies a Neon shadow with an explicit path (never a content-derived
    /// shadow, which costs an offscreen pass per frame).
    func applyNeonShadow(_ spec: ShadowSpec?, path: CGPath?) {
        guard let spec else {
            shadowOpacity = 0
            shadowPath = nil
            return
        }
        shadowColor = spec.color.cgColor
        shadowOpacity = spec.alpha
        shadowRadius = spec.blur / 2
        shadowOffset = spec.offset
        shadowPath = path
    }

    /// Applies a glow at its rest alpha, or clears it.
    func applyNeonGlow(_ spec: GlowSpec?, path: CGPath?, alpha: Float? = nil) {
        guard let spec else {
            shadowOpacity = 0
            shadowPath = nil
            return
        }
        shadowColor = spec.color.cgColor
        shadowOpacity = alpha ?? spec.rest
        shadowRadius = spec.blur / 2
        shadowOffset = CGSize(width: 0, height: spec.offsetY)
        shadowPath = path
    }
}
