// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import SoraUIKit
import UIKit

/// The hero row: sky, scope chip and the glass card with the total.
final class PortfolioHeroItem: NSObject {
    var model: PortfolioHeroModel? {
        didSet { if model != oldValue { onModelChange?() } }
    }

    /// Height of the safe area above the sky's content.
    var topInset: CGFloat = 0 {
        didSet { if topInset != oldValue { onModelChange?() } }
    }

    /// The sky is on screen (the parallax gate).
    var isSkyVisible = false {
        didSet { if isSkyVisible != oldValue { onVisibilityChange?(isSkyVisible) } }
    }

    var onScope: (() -> Void)?
    var onChip: (() -> Void)?
    var onCaption: (() -> Void)?
    var onGroup: ((String) -> Void)?
    var onQuickAction: ((PortfolioQuickAction) -> Void)?

    fileprivate var onModelChange: (() -> Void)?
    fileprivate var onVisibilityChange: ((Bool) -> Void)?
}

extension PortfolioHeroItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { PortfolioHeroCell.self }
    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }
    var clipsToBounds: Bool { false }

    func itemHeight(forWidth width: CGFloat, context: SoramitsuTableViewContext?) -> CGFloat {
        UITableView.automaticDimension
    }
}

final class PortfolioHeroCell: SoramitsuTableViewCell, SoramitsuTableViewCellProtocol {
    private weak var item: PortfolioHeroItem?
    private let sky = PortfolioSkyView()
    private let scopeButton = PortfolioScopeButton()
    private let card = GlassView()
    private let stack = UIStackView()
    private let eyebrow = UILabel.portfolio(FontType.eyebrow, .caption2, color: PortfolioTheme.textSecondary, maximum: 18)
    private let chip = PortfolioFreshnessChip()
    private let totalLabel = UILabel()
    private let changeLabel = UILabel.portfolio(FontType.amountS, .subheadline, lines: 0)
    private let captionButton = UIButton(type: .system)
    private let legendScroll = UIScrollView()
    private let legendStack = UIStackView()
    private let actionsStack = UIStackView()
    private let actionRows = [UIStackView(), UIStackView()]
    private lazy var actionViews: [PortfolioQuickActionView] = ([.send, .receive, .move, .swap] as [PortfolioQuickAction]).map {
        let view = PortfolioQuickActionView(action: $0)
        view.addTarget(self, action: #selector(quickAction(_:)), for: .touchUpInside)
        return view
    }
    private let emptyTitle = UILabel.portfolio(FontType.headline2, .title3, lines: 0)
    private let emptyDetail = UILabel.portfolio(FontType.paragraphS, .subheadline, color: PortfolioTheme.textSecondary, lines: 0)
    private lazy var emptyReceive = PortfolioPrimaryButton(title: PortfolioStrings.receive) { [weak self] in
        self?.item?.onQuickAction?(.receive)
    }
    private var skyHeight: NSLayoutConstraint?
    private var scopeTop: NSLayoutConstraint?
    private lazy var parallax = PortfolioParallaxController(layers: [
        .init(view: sky.starsView, depth: PortfolioTheme.Depth.stars),
        .init(view: sky.glowView, depth: PortfolioTheme.Depth.glow, yFactor: 0),
        .init(view: sky.fanView, depth: PortfolioTheme.Depth.fan),
        .init(view: sky.sheenView, depth: PortfolioTheme.Depth.sheen),
        .init(view: sky.flowerView, depth: PortfolioTheme.Depth.flower, rotateDeg: PortfolioTheme.Depth.flowerRotationDeg)
    ])

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
        clipsToBounds = false
        contentView.clipsToBounds = false
        setupViews()
        parallax.onRender = { [weak self] x, _ in self?.sky.setSheen(deflection: x) }
        SoramitsuUI.updates.addObserver(self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        [sky, card, scopeButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        card.shape = .chamfer(radius: 24, cut: 18)
        card.fill = .strong

        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.contentView.addSubview(stack)

        let header = UIStackView(arrangedSubviews: [eyebrow, UIView(), chip])
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 8
        eyebrow.text = PortfolioStrings.totalBalance
        chip.addTarget(self, action: #selector(chipTapped), for: .touchUpInside)

        totalLabel.numberOfLines = 1
        totalLabel.adjustsFontSizeToFitWidth = true
        totalLabel.minimumScaleFactor = 0.6
        totalLabel.adjustsFontForContentSizeCategory = true
        totalLabel.accessibilityTraits = .header

        captionButton.contentHorizontalAlignment = .leading
        captionButton.titleLabel?.numberOfLines = 0
        captionButton.addTarget(self, action: #selector(captionTapped), for: .touchUpInside)

        legendScroll.showsHorizontalScrollIndicator = false
        legendScroll.alwaysBounceHorizontal = true
        legendScroll.clipsToBounds = false
        legendStack.axis = .horizontal
        legendStack.spacing = 8
        legendStack.alignment = .center
        legendStack.translatesAutoresizingMaskIntoConstraints = false
        legendScroll.addSubview(legendStack)

        actionRows.forEach {
            $0.axis = .horizontal
            $0.distribution = .fillEqually
            $0.spacing = 8
        }
        actionsStack.axis = .vertical
        actionsStack.spacing = 16
        actionRows.forEach { actionsStack.addArrangedSubview($0) }

        [header, totalLabel, changeLabel, captionButton, legendScroll, actionsStack,
         emptyTitle, emptyDetail, emptyReceive].forEach { stack.addArrangedSubview($0) }
        stack.setCustomSpacing(10, after: header)
        stack.setCustomSpacing(2, after: totalLabel)
        stack.setCustomSpacing(10, after: changeLabel)
        stack.setCustomSpacing(14, after: captionButton)
        stack.setCustomSpacing(18, after: legendScroll)
        stack.setCustomSpacing(6, after: emptyTitle)
        stack.setCustomSpacing(18, after: emptyDetail)
        emptyTitle.text = PortfolioStrings.walletReady
        emptyDetail.text = PortfolioStrings.walletReadyDetail

        scopeButton.addTarget(self, action: #selector(scopeTapped), for: .touchUpInside)
        sky.onSegmentTap = { [weak self] key in self?.item?.onGroup?(key) }

        let skyHeight = sky.heightAnchor.constraint(equalToConstant: PortfolioTheme.Sky.height)
        let scopeTop = scopeButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6)
        self.skyHeight = skyHeight
        self.scopeTop = scopeTop
        NSLayoutConstraint.activate([
            sky.topAnchor.constraint(equalTo: contentView.topAnchor),
            sky.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            sky.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            skyHeight,
            scopeTop,
            scopeButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            scopeButton.trailingAnchor.constraint(lessThanOrEqualTo: contentView.centerXAnchor, constant: 40),
            card.topAnchor.constraint(equalTo: sky.bottomAnchor, constant: -PortfolioTheme.Sky.cardOverlap),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            stack.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -18),
            legendStack.leadingAnchor.constraint(equalTo: legendScroll.contentLayoutGuide.leadingAnchor),
            legendStack.trailingAnchor.constraint(equalTo: legendScroll.contentLayoutGuide.trailingAnchor),
            legendStack.topAnchor.constraint(equalTo: legendScroll.contentLayoutGuide.topAnchor),
            legendStack.bottomAnchor.constraint(equalTo: legendScroll.contentLayoutGuide.bottomAnchor),
            legendStack.heightAnchor.constraint(equalTo: legendScroll.frameLayoutGuide.heightAnchor),
            legendScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 40)
        ])
    }

    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? PortfolioHeroItem else { return }
        self.item?.onModelChange = nil
        self.item?.onVisibilityChange = nil
        self.item = item
        item.onModelChange = { [weak self] in self?.reload(animated: true) }
        item.onVisibilityChange = { [weak self] visible in self?.parallax.setHeroVisible(visible) }
        reload(animated: false)
        parallax.setHeroVisible(item.isSkyVisible)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            parallax.start()
            #if !F_RELEASE
            if let tilt = PortfolioDebugOptions.injectedTilt {
                parallax.inject(x: tilt.x, y: tilt.y)
            }
            #endif
        } else {
            parallax.stop()
        }
    }

