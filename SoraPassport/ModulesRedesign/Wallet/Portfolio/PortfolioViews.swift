// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

import SoraUIKit
import SVGKit
import UIKit

// MARK: - Icons

/// Token icons decoded once per size from the asset list's data URLs (SVG or PNG).
enum PortfolioIconCache {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(for source: String?, size: CGFloat) -> UIImage? {
        guard let source, !source.isEmpty else { return nil }
        let key = "\(size)|\(source.hashValue)|\(source.count)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard var string = source.removingPercentEncoding else { return nil }
        let isBase64 = string.contains("base64")
        if let comma = string.firstIndex(of: ",") { string.removeSubrange(...comma) }
        guard let data = isBase64 ? Data(base64Encoded: string) : Data(string.utf8) else { return nil }
        let target = CGSize(width: size, height: size)
        let image: UIImage?
        if let bitmap = UIImage(data: data) {
            image = bitmap
        } else if let svg = SVGKImage(data: data) ?? SVGKImage(data: data) {
            // Retried once: SVGKit sets up its length units on the first length it parses, and with
            // assertions on, that parse fails on iPhones its table does not list (simulators included).
            svg.size = target
            image = svg.uiImage
        } else {
            image = nil
        }
        guard let image else { return nil }
        let rendered = UIGraphicsImageRenderer(size: target).image { _ in
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: target)).addClip()
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        cache.setObject(rendered, forKey: key)
        return rendered
    }
}

/// A round token icon with a lettered fallback, struck as a coin: a domed face with a turned rim, its
/// shadow on the plate below it.
final class PortfolioTokenIconView: UIView {
    private let face = UIView()
    private let imageView = UIImageView()
    private let fallback = UILabel()
    private let coin = LitCoinLayers()
    private var size: CGFloat

    init(size: CGFloat) {
        self.size = size
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = false
        // Round for callers that add a border; the coin's own face does the clipping.
        layer.cornerRadius = size / 2
        face.layer.cornerRadius = size / 2
        face.clipsToBounds = true
        imageView.contentMode = .scaleAspectFit
        fallback.textAlignment = .center
        fallback.adjustsFontSizeToFitWidth = true
        fallback.minimumScaleFactor = 0.5
        [imageView, fallback].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            face.addSubview($0)
        }
        face.translatesAutoresizingMaskIntoConstraints = false
        layer.addSublayer(coin.shadow)
        addSubview(face)
        layer.addSublayer(coin.light)
        coin.configure(diameter: size)
        coin.layout(iconFrame: CGRect(x: 0, y: 0, width: size, height: size))
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size),
            heightAnchor.constraint(equalToConstant: size),
            face.leadingAnchor.constraint(equalTo: leadingAnchor),
            face.trailingAnchor.constraint(equalTo: trailingAnchor),
            face.topAnchor.constraint(equalTo: topAnchor),
            face.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: face.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: face.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: face.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: face.bottomAnchor),
            fallback.centerXAnchor.constraint(equalTo: face.centerXAnchor),
            fallback.centerYAnchor.constraint(equalTo: face.centerYAnchor),
            fallback.widthAnchor.constraint(equalTo: face.widthAnchor, multiplier: 0.78)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(_ icon: PortfolioIcon) {
        switch icon {
        case let .token(id, symbol, source):
            let image = PortfolioIconCache.image(for: source, size: size)
            imageView.image = image
            imageView.isHidden = image == nil
            fallback.isHidden = image != nil
            fallback.text = String(symbol.prefix(4))
            fallback.font = FontType.textBoldXS.font.withSize(size * 0.3)
            fallback.textColor = .white
            face.backgroundColor = image == nil ? PortfolioTheme.color(for: .slot(abs(id.hashValue) % 5)) : .clear
        case let .network(network):
            imageView.image = PortfolioBadges.network(network, size: size)
            imageView.isHidden = false
            fallback.isHidden = true
            face.backgroundColor = .clear
        case let .wallet(id, name):
            imageView.image = PortfolioBadges.wallet(id: id, name: name, size: size)
            imageView.isHidden = false
            fallback.isHidden = true
            face.backgroundColor = .clear
        case .allWallets:
            imageView.image = PortfolioBadges.allWallets(size: size)
            imageView.isHidden = false
            fallback.isHidden = true
            face.backgroundColor = .clear
        }
    }
}

