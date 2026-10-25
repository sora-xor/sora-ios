// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import SoraUIKit
import UIKit

/// The orbit header of Where it lives: the token as the centre orb, a ring in perspective, one
/// satellite per network that holds it, and the Polkaswap node. The holdings list below carries the
/// same data for accessibility, so the orbit is decorative except for its satellite buttons.
final class PortfolioOrbitView: UIView {
    var onSatellite: ((String) -> Void)?

    let ringView = PortfolioLayerView()
    let orbView = PortfolioLayerView()
    let satellitesView = PortfolioLayerView()
    let nodeView = PortfolioLayerView()

    private let ring = CAShapeLayer()
    private let ringFill = CAGradientLayer()
    private let halo = CAGradientLayer()
    private let orbIcon = PortfolioTokenIconView(size: 66)
    private let links = CAShapeLayer()
    private let orbLinks = CAShapeLayer()
    private let readyLinks = CAShapeLayer()
    private let nodeHalo = CAGradientLayer()
    private let node = UIImageView()
    private let nodeLabel = UILabel.portfolio(FontType.eyebrow, .caption2, maximum: 16)
    private var satelliteButtons: [UIButton] = []
    private var satelliteLabels: [UILabel] = []
    private var model: PortfolioDetailModel?
    private var laidOut: CGSize = .zero
    // The orb keeps its own size constraints, so it is placed by constraints too.
    private var orbCenterX: NSLayoutConstraint?
    private var orbCenterY: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false
        [ringView, orbView, satellitesView, nodeView].forEach {
            $0.isUserInteractionEnabled = false
            addSubview($0)
        }
        satellitesView.isUserInteractionEnabled = true
        ringFill.type = .radial
        ringView.layer.addSublayer(ringFill)
        ring.fillColor = nil
        ring.lineWidth = 1
        ringView.layer.addSublayer(ring)
        halo.type = .radial
        orbView.layer.addSublayer(halo)
        orbView.addSubview(orbIcon)
        let orbCenterX = orbIcon.centerXAnchor.constraint(equalTo: orbView.leadingAnchor)
        let orbCenterY = orbIcon.centerYAnchor.constraint(equalTo: orbView.topAnchor)
        self.orbCenterX = orbCenterX
        self.orbCenterY = orbCenterY
        NSLayoutConstraint.activate([orbCenterX, orbCenterY])
        [orbLinks, links, readyLinks].forEach {
            $0.fillColor = nil
            $0.lineCap = .round
            satellitesView.layer.addSublayer($0)
        }
        links.lineDashPattern = [1.5, 4]
        links.lineWidth = 1.5
        orbLinks.lineWidth = 1
        readyLinks.lineWidth = 2
        nodeHalo.type = .radial
        nodeView.layer.addSublayer(nodeHalo)
        node.contentMode = .center
        node.layer.cornerRadius = 26
        node.clipsToBounds = true
        nodeView.addSubview(node)
        nodeView.addSubview(nodeLabel)
        // Placed by frame, like the rest of the orbit.
        nodeLabel.translatesAutoresizingMaskIntoConstraints = true
        nodeLabel.textAlignment = .center
        nodeLabel.text = "POLKASWAP"
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(_ model: PortfolioDetailModel) {
        self.model = model
        orbIcon.configure(model.icon)
        laidOut = .zero
        setNeedsLayout()
    }

    private var center0: CGPoint { CGPoint(x: bounds.midX, y: bounds.height * 0.54) }
    /// Narrow enough that the side satellites' amount labels stay on screen.
    private var ringSize: CGSize { CGSize(width: min(bounds.width - 96, 300), height: 96) }

    /// Satellite positions on the ring: left, right, front, then back.
    private func satellitePoint(_ index: Int, count: Int) -> CGPoint {
        let angles: [CGFloat]
        switch count {
        case 1: angles = [200]
        case 2: angles = [195, 345]
        default: angles = [190, 350, 100, 270]
        }
        let angle = angles[min(index, angles.count - 1)] * .pi / 180
        let radiusX = ringSize.width / 2
        let radiusY = ringSize.height / 2
        return CGPoint(x: center0.x + cos(angle) * radiusX, y: center0.y + sin(angle) * radiusY)
    }

    private var nodePoint: CGPoint { CGPoint(x: bounds.width - 62, y: 46) }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != laidOut, let model else { return }
        laidOut = bounds.size
        let tokens = PortfolioTheme.tokens
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        [ringView, orbView, satellitesView, nodeView].forEach {
            $0.bounds = CGRect(origin: .zero, size: bounds.size)
            $0.center = CGPoint(x: bounds.midX, y: bounds.midY)
        }
        let center = center0
        let ringRect = CGRect(x: center.x - ringSize.width / 2, y: center.y - ringSize.height / 2,
                              width: ringSize.width, height: ringSize.height)
        ring.path = UIBezierPath(ovalIn: ringRect).cgPath
        ring.strokeColor = (PortfolioTheme.isDark ? UIColor.white.withAlphaComponent(0.16) : tokens.hairline).cgColor
        ringFill.frame = ringRect
        let tint = PortfolioTheme.isDark ? UIColor(portfolioHex: 0x8B5CFF, alpha: 0.22) : UIColor(portfolioHex: 0x8B5CFF, alpha: 0.10)
        ringFill.colors = [tint.cgColor, tint.withAlphaComponent(0).cgColor]
        ringFill.startPoint = CGPoint(x: 0.5, y: 0.5)
        ringFill.endPoint = CGPoint(x: 1, y: 1)