    private func reload(animated: Bool) {
        guard let item, let model = item.model else { return }
        let tokens = PortfolioTheme.tokens
        skyHeight?.constant = item.topInset + PortfolioTheme.Sky.height
        scopeTop?.constant = item.topInset + 6
        sky.topInset = item.topInset

        scopeButton.configure(title: model.scopeTitle, icon: model.scopeIcon, enabled: model.canChangeScope)
        chip.configure(text: model.chipText, tone: model.chipTone)
        chip.isHidden = model.isLoading
        eyebrow.setEyebrow(PortfolioStrings.totalBalance, color: tokens.textSecondary)

        let wholeFont = PortfolioTheme.font(FontType.displayHero, .largeTitle, maximum: 64)
        let fractionFont = PortfolioTheme.font(FontType.displayHero, size: 26, .title2)
        let primary = model.isDimmed ? tokens.textSecondary : tokens.textPrimary
        let total = NSMutableAttributedString(string: model.totalWhole, attributes: [
            .font: wholeFont, .foregroundColor: primary, .kern: -0.5
        ])
        total.append(NSAttributedString(string: model.totalFraction, attributes: [
            .font: fractionFont, .foregroundColor: tokens.textSecondary
        ]))
        totalLabel.attributedText = total
        totalLabel.accessibilityLabel = model.accessibilityTotal

        changeLabel.isHidden = model.isEmpty || model.changeAmount == nil
        if let amount = model.changeAmount, let percent = model.changePercent {
            let color: UIColor
            let arrow: String
            switch model.direction {
            case .up: color = tokens.success; arrow = "▲ "
            case .down: color = tokens.error; arrow = "▼ "
            case .flat: color = tokens.textSecondary; arrow = ""
            }
            let text = NSMutableAttributedString(string: arrow + amount, attributes: [
                .font: PortfolioTheme.font(FontType.amountM, .subheadline, maximum: 26),
                .foregroundColor: model.isDimmed ? tokens.textSecondary : color
            ])
            text.append(NSAttributedString(string: " · \(percent) · \(PortfolioStrings.hours24)", attributes: [
                .font: PortfolioTheme.font(FontType.amountS, .subheadline, maximum: 24),
                .foregroundColor: tokens.textSecondary
            ]))
            changeLabel.attributedText = text
            changeLabel.isAccessibilityElement = false
        }

        captionButton.isHidden = model.caption == nil
        if let caption = model.caption {
            var configuration = UIButton.Configuration.plain()
            configuration.contentInsets = .zero
            configuration.imagePadding = 7
            configuration.image = PortfolioGlyphs.symbol("info.circle", pointSize: 14, weight: .regular, color: tokens.info)
            configuration.attributedTitle = AttributedString(caption, attributes: AttributeContainer([
                .font: PortfolioTheme.font(FontType.textS, .footnote, maximum: 24),
                .foregroundColor: tokens.textSecondary
            ]))
            captionButton.configuration = configuration
            captionButton.accessibilityHint = PortfolioStrings.howWeCount
        }

        configureLegend(model.legend)
        sky.applyTheme()
        sky.apply(PortfolioSkyView.Model(segments: model.sky.segments, highlightedKey: model.sky.highlightedKey,
                                         showsFan: model.sky.showsFan), animated: animated)
        actionViews.forEach { $0.applyTheme() }
        layoutForContentSize()

        let empty = model.isEmpty
        [totalLabel, legendScroll, actionsStack].forEach { $0.isHidden = empty }
        changeLabel.isHidden = changeLabel.isHidden || empty
        captionButton.isHidden = captionButton.isHidden || empty
        legendScroll.isHidden = empty || model.legend.isEmpty
        [emptyTitle, emptyDetail, emptyReceive].forEach { $0.isHidden = !empty }
        emptyTitle.textColor = tokens.textPrimary
        emptyDetail.textColor = tokens.textSecondary

        accessibilityElements = [scopeButton, totalLabel, captionButton, chip] + legendStack.arrangedSubviews +
            actionViews + [emptyTitle, emptyDetail, emptyReceive]
    }

