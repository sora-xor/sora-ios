import UIKit

/// The static page backdrop (spec §4.2): the canvas colour lit by faint
/// radial washes. Built once per size; never animated, never scrolls.
/// Safe Mode (`style = .safe`) uses only cyan and mint: no red, no grid.
public final class AuroraView: UIView {
    public enum Style {
        case standard
        case safe
    }

    public var style: Style = .standard { didSet { if style != oldValue { rebuild() } } }
    /// Grid texture: Splash, Welcome and hero surfaces only (spec §4.2.3).
    public var showsGrid: Bool = false { didSet { if showsGrid != oldValue { rebuild() } } }

    private var orbs: [CAGradientLayer] = []
    private let gridContainer = CALayer()
    private var builtSize: CGSize = .zero
    private var observer: NSObjectProtocol?

    public init(style: Style = .standard, showsGrid: Bool = false) {
        self.style = style
        self.showsGrid = showsGrid
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        layer.addSublayer(gridContainer)
        SoramitsuUI.updates.addObserver(self)
        observer = NotificationCenter.default.addObserver(forName: .neonFxChanged, object: nil, queue: .main) {
            [weak self] _ in self?.rebuild()
        }
        rebuild()
    }

    public override convenience init(frame: CGRect) {
        self.init(style: .standard)
        self.frame = frame
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        observer.map(NotificationCenter.default.removeObserver)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.size != builtSize {
            rebuild()
        }
    }

    private func rebuild() {
        let tokens = NeonTokens.current
        backgroundColor = tokens.canvas
        builtSize = bounds.size
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        orbs.forEach { $0.removeFromSuperlayer() }
        orbs = []
        let width = bounds.width
        let height = bounds.height
        guard width > 0, height > 0 else {
            CATransaction.commit()
            return
        }

        // (colour, centre x, centre y, radius) as fractions of the screen (spec §2.1).
        let blobs: [(UIColor, CGFloat, CGFloat, CGFloat)]
        switch style {
        case .standard:
            blobs = [(tokens.auroraCyan, 0.15, -0.05, 0.90),
                     (tokens.auroraMagenta, 1.00, 0.20, 0.80),
                     (tokens.auroraRed, 0.30, 0.32, 0.70)]
        case .safe:
            blobs = [(tokens.safeAuroraCyan, 0.15, -0.05, 0.90),
                     (tokens.safeAuroraMint, 0.85, 0.25, 0.80)]
        }
        for (color, x, y, r) in blobs {
            let orb = CAGradientLayer()
            orb.type = .radial
            orb.colors = [color.cgColor, color.withAlphaComponent(0).cgColor]
            orb.startPoint = CGPoint(x: 0.5, y: 0.5)
            orb.endPoint = CGPoint(x: 1, y: 1)
            let radius = r * width
            orb.frame = CGRect(x: x * width - radius, y: y * height - radius, width: radius * 2, height: radius * 2)
            layer.insertSublayer(orb, below: gridContainer)
            orbs.append(orb)
        }

        gridContainer.sublayers?.forEach { $0.removeFromSuperlayer() }
        gridContainer.frame = bounds
        if showsGrid, style == .standard, FxPolicy.current.ambientDetail {
            gridContainer.addSublayer(gridLayer(color: tokens.gridMinor, major: false))
            gridContainer.addSublayer(gridLayer(color: tokens.gridMajor, major: true))
            // Static texture: rasterising once is safe and keeps scrolling cheap.
            gridContainer.shouldRasterize = true
            gridContainer.rasterizationScale = traitCollection.displayScale
        }
        CATransaction.commit()
    }

    /// Lines every 24 pt (major every 4th), fading radially from the top-end corner.
    private func gridLayer(color: UIColor, major: Bool) -> CALayer {
        let step: CGFloat = 24
        let lines = UIBezierPath()
        var index = 0
        var x: CGFloat = 0
        while x <= bounds.width {
            if (index % 4 == 0) == major {
                lines.move(to: CGPoint(x: x + 0.5, y: 0))
                lines.addLine(to: CGPoint(x: x + 0.5, y: bounds.height))
            }
            x += step
            index += 1
        }
        index = 0
        var y: CGFloat = 0
        while y <= bounds.height {
            if (index % 4 == 0) == major {
                lines.move(to: CGPoint(x: 0, y: y + 0.5))
                lines.addLine(to: CGPoint(x: bounds.width, y: y + 0.5))
            }
            y += step
            index += 1
        }
        let mask = CAShapeLayer()
        mask.frame = bounds
        mask.path = lines.cgPath
        mask.strokeColor = UIColor.black.cgColor
        mask.lineWidth = 1
        mask.fillColor = nil

        let fade = CAGradientLayer()
        fade.type = .radial
        let radius = bounds.width * 1.1
        fade.frame = CGRect(x: bounds.width * 0.85 - radius, y: -radius, width: radius * 2, height: radius * 2)
        fade.colors = [color.cgColor, color.withAlphaComponent(0).cgColor]
        fade.startPoint = CGPoint(x: 0.5, y: 0.5)
        fade.endPoint = CGPoint(x: 1, y: 1)

        let holder = CALayer()
        holder.frame = bounds
        holder.addSublayer(fade)
        holder.mask = mask
        return holder
    }
}

extension AuroraView: SoramitsuObserver {
    public func styleDidChange(options: UpdateOptions) {
        if options.contains(.palette) { rebuild() }
    }
}