/// Network badges, wallet avatars and the All wallets emblem.
enum PortfolioBadges {
    private static let cache = NSCache<NSString, UIImage>()

    private static func cached(_ key: String, _ make: () -> UIImage?) -> UIImage? {
        let key = "\(key)|\(PortfolioTheme.isDark)" as NSString
        if let image = cache.object(forKey: key) { return image }
        guard let image = make() else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    static func network(_ network: PortfolioNetwork, size: CGFloat) -> UIImage? {
        cached("network|\(network.rawValue)|\(size)") {
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            return UIGraphicsImageRenderer(size: rect.size).image { context in
                switch network {
                case .sora2:
                    if let logo = R.image.iconSora() {
                        logo.draw(in: rect)
                    } else {
                        UIColor(portfolioHex: 0xE3232C).setFill()
                        UIBezierPath(ovalIn: rect).fill()
                    }
                case .minamoto, .taira:
                    let info = WalletNetworkDirectory.current.info(network.networkId)
                    let colors: [UIColor] = info.isTestnet
                        ? [UIColor(portfolioHex: 0xFFB547), UIColor(portfolioHex: 0xD9781A)]
                        : [UIColor(portfolioHex: 0x6E5BFF), UIColor(portfolioHex: 0x3A2BB8)]
                    let space = CGColorSpaceCreateDeviceRGB()
                    if let gradient = CGGradient(colorsSpace: space, colors: colors.map(\.cgColor) as CFArray,
                                                 locations: [0, 1]) {
                        context.cgContext.saveGState()
                        UIBezierPath(ovalIn: rect).addClip()
                        context.cgContext.drawLinearGradient(gradient, start: .zero,
                                                             end: CGPoint(x: size, y: size), options: [])
                        context.cgContext.restoreGState()
                    }
                    let text = initials(info.name)
                    let font = FontType.textBoldXS.font.withSize(size * 0.34)
                    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white]
                    let textSize = (text as NSString).size(withAttributes: attributes)
                    (text as NSString).draw(at: CGPoint(x: (size - textSize.width) / 2, y: (size - textSize.height) / 2),
                                            withAttributes: attributes)
                }
            }
        }
    }

    static func wallet(id: String, name: String, size: CGFloat) -> UIImage? {
        cached("wallet|\(id)|\(size)") {
            if let icon = try? PolkadotIconGenerator().generateFromAddress(id),
               let image = icon.imageWithFillColor(UIColor.white, size: CGSize(width: size, height: size),
                                                   contentScale: UIScreen.main.scale) {
                return image
            }
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            return UIGraphicsImageRenderer(size: rect.size).image { _ in
                PortfolioTheme.otherColor.setFill()
                UIBezierPath(ovalIn: rect).fill()
                let initial = String(name.prefix(1)).uppercased()
                let attributes: [NSAttributedString.Key: Any] = [.font: FontType.headline3.font.withSize(size * 0.42),
                                                                 .foregroundColor: UIColor.white]
                let textSize = (initial as NSString).size(withAttributes: attributes)
                (initial as NSString).draw(at: CGPoint(x: (size - textSize.width) / 2, y: (size - textSize.height) / 2),
                                           withAttributes: attributes)
            }
        }
    }

    /// Two letters for a network badge from the app's network name: "SORA Nexus" SN, "Taira" TA.
    static func initials(_ name: String) -> String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return words.prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    /// The SORA mark, the red disc with 天: the All wallets avatar.
    static func allWallets(size: CGFloat) -> UIImage? {
        cached("all|\(size)") { PortfolioGlyphs.soraMarkImage(size: size) }
    }
}

// MARK: - Small controls