    private func configureLegend(_ chips: [PortfolioLegendChip]) {
        while legendStack.arrangedSubviews.count < chips.count {
            let view = PortfolioLegendChipView()
            view.addTarget(self, action: #selector(legendTapped(_:)), for: .touchUpInside)
            legendStack.addArrangedSubview(view)
        }
        for (index, view) in legendStack.arrangedSubviews.enumerated() {
            guard let chipView = view as? PortfolioLegendChipView else { continue }
            if index < chips.count {
                chipView.configure(chips[index])
                chipView.isHidden = false
            } else {
                chipView.isHidden = true
            }
        }
    }

    private func layoutForContentSize() {
        let large = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        legendStack.axis = large ? .vertical : .horizontal
        legendStack.alignment = large ? .leading : .center
        legendScroll.isScrollEnabled = !large
        actionRows.forEach { row in row.arrangedSubviews.forEach { $0.removeFromSuperview() } }
        if large {
            actionRows[0].addArrangedSubview(actionViews[0])
            actionRows[0].addArrangedSubview(actionViews[1])
            actionRows[1].addArrangedSubview(actionViews[2])
            actionRows[1].addArrangedSubview(actionViews[3])
            actionRows[1].isHidden = false
        } else {
            actionViews.forEach { actionRows[0].addArrangedSubview($0) }
            actionRows[1].isHidden = true
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            reload(animated: false)
        }
    }

    // MARK: Actions

    @objc private func scopeTapped() { item?.onScope?() }
    @objc private func chipTapped() { item?.onChip?() }
    @objc private func captionTapped() { item?.onCaption?() }

    @objc private func legendTapped(_ sender: PortfolioLegendChipView) {
        item?.onGroup?(sender.key)
    }

    @objc private func quickAction(_ sender: PortfolioQuickActionView) {
        item?.onQuickAction?(sender.action)
    }
}

extension PortfolioHeroCell: SoramitsuObserver {
    func styleDidChange(options: UpdateOptions) {
        guard options.contains(.palette) else { return }
        reload(animated: false)
    }
}

/// The scope chip at the top-left of the sky: avatar, name, chevron.
final class PortfolioScopeButton: UIControl {
    private let background = GlassView()
    private let avatar = PortfolioTokenIconView(size: 26)
    private let title = UILabel.portfolio(FontType.headline3, .subheadline, maximum: 24)
    private let chevron = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        background.shape = .capsule
        background.fill = .strong
        background.isUserInteractionEnabled = false
        [background, avatar, title, chevron].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.isUserInteractionEnabled = false
            addSubview($0)
        }
        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: leadingAnchor),
            background.trailingAnchor.constraint(equalTo: trailingAnchor),
            background.topAnchor.constraint(equalTo: topAnchor),
            background.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            avatar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 9),
            avatar.centerYAnchor.constraint(equalTo: centerYAnchor),
            title.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 9),
            title.centerYAnchor.constraint(equalTo: centerYAnchor),
            title.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 8),
            chevron.leadingAnchor.constraint(equalTo: title.trailingAnchor, constant: 8),
            chevron.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            chevron.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title text: String, icon: PortfolioIcon, enabled: Bool) {
        let tokens = PortfolioTheme.tokens
        title.text = text
        title.textColor = tokens.textPrimary
        avatar.configure(icon)
        chevron.image = PortfolioGlyphs.symbol("chevron.down", pointSize: 12, color: tokens.textSecondary)
        chevron.isHidden = !enabled
        isEnabled = enabled
        background.apply()
        accessibilityLabel = text
        accessibilityHint = enabled ? PortfolioStrings.wallets : nil
        accessibilityTraits = enabled ? .button : .staticText
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.7 : 1 }
    }
}

