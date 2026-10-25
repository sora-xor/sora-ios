//
//  Tabbar.swift
//  SoraUIKit
//
//  Created by Ivan Shlyapkin on 27.09.2022.
//

import UIKit

public class TabBar: UITabBar {
    
    public lazy var middleButtonTitleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.textColor = .fgSecondary
        label.sora.font = FontType.textBoldXS
        label.sora.alignment = .center
        return label
    }()
    
    public lazy var coverButton: SoramitsuControl = {
        let button = SoramitsuControl()
        button.sora.backgroundColor = .custom(uiColor: .clear)
        return button
    }()

    /// The centre swap disc (spec §7.11): `cta.swap` gradient, glyph in ink
    /// (white in light), static `glow.swap`. The only persistent glow on the
    /// main screens. Never pulses.
    public lazy var middleButton: ImageButton = {
        let middleButton = ImageButton(size: CGSize(width: 56, height: 56))
        middleButton.sora.cornerRadius = .circle
        middleButton.sora.backgroundColor = .custom(uiColor: .clear)
        return middleButton
    }()

    /// The disc fill sits behind the button (the button's own image view
    /// must stay on top of it). The disc is a fixed 56 pt circle.
    private let swapFill: NeonGradientView = {
        let fill = NeonGradientView()
        fill.layer.masksToBounds = true
        fill.layer.cornerRadius = 28
        fill.translatesAutoresizingMaskIntoConstraints = false
        return fill
    }()

    private let middleGlow: GlowHostView = {
        let glow = GlowHostView()
        glow.shape = .capsule
        glow.translatesAutoresizingMaskIntoConstraints = false
        return glow
    }()

    /// Top hairline of the notched bar (iOS 16–25 only).
    private let topLine: CAShapeLayer = {
        let line = CAShapeLayer()
        line.fillColor = nil
        line.lineWidth = 1
        return line
    }()

    /// True on iOS 16–25: the bar draws its own notched chrome and the
    /// active-item indicator. On iOS 26+ the system Liquid Glass bar and its
    /// selection are used and nothing is painted over them (spec §4.3.4).
    public let drawsLegacyChrome: Bool

    /// Active indicator, iOS 16–25 only (spec §7.11): a 16 × 3 `brand.red`
    /// pill above the selected icon with a static `glow.tab`. It is drawn
    /// above the bar's own background and item views, whatever order UIKit
    /// adds them in.
    let selectionIndicator: CALayer = {
        let indicator = CALayer()
        indicator.cornerRadius = 1.5
        indicator.cornerCurve = .continuous
        indicator.zPosition = 1
        indicator.isHidden = true
        return indicator
    }()

    public convenience override init(frame: CGRect) {
        self.init(frame: frame, drawsLegacyChrome: !NeonChrome.usesLiquidGlass)
    }

    /// - Parameter drawsLegacyChrome: defaults to the running system; tests
    ///   pass `true` to check the iOS 16–25 chrome on a newer simulator.
    public init(frame: CGRect, drawsLegacyChrome: Bool) {
        self.drawsLegacyChrome = drawsLegacyChrome
        super.init(frame: frame)

        if drawsLegacyChrome {
            layer.addSublayer(selectionIndicator)
        }
        installSwapDisc(in: self)

        SoramitsuUI.updates.addObserver(self)
        applyNeonStyle()
    }

    /// Puts the swap disc (glow, gradient fill, button, tap cover and label,
    /// in that order) into `host` and lays it out there. `init` uses the bar
    /// itself; `MainTabBarViewController` uses the system tab bar if it
    /// cannot swap this bar in, so the disc keeps its fill and glow there.
    public func installSwapDisc(in host: UIView) {
        let views: [UIView] = [coverButton, middleGlow, swapFill, middleButton, middleButtonTitleLabel]
        views.forEach {
            $0.removeFromSuperview()
            host.addSubview($0)
        }
        let titleWidth = UIScreen.main.bounds.width / 5

        NSLayoutConstraint.activate([
            middleGlow.leadingAnchor.constraint(equalTo: middleButton.leadingAnchor),
            middleGlow.trailingAnchor.constraint(equalTo: middleButton.trailingAnchor),
            middleGlow.topAnchor.constraint(equalTo: middleButton.topAnchor),
            middleGlow.bottomAnchor.constraint(equalTo: middleButton.bottomAnchor),
            swapFill.leadingAnchor.constraint(equalTo: middleButton.leadingAnchor),
            swapFill.trailingAnchor.constraint(equalTo: middleButton.trailingAnchor),
            swapFill.topAnchor.constraint(equalTo: middleButton.topAnchor),
            swapFill.bottomAnchor.constraint(equalTo: middleButton.bottomAnchor),

            middleButton.centerXAnchor.constraint(equalTo: host.centerXAnchor),
            middleButton.bottomAnchor.constraint(equalTo: host.safeAreaLayoutGuide.bottomAnchor, constant: -21),

            coverButton.centerXAnchor.constraint(equalTo: host.centerXAnchor),
            coverButton.bottomAnchor.constraint(equalTo: host.safeAreaLayoutGuide.bottomAnchor),
            coverButton.heightAnchor.constraint(equalToConstant: 77),
            coverButton.widthAnchor.constraint(equalTo: middleButton.widthAnchor),

            middleButtonTitleLabel.centerXAnchor.constraint(equalTo: host.centerXAnchor),
            middleButtonTitleLabel.widthAnchor.constraint(equalToConstant: titleWidth),
            middleButtonTitleLabel.bottomAnchor.constraint(equalTo: host.safeAreaLayoutGuide.bottomAnchor,
                                                           constant: -1),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var shapeLayer: CAShapeLayer?

    /// The notched chrome under the items. Not drawn on iOS 26+: it would
    /// paint over the system Liquid Glass bar (spec §4.3.4).
    private func addShape() {
        guard drawsLegacyChrome else {
            shapeLayer?.removeFromSuperlayer()
            shapeLayer = nil
            topLine.removeFromSuperlayer()
            return
        }
        let tokens = NeonTokens.current
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = createPath()
        shapeLayer.strokeColor = UIColor.clear.cgColor
        shapeLayer.fillColor = (tokens.isDark ? tokens.layer1 : tokens.surface).cgColor
        shapeLayer.lineWidth = 0

        if let oldShapeLayer = self.shapeLayer {
            self.layer.replaceSublayer(oldShapeLayer, with: shapeLayer)
        } else {
            self.layer.insertSublayer(shapeLayer, at: 0)
        }
        self.shapeLayer = shapeLayer

        topLine.path = createTopEdgePath()
        topLine.strokeColor = tokens.hairline.cgColor
        if topLine.superlayer == nil {
            layer.insertSublayer(topLine, above: shapeLayer)
        }
    }

    public override func draw(_ rect: CGRect) {
        self.addShape()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        updateSelectionIndicator(animated: false)
    }

    public override var selectedItem: UITabBarItem? {
        didSet {
            guard selectedItem !== oldValue else { return }
            updateSelectionIndicator(animated: oldValue != nil)
        }
    }

    /// Moves the indicator over the selected item (240 ms, none under
    /// Reduce Motion). Hidden on iOS 26+, for the centre swap item and while
    /// the item views cannot be matched to the items.
    public func updateSelectionIndicator(animated: Bool) {
        guard drawsLegacyChrome else { return }
        let frame = selectionIndicatorFrame()
        CATransaction.begin()
        if animated, frame != nil, !selectionIndicator.isHidden, !FxPolicy.current.reduceMotion {
            CATransaction.setAnimationDuration(0.24)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        } else {
            CATransaction.setDisableActions(true)
        }
        if let frame {
            selectionIndicator.frame = frame
            if selectionIndicator.shadowOpacity > 0 {
                selectionIndicator.shadowPath = UIBezierPath(roundedRect: CGRect(origin: .zero, size: frame.size),
                                                             cornerRadius: frame.height / 2).cgPath
            }
        }
        selectionIndicator.isHidden = frame == nil
        CATransaction.commit()
    }

    /// 16 × 3, centred over the selected item, 6 pt above its icon.
    func selectionIndicatorFrame() -> CGRect? {
        guard let items, let selectedItem, let index = items.firstIndex(where: { $0 === selectedItem }) else {
            return nil
        }
        let itemViews = subviews
            .filter { $0 is UIControl && $0 !== coverButton && $0 !== middleButton }
            .sorted { $0.frame.minX < $1.frame.minX }
        // The centre item is the swap disc, which is not a selectable tab.
        guard itemViews.count == items.count, !(items.count == 5 && index == 2) else { return nil }
        let itemView = itemViews[index]
        let size = CGSize(width: 16, height: 3)
        let top: CGFloat
        if let icon = Self.firstImageView(in: itemView) {
            top = max(1, icon.convert(icon.bounds, to: self).minY - 6 - size.height)
        } else {
            top = itemView.frame.minY + 2
        }
        return CGRect(x: itemView.frame.midX - size.width / 2, y: top, width: size.width, height: size.height)
    }

    private static func firstImageView(in view: UIView) -> UIImageView? {
        for subview in view.subviews {
            if let image = subview as? UIImageView, !image.isHidden, image.bounds.width > 0 {
                return image
            }
            if let nested = firstImageView(in: subview) {
                return nested
            }
        }
        return nil
    }

    private func applyNeonStyle() {
        let tokens = NeonTokens.current
        let fx = FxPolicy.current
        swapFill.apply(tokens.ctaSwap)
        middleButton.sora.tintColor = .custom(uiColor: tokens.onAccent)
        middleGlow.configure(tokens.glowSwap)
        middleButtonTitleLabel.sora.textColor = .fgSecondary
        if let shapeLayer {
            shapeLayer.fillColor = (tokens.isDark ? tokens.layer1 : tokens.surface).cgColor
            topLine.strokeColor = tokens.hairline.cgColor
        }
        if drawsLegacyChrome {
            selectionIndicator.backgroundColor = tokens.brandRed.cgColor
            // Static glow; the pill alone in the MINIMAL tier and under
            // Increase Contrast. The path is the pill itself.
            let pill = CGRect(origin: .zero, size: selectionIndicator.bounds.size)
            selectionIndicator.applyNeonGlow(fx.glows && fx.tier != .minimal ? tokens.glowTab : nil,
                                             path: UIBezierPath(roundedRect: pill,
                                                                cornerRadius: pill.height / 2).cgPath)
        }
        setNeedsDisplay()
    }

    private func createTopEdgePath() -> CGPath {
        let height: CGFloat = 32.0
        let path = UIBezierPath()
        let centerWidth = self.frame.width / 2
        path.move(to: CGPoint(x: 0, y: 0.5))
        path.addLine(to: CGPoint(x: (centerWidth - height), y: 0.5))
        path.addCurve(to: CGPoint(x: centerWidth, y: height + 0.5),
                      controlPoint1: CGPoint(x: (centerWidth - height), y: 0.5),
                      controlPoint2: CGPoint(x: centerWidth - height, y: height + 0.5))
        path.addCurve(to: CGPoint(x: (centerWidth + height), y: 0.5),
                      controlPoint1: CGPoint(x: centerWidth + height, y: height + 0.5),
                      controlPoint2: CGPoint(x: (centerWidth + height), y: 0.5))
        path.addLine(to: CGPoint(x: self.frame.width, y: 0.5))
        return path.cgPath
    }

    func createPath() -> CGPath {

        let height: CGFloat = 32.0
        let path = UIBezierPath()
        let centerWidth = self.frame.width / 2

        path.move(to: CGPoint(x: 0, y: 0)) // start top left
        path.addLine(to: CGPoint(x: (centerWidth - height), y: 0)) // the beginning of the trough
        // first curve down
        path.addCurve(to: CGPoint(x: centerWidth, y: height),
                      controlPoint1: CGPoint(x: (centerWidth - height), y: 0), controlPoint2: CGPoint(x: centerWidth - height, y: height))
        // second curve up
        path.addCurve(to: CGPoint(x: (centerWidth + height), y: 0),
                      controlPoint1: CGPoint(x: centerWidth + height, y: height), controlPoint2: CGPoint(x: (centerWidth + height), y: 0))

        // complete the rect
        path.addLine(to: CGPoint(x: self.frame.width, y: 0))
        path.addLine(to: CGPoint(x: self.frame.width, y: self.frame.height))
        path.addLine(to: CGPoint(x: 0, y: self.frame.height))
        path.close()

        return path.cgPath
    }

    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !clipsToBounds && !isHidden && alpha > 0 else { return nil }
        for member in subviews.reversed() {
            let subPoint = member.convert(point, from: self)
            guard let result = member.hitTest(subPoint, with: event) else { continue }
            return result
        }
        return nil
    }
}

extension TabBar: SoramitsuObserver {
    public func styleDidChange(options: UpdateOptions) {
        guard options.contains(.palette) || options.contains(.effects) else { return }
        applyNeonStyle()
    }
}

extension CGFloat {
    var degreesToRadians: CGFloat { return self * .pi / 180 }
    var radiansToDegrees: CGFloat { return self * 180 / .pi }
}
