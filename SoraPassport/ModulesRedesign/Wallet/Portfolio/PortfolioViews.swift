// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

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

/// A round token icon with a lettered fallback.
final class PortfolioTokenIconView: UIView {
    private let imageView = UIImageView()
    private let fallback = UILabel()
    private var size: CGFloat

    init(size: CGFloat) {
        self.size = size
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = false
        layer.cornerRadius = size / 2
        layer.cornerCurve = .continuous
        clipsToBounds = true
        imageView.contentMode = .scaleAspectFit
        fallback.textAlignment = .center
        fallback.adjustsFontSizeToFitWidth = true
        fallback.minimumScaleFactor = 0.5
        [imageView, fallback].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size),
            heightAnchor.constraint(equalToConstant: size),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            fallback.centerXAnchor.constraint(equalTo: centerXAnchor),
            fallback.centerYAnchor.constraint(equalTo: centerYAnchor),
            fallback.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.78)
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
            backgroundColor = image == nil ? PortfolioTheme.color(for: .slot(abs(id.hashValue) % 5)) : .clear
        case let .network(network):
            imageView.image = PortfolioBadges.network(network, size: size)
            imageView.isHidden = false
            fallback.isHidden = true
            backgroundColor = .clear
        case let .wallet(id, name):
            imageView.image = PortfolioBadges.wallet(id: id, name: name, size: size)
            imageView.isHidden = false
            fallback.isHidden = true
            backgroundColor = .clear
        case .allWallets:
            imageView.image = PortfolioBadges.allWallets(size: size)
            imageView.isHidden = false
            fallback.isHidden = true
            backgroundColor = .clear
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

    /// The flower on a pink badge with faint rings: the All wallets avatar.
    static func allWallets(size: CGFloat) -> UIImage? {
        cached("all|\(size)") {
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            return UIGraphicsImageRenderer(size: rect.size).image { context in
                let space = CGColorSpaceCreateDeviceRGB()
                let colors = [UIColor(portfolioHex: 0xFF2E86), UIColor(portfolioHex: 0xB0005A)].map(\.cgColor)
                context.cgContext.saveGState()
                UIBezierPath(ovalIn: rect).addClip()
                if let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: [0, 1]) {
                    context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size, y: size),
                                                         options: [])
                }
                for (fraction, alpha) in [(0.5, 0.22), (0.7, 0.14), (0.9, 0.07)] {
                    let radius = size / 2 * CGFloat(fraction)
                    let ring = UIBezierPath(ovalIn: CGRect(x: size / 2 - radius, y: size / 2 - radius,
                                                           width: radius * 2, height: radius * 2))
                    ring.lineWidth = 1
                    UIColor.white.withAlphaComponent(CGFloat(alpha)).setStroke()
                    ring.stroke()
                }
                context.cgContext.restoreGState()
                UIColor.white.setFill()
                PortfolioGlyphs.flowerPath(in: rect.insetBy(dx: size * 0.2, dy: size * 0.2)).fill()
            }
        }
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
            case .testnet: color = .systemOrange
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

/// Capsule with a dot: "● LIVE · 31s".
final class PortfolioFreshnessChip: UIControl {
    private let dot = UIView()
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        dot.layer.cornerRadius = 3.5
        dot.isUserInteractionEnabled = false
        label.isUserInteractionEnabled = false
        label.font = PortfolioTheme.font(FontType.eyebrow, .caption2, maximum: 18)
        label.adjustsFontForContentSizeCategory = true
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        [dot, label].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        NSLayoutConstraint.activate([
            dot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            dot.centerYAnchor.constraint(equalTo: centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 7),
            dot.heightAnchor.constraint(equalToConstant: 7),
            label.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 7),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -11),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
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
        dot.backgroundColor = color
        label.textColor = tone == .partial ? tokens.warning : tokens.textSecondary
        backgroundColor = tokens.glassFill
        layer.borderColor = tokens.hairline.cgColor
        accessibilityLabel = text
        accessibilityTraits = tone == .live ? .staticText : .button
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }
}