/// The app's primary call to action: the Neon gradient capsule.
final class PortfolioPrimaryButton: UIControl {
    enum Style {
        case primary
        case swap
    }

    private let gradient = NeonGradientView()
    private let label = UILabel.portfolio(FontType.buttonM, .headline, maximum: 28)
    private let glyph = UIImageView()
    private let content = UIStackView()
    private let handler: () -> Void
    private let style: Style

    init(title: String, style: Style = .primary, showsFlower: Bool = false, handler: @escaping () -> Void) {
        self.handler = handler
        self.style = style
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerCurve = .continuous
        clipsToBounds = true
        gradient.translatesAutoresizingMaskIntoConstraints = false
        addSubview(gradient)
        content.axis = .horizontal
        content.spacing = 8
        content.alignment = .center
        content.isUserInteractionEnabled = false
        content.translatesAutoresizingMaskIntoConstraints = false
        glyph.image = PortfolioGlyphs.flowerImage(size: 20, color: .white)
        glyph.isHidden = !showsFlower
        content.addArrangedSubview(glyph)
        content.addArrangedSubview(label)
        addSubview(content)
        label.text = title
        label.textAlignment = .center
        label.numberOfLines = 0
        let minimumHeight = heightAnchor.constraint(greaterThanOrEqualToConstant: 52)
        let verticalInset = content.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 12)
        // A hidden arranged button must yield to UIStackView's required zero-height constraint.
        minimumHeight.priority = UILayoutPriority(999)
        verticalInset.priority = UILayoutPriority(999)
        NSLayoutConstraint.activate([
            gradient.leadingAnchor.constraint(equalTo: leadingAnchor),
            gradient.trailingAnchor.constraint(equalTo: trailingAnchor),
            gradient.topAnchor.constraint(equalTo: topAnchor),
            gradient.bottomAnchor.constraint(equalTo: bottomAnchor),
            minimumHeight,
            content.centerXAnchor.constraint(equalTo: centerXAnchor),
            content.centerYAnchor.constraint(equalTo: centerYAnchor),
            content.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 20),
            verticalInset
        ])
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = title
        applyTheme()
        SoramitsuUI.updates.addObserver(self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setTitle(_ title: String) {
        label.text = title
        accessibilityLabel = title
    }

    func applyTheme() {
        let tokens = PortfolioTheme.tokens
        gradient.apply(style == .swap ? tokens.ctaSwap : tokens.ctaPrimary)
        label.textColor = .white
        alpha = isEnabled ? 1 : 0.45
    }

    override var isEnabled: Bool {
        didSet {
            alpha = isEnabled ? 1 : 0.45
            accessibilityTraits = isEnabled ? .button : [.button, .notEnabled]
        }
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.85 : (isEnabled ? 1 : 0.45) }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }

    @objc private func tapped() { handler() }
}

extension PortfolioPrimaryButton: SoramitsuObserver {
    func styleDidChange(options: UpdateOptions) {
        if options.contains(.palette) { applyTheme() }
    }
}