/// "Swap-ready" (pink, with the flower) or the app's network tag, in the colours of the network
/// lists (`WalletNetworkTagView`): Main, Testnet, Coming soon.
final class PortfolioTagView: UIView {
    private let label = UILabel()
    private let glyph = UIImageView()
    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerCurve = .continuous
        stack.axis = .horizontal
        stack.spacing = 4
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(glyph)
        stack.addArrangedSubview(label)
        addSubview(stack)
        label.font = PortfolioTheme.font(FontType.textBoldXS, .caption2, maximum: 18)
        label.adjustsFontForContentSizeCategory = true
        // A tag is short and never truncates: the row's names give way instead.
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
            glyph.widthAnchor.constraint(equalToConstant: 11),
            glyph.heightAnchor.constraint(equalToConstant: 11)
        ])
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(_ tag: PortfolioTag) {
        let tokens = PortfolioTheme.tokens
        switch tag {
        case .swapReady:
            label.text = PortfolioStrings.swapReady
            label.textColor = tokens.polkaswapText
            backgroundColor = tokens.polkaswapContainer
            glyph.image = PortfolioGlyphs.flowerImage(size: 11, color: tokens.polkaswapText)
            glyph.isHidden = false
        case let .network(networkTag):
            let color: UIColor
            switch networkTag {
            case .main: color = WalletUX.accent
            case .testnet: color = PortfolioTheme.warning
            case .comingSoon: color = WalletUX.secondary
            }
            label.text = networkTag.title
            label.textColor = color
            backgroundColor = color.withAlphaComponent(0.14)
            glyph.isHidden = true
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }
}

/// A small well with a status light: "● LIVE · 31s".
final class PortfolioFreshnessChip: UIControl {
    private let well = LitWellLayer()
    private let dot = LitDotView(diameter: 7)
    private let label = UILabel()
    private var lightColor = UIColor.clear

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        well.depth = 1.8
        layer.addSublayer(well)
        label.isUserInteractionEnabled = false
        label.font = PortfolioTheme.font(FontType.eyebrow, .caption2, maximum: 18)
        label.adjustsFontForContentSizeCategory = true
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        [dot, label].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        NSLayoutConstraint.activate([
            dot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 11),
            dot.centerYAnchor.constraint(equalTo: centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 7),
            dot.heightAnchor.constraint(equalToConstant: 7),
            label.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 7),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 7),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -7)
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(text: String, tone: PortfolioChipTone) {
        let tokens = PortfolioTheme.tokens
        label.text = text
        let color: UIColor
        switch tone {
        case .live: color = tokens.success
        case .saved: color = tokens.textTertiary
        case .partial: color = tokens.warning
        case .offline: color = tokens.error
        }
        dot.setColor(color)
        lightColor = color
        label.textColor = tokens.textSecondary
        accessibilityLabel = text
        accessibilityTraits = tone == .live ? .staticText : .button
    }

    /// Fresh numbers have just arrived: one ring goes out from the light, like a drop in still water.
    func ping() {
        guard LitMotion.allowed, window != nil else { return }
        let ring = CAShapeLayer()
        let side = dot.bounds.width
        ring.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        ring.position = dot.center
        ring.path = UIBezierPath(ovalIn: ring.bounds).cgPath
        ring.fillColor = nil
        ring.strokeColor = lightColor.cgColor
        ring.lineWidth = 1.2
        ring.opacity = 0
        layer.addSublayer(ring)
        let widen = CABasicAnimation(keyPath: "transform.scale")
        widen.fromValue = 1
        widen.toValue = 1 + 2 * SacredGeometry.phi
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0.75
        fade.toValue = 0
        let wave = CAAnimationGroup()
        wave.animations = [widen, fade]
        wave.duration = SacredGeometry.beat(4)
        wave.timingFunction = CAMediaTimingFunction(name: .easeOut)
        CATransaction.begin()
        CATransaction.setCompletionBlock { ring.removeFromSuperlayer() }
        ring.add(wave, forKey: "sacred.ping")
        CATransaction.commit()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        well.cornerRadiusValue = bounds.height / 2
        well.place(in: bounds)
    }
}

