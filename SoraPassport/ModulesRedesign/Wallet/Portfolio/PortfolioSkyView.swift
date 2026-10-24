// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import SoraUIKit
import UIKit

/// The hero sky: the Polkaswap flower with the allocation fan above it. The brand is the chart:
/// 100 rays on a 180° arc, one per percent of the counted value, coloured by the entity's slot.
/// Decorative for accessibility; the legend chips are the real buttons.
final class PortfolioSkyView: UIView {
    struct Model: Equatable {
        var segments: [PortfolioFanSegment]
        var highlightedKey: String?
        var showsFan: Bool
    }

    /// Parallax layers, deepest first. Only their transforms move.
    let starsView = PortfolioLayerView()
    let glowView = PortfolioLayerView()
    let fanView = PortfolioLayerView()
    let sheenView = PortfolioLayerView()
    let flowerView = PortfolioLayerView()

    /// Called with a segment key when a ray is tapped.
    var onSegmentTap: ((String) -> Void)?

    /// Height of the safe area above the sky's content (the sky runs under the status bar).
    var topInset: CGFloat = 0 {
        didSet { if topInset != oldValue { setNeedsLayout() } }
    }

    private let gradient = CAGradientLayer()
    private let starLayers: [CAShapeLayer] = (0..<3).map { _ in CAShapeLayer() }
    private let glow = CAGradientLayer()
    private var segmentLayers: [CAShapeLayer] = []
    private let fanMask = CAGradientLayer()
    private let sheenRays = CAShapeLayer()
    private let sheenMask = CAGradientLayer()
    private let flower = CAShapeLayer()
    private var model = Model(segments: [], highlightedKey: nil, showsFan: false)
    private var laidOutSize: CGSize = .zero
    private var laidOutInset: CGFloat = -1
    private var sheenAngle: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        clipsToBounds = true
        layer.addSublayer(gradient)
        gradient.locations = PortfolioTheme.skyLocations
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)

        [starsView, glowView, fanView, sheenView, flowerView].forEach {
            $0.isUserInteractionEnabled = false
            addSubview($0)
        }
        starLayers.forEach { starsView.layer.addSublayer($0) }

        glow.type = .radial
        glow.startPoint = CGPoint(x: 0.5, y: 0.5)
        glow.endPoint = CGPoint(x: 1, y: 1)
        glowView.layer.addSublayer(glow)

        fanMask.type = .radial
        fanMask.startPoint = CGPoint(x: 0.5, y: 0.5)
        fanMask.endPoint = CGPoint(x: 1, y: 1)
        fanView.layer.mask = fanMask

        sheenRays.fillColor = nil
        sheenRays.lineCap = .round
        sheenRays.lineWidth = PortfolioTheme.Sky.rayWidth
        sheenView.layer.addSublayer(sheenRays)
        sheenMask.type = .conic
        sheenView.layer.mask = sheenMask

        flower.fillColor = PortfolioTheme.flowerPink.cgColor
        flowerView.layer.addSublayer(flower)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)
        applyTheme()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Geometry

    var flowerCenter: CGPoint {
        CGPoint(x: bounds.midX, y: topInset + PortfolioTheme.Sky.flowerCenterY)
    }

    /// Angle of ray `index` in radians, 0 pointing up, negative to the left (180° arc, left to right).
    static func rayAngle(_ index: Int) -> CGFloat {
        let step = CGFloat.pi / CGFloat(PortfolioAllocation.rayCount)
        return -CGFloat.pi / 2 + (CGFloat(index) + 0.5) * step
    }

    // MARK: Updates

    func apply(_ newModel: Model, animated: Bool) {
        let segmentsChanged = newModel.segments != model.segments || newModel.showsFan != model.showsFan
        model = newModel
        if segmentsChanged {
            rebuildFan()
        } else {
            applyHighlight(animated: animated)
        }
    }

    func applyTheme() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.colors = PortfolioTheme.skyColors()
        let glowColor = PortfolioTheme.glowColor
        glow.colors = [glowColor.cgColor, glowColor.withAlphaComponent(0).cgColor]
        starsView.isHidden = !PortfolioTheme.isDark
        starLayers.enumerated().forEach { index, layer in
            layer.fillColor = PortfolioTheme.starColor.withAlphaComponent([0.24, 0.38, 0.56][index]).cgColor
        }
        sheenRays.strokeColor = UIColor.white.withAlphaComponent(PortfolioTheme.isDark ? 0.42 : 0.55).cgColor
        flower.shadowColor = PortfolioTheme.flowerPink.cgColor
        flower.shadowOpacity = PortfolioTheme.isDark ? 0.55 : 0.28
        flower.shadowRadius = 14
        flower.shadowOffset = .zero
        CATransaction.commit()
    }

    /// Slides the window of light across the fan with the horizontal deflection.
    func setSheen(deflection x: CGFloat) {
        sheenAngle = (-100 + (x + 1) * 100) * .pi / 180
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        sheenMask.setAffineTransform(CGAffineTransform(rotationAngle: sheenAngle))
        CATransaction.commit()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != laidOutSize || topInset != laidOutInset else { return }
        laidOutSize = bounds.size
        laidOutInset = topInset
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = bounds
        [starsView, glowView, fanView, sheenView].forEach { view in
            view.bounds = CGRect(origin: .zero, size: bounds.size)
            view.center = CGPoint(x: bounds.midX, y: bounds.midY)
        }
        layoutStars()
        let center = flowerCenter
        let glowRadius: CGFloat = 132
        glow.frame = CGRect(x: center.x - glowRadius, y: center.y - glowRadius * 0.9,
                            width: glowRadius * 2, height: glowRadius * 2)

        let outer = PortfolioTheme.Sky.outerRadius + PortfolioTheme.Sky.highlightLift + 4
        fanMask.frame = CGRect(x: center.x - outer, y: center.y - outer, width: outer * 2, height: outer * 2)
        let inner = PortfolioTheme.Sky.innerRadius
        let fade = (PortfolioTheme.Sky.outerRadius - inner) * PortfolioTheme.Sky.fadeFraction
        fanMask.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor, UIColor.black.cgColor, UIColor.black.cgColor]
        fanMask.locations = [0, NSNumber(value: Double(inner / outer)),
                             NSNumber(value: Double((inner + fade) / outer)), 1]

        let sheenSide = outer * 2
        sheenMask.bounds = CGRect(x: 0, y: 0, width: sheenSide, height: sheenSide)
        sheenMask.position = center
        sheenMask.startPoint = CGPoint(x: 0.5, y: 0.5)
        sheenMask.endPoint = CGPoint(x: 0.5, y: 0)
        let window: Double = 26.0 / 360.0
        sheenMask.colors = [UIColor.clear.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor, UIColor.clear.cgColor]
        sheenMask.locations = [0, NSNumber(value: window * 12 / 26), NSNumber(value: window), 1]
        sheenMask.setAffineTransform(CGAffineTransform(rotationAngle: sheenAngle))

        let size = PortfolioTheme.Sky.flowerSize
        flowerView.bounds = CGRect(x: 0, y: 0, width: size, height: size)
        flowerView.center = center
        flower.frame = flowerView.bounds
        flower.path = PortfolioGlyphs.flowerPath(in: flowerView.bounds).cgPath
        flower.shadowPath = flower.path
        CATransaction.commit()
        rebuildFan()
    }

    private func layoutStars() {
        // Deterministic speckle, the same on every device and every launch.
        var seed: UInt32 = 11
        func next() -> CGFloat {
            seed = (seed &* 9301 &+ 49297) % 233_280
            return CGFloat(seed) / 233_280
        }
        let paths = starLayers.map { _ in UIBezierPath() }
        for index in 0..<30 {
            let x = next() * bounds.width
            let y = topInset * 0.4 + next() * (bounds.height - topInset * 0.4) * 0.78
            let radius: CGFloat = index % 6 == 0 ? 1.3 : 0.8
            let bucket = Int(next() * 3) % 3
            paths[bucket].append(UIBezierPath(ovalIn: CGRect(x: x - radius, y: y - radius,
                                                            width: radius * 2, height: radius * 2)))
        }
        zip(starLayers, paths).forEach { layer, path in
            layer.frame = bounds
            layer.path = path.cgPath
        }
    }

    private func rayPath(from start: Int, count: Int, lift: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        let center = flowerCenter
        let inner = PortfolioTheme.Sky.innerRadius + lift
        let outer = PortfolioTheme.Sky.outerRadius + lift
        for index in start..<(start + count) {
            let angle = Self.rayAngle(index)
            let direction = CGPoint(x: sin(angle), y: -cos(angle))
            path.move(to: CGPoint(x: center.x + direction.x * inner, y: center.y + direction.y * inner))
            path.addLine(to: CGPoint(x: center.x + direction.x * outer, y: center.y + direction.y * outer))
        }
        return path
    }

    private func rebuildFan() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        segmentLayers.forEach { $0.removeFromSuperlayer() }
        segmentLayers = []
        fanView.isHidden = !model.showsFan
        sheenView.isHidden = !model.showsFan || !FxPolicy.current.glows
        let all = UIBezierPath()
        var start = 0
        if model.showsFan, bounds.width > 0 {
            for segment in model.segments where segment.rays > 0 {
                let layer = CAShapeLayer()
                layer.fillColor = nil
                layer.lineCap = .round
                layer.lineWidth = PortfolioTheme.Sky.rayWidth
                layer.strokeColor = PortfolioTheme.color(for: segment.slot).cgColor
                layer.frame = fanView.bounds
                layer.path = rayPath(from: start, count: segment.rays, lift: 0).cgPath
                layer.name = segment.key
                fanView.layer.addSublayer(layer)
                segmentLayers.append(layer)
                all.append(rayPath(from: start, count: segment.rays, lift: 0))
                start += segment.rays
            }
        }
        sheenRays.frame = sheenView.bounds
        sheenRays.path = all.cgPath
        CATransaction.commit()
        applyHighlight(animated: false)
    }

    private func applyHighlight(animated: Bool) {
        var start = 0
        let duration = animated && !UIAccessibility.isReduceMotionEnabled ? NeonMotion.base : 0
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        CATransaction.setAnimationTimingFunction(NeonMotion.standard)
        if duration == 0 { CATransaction.setDisableActions(true) }
        for segment in model.segments where segment.rays > 0 {
            guard let layer = segmentLayers.first(where: { $0.name == segment.key }) else {
                start += segment.rays
                continue
            }
            let isSelected = model.highlightedKey == segment.key
            let dimmed = model.highlightedKey != nil && !isSelected
            let path = rayPath(from: start, count: segment.rays,
                               lift: isSelected ? PortfolioTheme.Sky.highlightLift : 0).cgPath
            if duration > 0 {
                let animation = CABasicAnimation(keyPath: "path")
                animation.fromValue = layer.presentation()?.path ?? layer.path
                animation.toValue = path
                animation.duration = duration
                animation.timingFunction = NeonMotion.standard
                layer.add(animation, forKey: "lift")
            }
            layer.path = path
            layer.opacity = dimmed ? PortfolioTheme.Sky.dimmedAlpha : 1
            layer.lineWidth = isSelected ? PortfolioTheme.Sky.rayWidth + 0.5 : PortfolioTheme.Sky.rayWidth
            start += segment.rays
        }
        CATransaction.commit()
    }

    // MARK: Touch

    /// The segment under a point, if the point is on the fan.
    func segmentKey(at point: CGPoint) -> String? {
        guard model.showsFan else { return nil }
        let center = flowerCenter
        let dx = point.x - center.x
        let dy = point.y - center.y
        let radius = (dx * dx + dy * dy).squareRoot()
        guard radius >= PortfolioTheme.Sky.innerRadius - 10,
              radius <= PortfolioTheme.Sky.outerRadius + 18,
              dy <= 6 else { return nil }
        let angle = atan2(dx, -dy) // 0 up, negative left
        let index = Int(((angle + .pi / 2) / .pi * CGFloat(PortfolioAllocation.rayCount)).rounded(.down))
        guard index >= 0, index < PortfolioAllocation.rayCount else { return nil }
        var start = 0
        for segment in model.segments {
            if index >= start && index < start + segment.rays { return segment.key }
            start += segment.rays
        }
        return nil
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let key = segmentKey(at: recognizer.location(in: self)) else { return }
        onSegmentTap?(key)
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // Only the fan takes touches; everything else falls through to the controls above.
        segmentKey(at: point) != nil
    }
}

/// A plain container whose transform the parallax controller drives.
final class PortfolioLayerView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
