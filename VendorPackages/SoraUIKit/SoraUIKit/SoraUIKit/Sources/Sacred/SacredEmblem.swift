import UIKit

/// The two line colours of the figures: ink, and the gold of a mended bowl.
public enum SacredInk {
    public static let line = Lit.ink
    public static let gold = UIColor(litHex: 0xA87A2E)
    /// The launch page, and the same two lines as they show on it.
    public static let night = UIColor(litHex: 0x06060B)
    public static let nightLine = UIColor(litHex: 0xEFE7E1)
    public static let nightGold = UIColor(litHex: 0xE2B45A)
}

/// The SORA mark: the red disc with 天 in white, as the logo is. Drawn once per size, for the launch flight
/// and the PIN screen. The home's ray-traced ball carries the same mark.
public enum SacredPlanet {
    private static let cache = NSCache<NSString, UIImage>()

    public static func image(diameter: CGFloat, scale: CGFloat = UIScreen.main.scale) -> UIImage {
        let side = max(2, diameter)
        let key = "\(Int((side * 10).rounded()))@\(scale)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        let size = CGSize(width: side, height: side)
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let canvas = context.cgContext
            canvas.addEllipse(in: CGRect(origin: .zero, size: size))
            canvas.clip()
            canvas.setFillColor(Lit.brandRed.cgColor)
            canvas.fill(CGRect(origin: .zero, size: size))
            canvas.addPath(PortfolioLitMark.path(side: side))
            canvas.setFillColor(UIColor.white.cgColor)
            canvas.fillPath()
        }
        cache.setObject(image, forKey: key)
        return image
    }

    /// The planet's red light on the page round it.
    static func glowLayer(planetRadius: CGFloat) -> CAGradientLayer {
        let glow = CAGradientLayer()
        glow.type = .radial
        glow.startPoint = CGPoint(x: 0.5, y: 0.5)
        glow.endPoint = CGPoint(x: 1, y: 1)
        glow.colors = [Lit.lacquerRed.withAlphaComponent(0).cgColor, Lit.lacquerRed.withAlphaComponent(0.12).cgColor,
                       Lit.lacquerRed.withAlphaComponent(0).cgColor]
        glow.locations = [0.38, 0.44, 1]
        let side = planetRadius * 4.2
        glow.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        return glow
    }
}

/// Where the emblem (the planet in its ring) stands on a screen.
public enum SacredEmblemLayout {
    public struct Placement: Equatable {
        public let centre: CGPoint
        public let ringRadius: CGFloat
        public var planetRadius: CGFloat { ringRadius / SacredEmblemLayout.ringToPlanet }
        /// The square the emblem view takes: the ring and its stroke.
        public var frame: CGRect {
            CGRect(x: centre.x - ringRadius - 2, y: centre.y - ringRadius - 2,
                   width: (ringRadius + 2) * 2, height: (ringRadius + 2) * 2)
        }

        public init(centre: CGPoint, ringRadius: CGFloat) {
            self.centre = centre
            self.ringRadius = ringRadius
        }
    }

    /// The ring's radius over the planet's.
    public static let ringToPlanet: CGFloat = 2.05
    static let keypadHeight: CGFloat = 368
    static let keypadBottom: CGFloat = 18
    static let titleHalfHeight: CGFloat = 16
    static let margin: CGFloat = 18
    static let largest: CGFloat = 132
    static let smallest: CGFloat = 84

    /// The room a PIN screen leaves above its title, between the top of the screen and the keypad. Nil on
    /// a screen too short to hold the emblem and the title both.
    public static func pinPlacement(bounds: CGRect, safeArea: UIEdgeInsets) -> Placement? {
        // Two pages side by side (an unfolded screen in landscape): the emblem, the title and the dots
        // stand on the left page and the keypad on the right. The launch flight asks here too, so the
        // planet lands where that PIN screen shows it.
        if let pages = LayoutCanvas(size: bounds.size).pages(in: bounds) {
            return pagedPinPlacement(page: pages.left, safeArea: safeArea)
        }
        let top = bounds.minY + safeArea.top
        let keypadTop = bounds.maxY - safeArea.bottom - keypadBottom - keypadHeight
        let room = (keypadTop - top) / 2 - titleHalfHeight
        let diameter = min(largest, room - 2 * margin)
        guard diameter >= smallest else { return nil }
        return Placement(centre: CGPoint(x: bounds.midX, y: top + room / 2), ringRadius: diameter / 2)
    }

    /// What stands under the emblem on a PIN screen's own page: the gap, the title, the gap and the dots.
    static let pagedGroupBelow: CGFloat = margin + titleHalfHeight * 2 + 16 + 24

    /// The emblem on the left page of a two-page PIN screen: the emblem, the title and the dots are
    /// one group in the middle of the page.
    public static func pagedPinPlacement(page: CGRect, safeArea: UIEdgeInsets) -> Placement {
        let top = page.minY + safeArea.top
        let bottom = page.maxY - safeArea.bottom
        let diameter = min(largest, max(smallest, bottom - top - pagedGroupBelow - 2 * margin))
        return Placement(centre: CGPoint(x: page.midX, y: (top + bottom) / 2 - pagedGroupBelow / 2),
                         ringRadius: diameter / 2)
    }