/// Legend chip: light, name, percent. The fan's accessible twin. Raised at rest, pressed in when selected.
final class PortfolioLegendChipView: UIControl {
    private let plate = LitPlateLayer()
    private let well = LitWellLayer()
    private let dot = LitDotView(diameter: 8)
    private let title = UILabel()
    private let percent = UILabel()
    private(set) var key: String = ""
    private var color: UIColor = .clear

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        plate.elevation = 6
        well.depth = 2.2
        well.isHidden = true
        layer.addSublayer(plate)
        layer.addSublayer(well)
        title.font = PortfolioTheme.font(FontType.textBoldS, .subheadline, maximum: 22)
        percent.font = PortfolioTheme.font(FontType.amountS, .subheadline, maximum: 22)
        [title, percent].forEach { $0.adjustsFontForContentSizeCategory = true }
        [dot, title, percent].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.isUserInteractionEnabled = false
            addSubview($0)
        }
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 36),
            dot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 13),
            dot.centerYAnchor.constraint(equalTo: centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),
            title.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 9),
            title.centerYAnchor.constraint(equalTo: centerYAnchor),
            percent.leadingAnchor.constraint(equalTo: title.trailingAnchor, constant: 6),
            percent.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            percent.centerYAnchor.constraint(equalTo: centerYAnchor),
            title.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 8),
            title.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -8)
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(_ chip: PortfolioLegendChip) {
        key = chip.key
        color = PortfolioTheme.color(for: chip.slot)
        title.text = chip.title
        percent.text = chip.percent
        accessibilityLabel = chip.accessibilityLabel
        accessibilityTraits = chip.isSelected ? [.button, .selected] : .button
        accessibilityHint = chip.isSelected && chip.opensToken ? PortfolioStrings.whereItLives : nil
        let tokens = PortfolioTheme.tokens
        dot.setColor(color)
        title.textColor = tokens.textPrimary
        percent.textColor = tokens.textSecondary
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        plate.isHidden = chip.isSelected
        well.isHidden = !chip.isSelected
        well.floorColor = chip.isSelected ? PortfolioTheme.tintedFloor(color) : nil
        CATransaction.commit()
    }

    override var isHighlighted: Bool {
        didSet { if isHighlighted != oldValue { LitMotion.press(self, pressed: isHighlighted, scale: 0.95) } }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        plate.cornerRadiusValue = bounds.height / 2
        plate.frame = bounds
        well.cornerRadiusValue = bounds.height / 2
        well.place(in: bounds)
        CATransaction.commit()
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // 44 pt targets: an invisible margin around the 36 pt chip.
        bounds.insetBy(dx: -4, dy: -6).contains(point)
    }
}

/// A quick action: a soft raised pad of the sheet's own white with the glyph in red, a label below. Pressing
/// lets the pad into the sheet.
final class PortfolioQuickActionView: UIControl {
    private static let padSize = CGSize(width: 60, height: 52)
    private static let padRadius: CGFloat = 16
    private let pad: UIView
    private let backing: LitBacking
    private let glyph = UIImageView()
    private let label = UILabel()
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    let action: PortfolioQuickAction

