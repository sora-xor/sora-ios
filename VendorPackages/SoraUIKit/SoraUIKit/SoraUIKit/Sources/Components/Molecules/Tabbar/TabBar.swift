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
    /// must stay on top of it).
    private let swapFill: NeonGradientView = {
        let fill = NeonGradientView()
        fill.layer.masksToBounds = true
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

    public override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(coverButton)
        addSubview(middleGlow)
        addSubview(swapFill)
        addSubview(middleButton)
        addSubview(middleButtonTitleLabel)
        
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

            middleButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            middleButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -21),
            
            coverButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            coverButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
            coverButton.heightAnchor.constraint(equalToConstant: 77),
            coverButton.widthAnchor.constraint(equalTo: middleButton.widthAnchor),
            
            middleButtonTitleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            middleButtonTitleLabel.widthAnchor.constraint(equalToConstant: titleWidth),
            middleButtonTitleLabel.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -1),
        ])
        
        SoramitsuUI.updates.addObserver(self)
        applyNeonStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var shapeLayer: CAShapeLayer?

    /// The notched chrome under the items. Not drawn on iOS 26+: it would
    /// paint over the system Liquid Glass bar (spec §4.3.4).
    private func addShape() {
        guard !NeonChrome.usesLiquidGlass else {
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
        swapFill.layer.cornerRadius = swapFill.bounds.height / 2
    }

    private func applyNeonStyle() {
        let tokens = NeonTokens.current
        swapFill.apply(tokens.ctaSwap)
        middleButton.sora.tintColor = .custom(uiColor: tokens.onAccent)
        middleGlow.configure(tokens.glowSwap)
        middleButtonTitleLabel.sora.textColor = .fgSecondary
        if let shapeLayer {
            shapeLayer.fillColor = (tokens.isDark ? tokens.layer1 : tokens.surface).cgColor
            topLine.strokeColor = tokens.hairline.cgColor
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
        guard options.contains(.palette) else { return }
        applyNeonStyle()
    }
}

extension CGFloat {
    var degreesToRadians: CGFloat { return self * .pi / 180 }
    var radiansToDegrees: CGFloat { return self * 180 / .pi }
}