    /// The middle of the title under that emblem.
    public static func pagedPinTitleCentreY(under place: Placement) -> CGFloat {
        place.centre.y + place.ringRadius + margin + titleHalfHeight
    }

    /// Where the flight ends when the next screen has no place of its own: on the upper golden section.
    public static func fallback(bounds: CGRect, safeArea: UIEdgeInsets) -> Placement {
        let top = bounds.minY + safeArea.top
        let height = bounds.maxY - safeArea.bottom - top
        let radius = min(largest / 2, max(smallest / 2, bounds.width * 0.16))
        return Placement(centre: CGPoint(x: bounds.midX, y: top + height * (1 - 1 / SacredGeometry.phi)),
                         ringRadius: radius)
    }
}

/// The planet in its ring of six circles. On the PIN screen the ring is the lock: each digit draws one
/// more circle out from behind the planet, and the sixth closes the rim.
public final class SacredEmblemView: UIView {
    public let planetView = UIImageView()
    public var litColor: UIColor = SacredInk.gold
    /// The share of the code entered, 0...1.
    public private(set) var share: CGFloat = 0

    private let glow = SacredPlanet.glowLayer(planetRadius: 1)
    private let ringGroup = CALayer()
    private let base = CAShapeLayer()
    private let petals: [CAShapeLayer] = (0..<6).map { _ in CAShapeLayer() }
    private let rim = CAShapeLayer()
    private var builtSide: CGFloat = 0

    public var ringRadius: CGFloat { max(0, min(bounds.width, bounds.height) / 2 - 2) }
    public var planetRadius: CGFloat { ringRadius / SacredEmblemLayout.ringToPlanet }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        backgroundColor = .clear
        layer.addSublayer(glow)
        layer.addSublayer(ringGroup)
        base.fillColor = nil
        base.strokeColor = SacredInk.line.cgColor
        base.lineWidth = 0.8
        base.opacity = 0.5
        ringGroup.addSublayer(base)
        for petal in petals + [rim] {
            petal.fillColor = nil
            petal.lineWidth = 1.6
            petal.lineCap = .round
            petal.strokeEnd = 0
            ringGroup.addSublayer(petal)
        }
        planetView.contentMode = .scaleAspectFit
        addSubview(planetView)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    public override func layoutSubviews() {
        super.layoutSubviews()
        let side = min(bounds.width, bounds.height)
        guard side > 0, abs(side - builtSide) > 0.01 else { return }
        builtSide = side
        let middle = CGPoint(x: bounds.midX, y: bounds.midY)
        var toMiddle = CGAffineTransform(translationX: middle.x, y: middle.y)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ringGroup.bounds = bounds
        ringGroup.position = middle
        for shape in [base, rim] + petals { shape.frame = bounds }
        base.path = SacredGeometry.path(for: .seed, radius: ringRadius).copy(using: &toMiddle)
        for (index, petal) in petals.enumerated() {
            petal.path = SacredGeometry.seedCircle(index, radius: ringRadius).copy(using: &toMiddle)
        }
        rim.path = SacredGeometry.circle(radius: ringRadius).copy(using: &toMiddle)
        let glowSide = planetRadius * 4.2
        glow.bounds = CGRect(x: 0, y: 0, width: glowSide, height: glowSide)
        glow.position = middle
        CATransaction.commit()
        planetView.bounds = CGRect(x: 0, y: 0, width: planetRadius * 2, height: planetRadius * 2)
        planetView.center = middle
        // Baked a little finer than the screen: the flight to the home enlarges it.
        planetView.image = SacredPlanet.image(diameter: planetRadius * 2, scale: UIScreen.main.scale * 1.5)
        applyShare(animated: false)
    }

    /// How much of the code is entered. Each sixth draws one circle.
    public func setShare(_ value: CGFloat, animated: Bool) {
        share = min(1, max(0, value))
        applyShare(animated: animated && LitMotion.allowed)
    }

    private func applyShare(animated: Bool) {
        let colour = litColor.cgColor
        for (index, petal) in petals.enumerated() {
            petal.strokeColor = colour
            setEnd(min(1, max(0, share * 6 - CGFloat(index))), on: petal, animated: animated, duration: SacredGeometry.beat(1))
        }
        rim.strokeColor = colour
        setEnd(share >= 1 ? 1 : 0, on: rim, animated: animated, duration: SacredGeometry.beat(2))
    }

    private func setEnd(_ end: CGFloat, on shape: CAShapeLayer, animated: Bool, duration: TimeInterval) {
        let from = shape.presentation()?.strokeEnd ?? shape.strokeEnd
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shape.strokeEnd = end
        CATransaction.commit()
        shape.removeAnimation(forKey: "sacred.end")
        guard animated, abs(from - end) > 0.001 else { return }
        let draw = CABasicAnimation(keyPath: "strokeEnd")
        draw.fromValue = from
        draw.toValue = end
        draw.duration = duration
        draw.timingFunction = CAMediaTimingFunction(name: .easeOut)
        shape.add(draw, forKey: "sacred.end")
    }