    init(action: PortfolioQuickAction) {
        self.action = action
        let pad = UIView()
        self.pad = pad
        backing = LitBacking(host: pad)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backing.style = .raised(elevation: 10)
        pad.isUserInteractionEnabled = false
        glyph.contentMode = .center
        glyph.translatesAutoresizingMaskIntoConstraints = false
        pad.addSubview(glyph)
        label.textAlignment = .center
        label.font = PortfolioTheme.font(FontType.textBoldXS, .caption1, maximum: 20)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        [pad, label].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        NSLayoutConstraint.activate([
            pad.topAnchor.constraint(equalTo: topAnchor),
            pad.centerXAnchor.constraint(equalTo: centerXAnchor),
            pad.widthAnchor.constraint(equalToConstant: Self.padSize.width),
            pad.heightAnchor.constraint(equalToConstant: Self.padSize.height),
            glyph.centerXAnchor.constraint(equalTo: pad.centerXAnchor),
            glyph.centerYAnchor.constraint(equalTo: pad.centerYAnchor),
            label.topAnchor.constraint(equalTo: pad.bottomAnchor, constant: 9),
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
        addTarget(self, action: #selector(touchedDown), for: .touchDown)
        // Nearer the eye than the sheet it stands on.
        LitParallax.attach(to: pad, depth: 1.5)
        applyTheme()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyTheme() {
        let tokens = PortfolioTheme.tokens
        let red = Lit.lacquerText
        let title: String
        switch action {
        case .send:
            title = PortfolioStrings.send
            glyph.image = PortfolioGlyphs.symbol("arrow.up.right", pointSize: 19, color: red)
        case .receive:
            title = PortfolioStrings.receive
            glyph.image = PortfolioGlyphs.symbol("arrow.down.left", pointSize: 19, color: red)
        case .move:
            title = PortfolioStrings.move
            glyph.image = PortfolioGlyphs.moveImage(size: 24, color: red)
        case .swap:
            title = PortfolioStrings.swap
            glyph.image = PortfolioGlyphs.flowerImage(size: 24, color: red)
        }
        label.text = title
        label.textColor = tokens.textPrimary
        accessibilityLabel = title
    }

    /// The pad rises into place.
    func popIn(after delay: CFTimeInterval) {
        LitMotion.rise(pad, by: 7, after: delay)
    }

    override var isHighlighted: Bool {
        didSet {
            guard isHighlighted != oldValue else { return }
            backing.style = isHighlighted ? .pressed(floor: nil, depth: 2.5) : .raised(elevation: 10)
            glyph.transform = isHighlighted ? CGAffineTransform(translationX: 0, y: 0.75) : .identity
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        backing.layout(radius: Self.padRadius)
    }

    @objc private func touchedDown() {
        haptic.impactOccurred(intensity: 0.7)
    }
}

/// The 24 h change in a shallow well whose floor takes the direction's colour.
final class PortfolioChangePill: UIView {
    let label = UILabel.portfolio(FontType.amountS, .subheadline, lines: 0)
    private let well = LitWellLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        well.depth = 1.8
        layer.addSublayer(well)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12)
        ])
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func tint(_ color: UIColor) {
        well.floorColor = PortfolioTheme.tintedFloor(color)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // A capsule on one line; a rounded box when large text wraps it.
        well.cornerRadiusValue = min(bounds.height / 2, 18)
        well.place(in: bounds)
    }
}

/// A wallet dot (rows show one per wallet that holds a token).
final class PortfolioDotsView: UIStackView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        axis = .horizontal
        spacing = 3
        alignment = .center
        isAccessibilityElement = false
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(_ slots: [PortfolioSlot]) {
        arrangedSubviews.forEach { $0.removeFromSuperview() }
        for slot in slots.prefix(4) {
            let dot = UIView()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.backgroundColor = PortfolioTheme.color(for: slot)
            dot.layer.cornerRadius = 3.5
            NSLayoutConstraint.activate([dot.widthAnchor.constraint(equalToConstant: 7),
                                         dot.heightAnchor.constraint(equalToConstant: 7)])
            addArrangedSubview(dot)
        }
        isHidden = slots.isEmpty
    }
}

extension UILabel {
    /// Eyebrow text ("TOTAL BALANCE", "FROM"): the type scale's tracking needs attributed text.
    func setEyebrow(_ text: String, color: UIColor) {
        attributedText = NSAttributedString(string: text, attributes: [.font: font as Any, .foregroundColor: color, .kern: 1.2])
        accessibilityLabel = text.capitalized
    }

    static func portfolio(_ data: FontData, _ style: UIFont.TextStyle, color: UIColor? = nil, lines: Int = 1,
                          maximum: CGFloat? = nil) -> UILabel {
        let label = UILabel()
        label.font = PortfolioTheme.font(data, style, maximum: maximum)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = color ?? PortfolioTheme.textPrimary
        label.numberOfLines = lines
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
}