        let haloRadius: CGFloat = 70
        halo.frame = CGRect(x: center.x - haloRadius, y: center.y - haloRadius, width: haloRadius * 2, height: haloRadius * 2)
        let haloColor = PortfolioTheme.flowerPink.withAlphaComponent(PortfolioTheme.isDark ? 0.30 : 0.14)
        halo.colors = [haloColor.cgColor, haloColor.withAlphaComponent(0).cgColor]
        halo.startPoint = CGPoint(x: 0.5, y: 0.5)
        halo.endPoint = CGPoint(x: 1, y: 1)
        orbCenterX?.constant = center.x
        orbCenterY?.constant = center.y
        orbIcon.layer.borderWidth = 2
        orbIcon.layer.borderColor = UIColor.white.withAlphaComponent(PortfolioTheme.isDark ? 0.18 : 0.9).cgColor

        let nodeCenter = nodePoint
        node.frame = CGRect(x: nodeCenter.x - 26, y: nodeCenter.y - 26, width: 52, height: 52)
        node.image = PortfolioGlyphs.flowerImage(size: 26, color: .white)
        node.backgroundColor = PortfolioTheme.flowerPink
        node.layer.borderWidth = 2
        node.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        let nodeHaloRadius: CGFloat = 46
        nodeHalo.frame = CGRect(x: nodeCenter.x - nodeHaloRadius, y: nodeCenter.y - nodeHaloRadius,
                                width: nodeHaloRadius * 2, height: nodeHaloRadius * 2)
        let pink = PortfolioTheme.flowerPink.withAlphaComponent(PortfolioTheme.isDark ? 0.35 : 0.18)
        nodeHalo.colors = [pink.cgColor, pink.withAlphaComponent(0).cgColor]
        nodeHalo.startPoint = CGPoint(x: 0.5, y: 0.5)
        nodeHalo.endPoint = CGPoint(x: 1, y: 1)
        nodeLabel.setEyebrow("POLKASWAP", color: tokens.textSecondary)
        nodeLabel.sizeToFit()
        nodeLabel.center = CGPoint(x: nodeCenter.x, y: nodeCenter.y + 26 + 12)

        satelliteButtons.forEach { $0.removeFromSuperview() }
        satelliteLabels.forEach { $0.removeFromSuperview() }
        satelliteButtons = []
        satelliteLabels = []
        let dotted = UIBezierPath()
        let solid = UIBezierPath()
        let toOrb = UIBezierPath()
        for (index, satellite) in model.satellites.enumerated() {
            let point = satellitePoint(index, count: model.satellites.count)
            let size = 32 + 14 * CGFloat(max(0, min(1, satellite.weight)))
            let button = UIButton(type: .custom)
            button.frame = CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size)
            button.setImage(PortfolioBadges.network(satellite.network, size: size), for: .normal)
            button.layer.cornerRadius = size / 2
            button.layer.borderWidth = 2
            button.layer.borderColor = (satellite.isSwapReady ? PortfolioTheme.flowerPink
                : UIColor.white.withAlphaComponent(PortfolioTheme.isDark ? 0.2 : 0.9)).cgColor
            button.tag = index
            button.addTarget(self, action: #selector(satelliteTapped(_:)), for: .touchUpInside)
            button.isAccessibilityElement = false
            satellitesView.addSubview(button)
            satelliteButtons.append(button)

            let label = UILabel()
            label.font = PortfolioTheme.font(FontType.amountS, .caption1, maximum: 18)
            label.text = satellite.amount
            label.textColor = tokens.textPrimary
            label.backgroundColor = PortfolioTheme.isDark ? UIColor.black.withAlphaComponent(0.35)
                : UIColor.white.withAlphaComponent(0.85)
            label.textAlignment = .center
            label.layer.cornerRadius = 9
            label.clipsToBounds = true
            label.sizeToFit()
            let labelWidth = label.bounds.width + 14
            let labelX = min(max(8, point.x - labelWidth / 2), bounds.width - 8 - labelWidth)
            label.frame = CGRect(x: labelX, y: point.y + size / 2 + 5, width: labelWidth, height: 18)
            satellitesView.addSubview(label)
            satelliteLabels.append(label)

            toOrb.move(to: point)
            toOrb.addLine(to: center)
            let path = satellite.isSwapReady ? solid : dotted
            path.move(to: CGPoint(x: point.x, y: point.y - size / 2))
            path.addQuadCurve(to: CGPoint(x: nodeCenter.x - 18, y: nodeCenter.y + 10),
                              controlPoint: CGPoint(x: (point.x + nodeCenter.x) / 2, y: min(point.y, nodeCenter.y) - 40))
        }
        orbLinks.path = toOrb.cgPath
        orbLinks.strokeColor = (PortfolioTheme.isDark ? UIColor.white.withAlphaComponent(0.18) : tokens.hairline).cgColor
        links.path = dotted.cgPath
        links.strokeColor = tokens.textTertiary.withAlphaComponent(0.7).cgColor
        readyLinks.path = solid.cgPath
        readyLinks.strokeColor = PortfolioTheme.flowerPink.cgColor
        readyLinks.shadowColor = PortfolioTheme.flowerPink.cgColor
        readyLinks.shadowOpacity = PortfolioTheme.isDark ? 0.6 : 0.25
        readyLinks.shadowRadius = 4
        readyLinks.shadowOffset = .zero
        CATransaction.commit()
    }

    @objc private func satelliteTapped(_ sender: UIButton) {
        guard let model, model.satellites.indices.contains(sender.tag) else { return }
        onSatellite?(model.satellites[sender.tag].holdingId)
    }

    func applyTheme() {
        laidOut = .zero
        setNeedsLayout()
    }
}