    /// A wrong code: the whole ring shows in the error colour and shivers. `setShare` clears it.
    public func showError(color: UIColor) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for shape in petals + [rim] {
            shape.removeAnimation(forKey: "sacred.end")
            shape.strokeColor = color.cgColor
            shape.strokeEnd = 1
        }
        CATransaction.commit()
        guard LitMotion.allowed else { return }
        let shiver = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        shiver.values = [0, -0.10, 0.08, -0.05, 0.02, 0]
        shiver.duration = 0.5
        shiver.calculationMode = .cubic
        ringGroup.add(shiver, forKey: "sacred.shiver")
    }

    /// The gate opens: the ring turns a twelfth, widens past the screen's edge and is gone.
    public func openGate() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ringGroup.opacity = 0
        glow.opacity = 0
        CATransaction.commit()
        guard LitMotion.allowed else { return }
        let duration = SacredGeometry.beat(3)
        let widen = CABasicAnimation(keyPath: "transform.scale")
        widen.fromValue = 1
        widen.toValue = 3.2
        let turn = CABasicAnimation(keyPath: "transform.rotation.z")
        turn.fromValue = 0
        turn.toValue = CGFloat.pi / 6
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [1, 0.85, 0]
        fade.keyTimes = [0, 0.4, 1]
        let group = CAAnimationGroup()
        group.animations = [widen, turn, fade]
        group.duration = duration
        group.timingFunction = CAMediaTimingFunction(controlPoints: 0.5, 0, 0.9, 0.6)
        ringGroup.add(group, forKey: "sacred.open")
        let dim = CABasicAnimation(keyPath: "opacity")
        dim.fromValue = 1
        dim.toValue = 0
        dim.duration = duration
        glow.add(dim, forKey: "sacred.open")
    }
}

/// Carries the PIN screen's planet across the change of screens and sets it down on the home's planet,
/// so unlocking reads as going through the gate rather than as one screen replacing another.
public enum SacredUnlockFlight {
    public enum Destination {
        /// The home is not on screen yet.
        case waiting
        /// The screen that came has no planet.
        case nowhere
        /// The home's planet, in the window's coordinates.
        case planet(CGRect)
    }

    /// How long the planet waits for the home before it gives up and fades.
    public static let patience: CFTimeInterval = 2.5

    /// Returns false, having changed nothing, when motion is off or the emblem is not showing.
    /// `landed` runs exactly once after a `.planet` answer, whatever else happens.
    @discardableResult
    public static func begin(from emblem: SacredEmblemView, in window: UIWindow,
                             destination: @escaping () -> Destination,
                             landed: @escaping () -> Void = {}) -> Bool {
        guard FxPolicy.current.litMotion, emblem.window === window, !emblem.isHidden, emblem.alpha > 0,
              emblem.planetRadius > 0 else { return false }
        let frame = emblem.convert(emblem.bounds, to: window)
        emblem.removeFromSuperview()
        emblem.translatesAutoresizingMaskIntoConstraints = true
        emblem.frame = frame
        window.addSubview(emblem)
        emblem.setShare(1, animated: false)
        emblem.openGate()
        let started = CACurrentMediaTime()
        func look() {
            guard emblem.superview === window else { return }
            // Each new root view lands on top; the planet stays above it.
            window.bringSubviewToFront(emblem)
            switch destination() {
            case .planet(let target):
                land(emblem, on: target, landed: landed)
            case .nowhere:
                leave(emblem)
            case .waiting:
                if CACurrentMediaTime() - started > patience {
                    leave(emblem)
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { look() }
                }
            }
        }
        look()
        return true
    }

    private static func land(_ emblem: SacredEmblemView, on target: CGRect, landed: @escaping () -> Void) {
        let scale = max(0.2, target.width / 2 / max(1, emblem.planetRadius))
        UIView.animate(withDuration: SacredGeometry.beat(3), delay: 0, usingSpringWithDamping: 0.84,
                       initialSpringVelocity: 0, options: [.beginFromCurrentState]) {
            emblem.center = CGPoint(x: target.midX, y: target.midY)
            emblem.transform = CGAffineTransform(scaleX: scale, y: scale)
        } completion: { _ in
            landed()
            UIView.animate(withDuration: SacredGeometry.beat(1), delay: 0, options: [.curveEaseOut]) {
                emblem.alpha = 0
            } completion: { _ in
                emblem.removeFromSuperview()
            }
        }
    }

    private static func leave(_ emblem: SacredEmblemView) {
        UIView.animate(withDuration: SacredGeometry.beat(2), delay: 0, options: [.curveEaseOut]) {
            emblem.alpha = 0
        } completion: { _ in
            emblem.removeFromSuperview()
        }
    }
}