/// Legend chip: dot, name, percent. The fan's accessible twin.
final class PortfolioLegendChipView: UIControl {
    private let dot = UIView()
    private let title = UILabel()
    private let percent = UILabel()
    private(set) var key: String = ""
    private var color: UIColor = .clear

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        dot.layer.cornerRadius = 2.5
        dot.layer.cornerCurve = .continuous
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
            dot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            dot.centerYAnchor.constraint(equalTo: centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 9),
            dot.heightAnchor.constraint(equalToConstant: 9),
            title.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 8),
            title.centerYAnchor.constraint(equalTo: centerYAnchor),
            percent.leadingAnchor.constraint(equalTo: title.trailingAnchor, constant: 6),
            percent.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -13),
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
        applyColors(selected: chip.isSelected)
    }

    private func applyColors(selected: Bool) {
        let tokens = PortfolioTheme.tokens
        dot.backgroundColor = color
        title.textColor = tokens.textPrimary
        percent.textColor = tokens.textSecondary
        backgroundColor = selected ? color.withAlphaComponent(PortfolioTheme.isDark ? 0.18 : 0.12) : tokens.glassFill
        layer.borderColor = (selected ? color : tokens.hairline).cgColor
        layer.borderWidth = selected ? 1.5 : 1
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.7 : 1 }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // 44 pt targets: an invisible margin around the 36 pt chip.
        bounds.insetBy(dx: -4, dy: -6).contains(point)
    }
}

/// A quick action: a tactile disc with a glyph and a label below.
final class PortfolioQuickActionView: UIControl {
    let disc = NeumorphicControl()
    private let glyph = UIImageView()
    private let label = UILabel()
    let action: PortfolioQuickAction

    init(action: PortfolioQuickAction) {
        self.action = action
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        disc.shape = .capsule
        disc.isUserInteractionEnabled = false
        glyph.contentMode = .center
        label.textAlignment = .center
        label.font = PortfolioTheme.font(FontType.textBoldXS, .caption1, maximum: 20)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        [disc, label].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        glyph.translatesAutoresizingMaskIntoConstraints = false
        disc.contentView.addSubview(glyph)
        NSLayoutConstraint.activate([
            disc.topAnchor.constraint(equalTo: topAnchor),
            disc.centerXAnchor.constraint(equalTo: centerXAnchor),
            disc.widthAnchor.constraint(equalToConstant: 54),
            disc.heightAnchor.constraint(equalToConstant: 54),
            glyph.centerXAnchor.constraint(equalTo: disc.centerXAnchor),
            glyph.centerYAnchor.constraint(equalTo: disc.centerYAnchor),
            label.topAnchor.constraint(equalTo: disc.bottomAnchor, constant: 8),
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
        applyTheme()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyTheme() {
        let tokens = PortfolioTheme.tokens
        let title: String
        switch action {
        case .send:
            title = PortfolioStrings.send
            glyph.image = PortfolioGlyphs.symbol("arrow.up.right", pointSize: 19, color: tokens.textPrimary)
        case .receive:
            title = PortfolioStrings.receive
            glyph.image = PortfolioGlyphs.symbol("arrow.down.left", pointSize: 19, color: tokens.textPrimary)
        case .move:
            title = PortfolioStrings.move
            glyph.image = PortfolioGlyphs.moveImage(size: 24, color: tokens.textPrimary)
        case .swap:
            title = PortfolioStrings.swap
            glyph.image = PortfolioGlyphs.flowerImage(size: 24)
        }
        label.text = title
        label.textColor = tokens.textPrimary
        accessibilityLabel = title
        disc.apply()
    }

    override var isHighlighted: Bool {
        // The disc presses itself (shadow, face and scale); the label stays still.
        didSet { disc.isHighlighted = isHighlighted }
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
        for slot in slots.prefix(6) {
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
        attributedText = NSAttributedString(string: text, attributes: [
            .font: font as Any, .foregroundColor: color, .kern: 1.2
        ])
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
