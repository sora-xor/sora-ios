// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

import SoraUIKit
import UIKit

/// Where it lives: one token's holdings by network and wallet, with the route to Polkaswap.
final class PortfolioDetailViewController: UIViewController {
    var onAction: ((PortfolioActionPlan.Action, String) -> Void)?
    var onPolkaswap: ((String?) -> Void)?

    private let tokenId: String
    private var selectedHoldingId: String?
    private let modelProvider: (String, String?) -> PortfolioDetailModel?
    private var model: PortfolioDetailModel?

    private let aurora = AuroraView()
    private let scrollView = UIScrollView()
    private let content = UIStackView()
    private let orbit = PortfolioOrbitView()
    private let symbolLabel = UILabel.portfolio(FontType.displayL, .largeTitle, maximum: 52)
    private let nameLabel = UILabel.portfolio(FontType.textM, .body, color: PortfolioTheme.textSecondary, maximum: 28)
    private let amountLabel = UILabel.portfolio(FontType.displayM, .title2, lines: 0, maximum: 40)
    private let summaryLabel = UILabel.portfolio(FontType.amountS, .subheadline, lines: 0, maximum: 28)
    private let sectionTitle = UILabel.portfolio(FontType.headline1, .title2, lines: 0, maximum: 40)
    private let countsLabel = UILabel.portfolio(FontType.eyebrow, .caption2, color: PortfolioTheme.textSecondary, maximum: 18)
    private let holdingsCard = GlassView()
    private let holdingsStack = UIStackView()
    private let polkaswapCard = GlassView()
    private let polkaswapStack = UIStackView()
    private var parallax: PortfolioParallaxController?

    init(tokenId: String, holdingId: String?, modelProvider: @escaping (String, String?) -> PortfolioDetailModel?) {
        self.tokenId = tokenId
        selectedHoldingId = holdingId
        self.modelProvider = modelProvider
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = PortfolioTheme.tokens.canvas
        navigationItem.largeTitleDisplayMode = .never
        [aurora, scrollView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        scrollView.alwaysBounceVertical = true
        scrollView.delegate = self
        // The bar takes its material (standard appearance) once content scrolls under it.
        setContentScrollView(scrollView, for: .top)
        content.axis = .vertical
        content.spacing = 0
        content.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(content)
        NSLayoutConstraint.activate([
            aurora.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            aurora.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            aurora.topAnchor.constraint(equalTo: view.topAnchor),
            aurora.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            content.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32),
            content.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        orbit.translatesAutoresizingMaskIntoConstraints = false
        orbit.heightAnchor.constraint(equalToConstant: 250).isActive = true
        orbit.onSatellite = { [weak self] holdingId in self?.select(holdingId) }
        content.addArrangedSubview(orbit)

        let titleLine = UIStackView(arrangedSubviews: [symbolLabel, nameLabel, UIView()])
        titleLine.axis = .horizontal
        titleLine.spacing = 10
        titleLine.alignment = .lastBaseline
        let header = UIStackView(arrangedSubviews: [titleLine, amountLabel, summaryLabel])
        header.axis = .vertical
        header.spacing = 6
        header.setCustomSpacing(2, after: titleLine)
        header.isLayoutMarginsRelativeArrangement = true
        // Margins are the design's, not widened where a row passes the home indicator.
        header.insetsLayoutMarginsFromSafeArea = false
        header.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 4, leading: 24, bottom: 20, trailing: 24)
        header.accessibilityElements = [symbolLabel, nameLabel, amountLabel, summaryLabel]
        content.addArrangedSubview(header)

        // The counts sit under the title: side by side they truncate at most widths.
        countsLabel.numberOfLines = 0
        let sectionLine = UIStackView(arrangedSubviews: [sectionTitle, countsLabel])
        sectionLine.axis = .vertical
        sectionLine.alignment = .leading
        sectionLine.spacing = 4
        sectionLine.isLayoutMarginsRelativeArrangement = true
        sectionLine.insetsLayoutMarginsFromSafeArea = false
        sectionLine.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 4, leading: 24, bottom: 12, trailing: 24)
        sectionTitle.text = PortfolioStrings.whereItLives
        sectionTitle.accessibilityTraits = .header
        content.addArrangedSubview(sectionLine)

        holdingsStack.axis = .vertical
        holdingsStack.translatesAutoresizingMaskIntoConstraints = false
        holdingsCard.shape = .rounded(24)
        holdingsCard.contentView.addSubview(holdingsStack)
        polkaswapStack.axis = .vertical
        polkaswapStack.spacing = 12
        polkaswapStack.translatesAutoresizingMaskIntoConstraints = false
        polkaswapCard.shape = .rounded(24)
        polkaswapCard.border = .spectrum
        polkaswapCard.contentView.addSubview(polkaswapStack)
        NSLayoutConstraint.activate([
            holdingsStack.leadingAnchor.constraint(equalTo: holdingsCard.contentView.leadingAnchor),
            holdingsStack.trailingAnchor.constraint(equalTo: holdingsCard.contentView.trailingAnchor),
            holdingsStack.topAnchor.constraint(equalTo: holdingsCard.contentView.topAnchor, constant: 4),
            holdingsStack.bottomAnchor.constraint(equalTo: holdingsCard.contentView.bottomAnchor, constant: -4),
            polkaswapStack.leadingAnchor.constraint(equalTo: polkaswapCard.contentView.leadingAnchor, constant: 18),
            polkaswapStack.trailingAnchor.constraint(equalTo: polkaswapCard.contentView.trailingAnchor, constant: -18),
            polkaswapStack.topAnchor.constraint(equalTo: polkaswapCard.contentView.topAnchor, constant: 18),
            polkaswapStack.bottomAnchor.constraint(equalTo: polkaswapCard.contentView.bottomAnchor, constant: -18)
        ])
        content.addArrangedSubview(inset(holdingsCard))
        content.setCustomSpacing(16, after: content.arrangedSubviews.last!)
        content.addArrangedSubview(inset(polkaswapCard))

        parallax = PortfolioParallaxController(layers: [
            .init(view: orbit.ringView, depth: PortfolioTheme.Depth.ring, yFactor: 0.6),
            .init(view: orbit.orbView, depth: PortfolioTheme.Depth.orb, yFactor: 0.6),
            .init(view: orbit.satellitesView, depth: PortfolioTheme.Depth.satellites, yFactor: 0.6),
            .init(view: orbit.nodeView, depth: PortfolioTheme.Depth.polkaswapNode, yFactor: 0.6)
        ])
        SoramitsuUI.updates.addObserver(self)
        reload()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        reload()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        parallax?.start()
        parallax?.setHeroVisible(true)
        #if !F_RELEASE
        if let tilt = PortfolioDebugOptions.injectedTilt {
            parallax?.inject(x: tilt.x, y: tilt.y)
        }
        #endif
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        parallax?.stop()
    }

    private func inset(_ view: UIView) -> UIView {
        let wrapper = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 16),
            view.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -16),
            view.topAnchor.constraint(equalTo: wrapper.topAnchor),
            view.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor)
        ])
        return wrapper
    }

    func reload() {
        guard isViewLoaded else { return }
        guard let model = modelProvider(tokenId, selectedHoldingId) else {
            navigationController?.popViewController(animated: true)
            return
        }
        self.model = model
        selectedHoldingId = model.panel?.holdingId
        let tokens = PortfolioTheme.tokens
        view.backgroundColor = tokens.canvas
        orbit.configure(model)
        symbolLabel.text = model.symbol
        symbolLabel.textColor = tokens.textPrimary
        nameLabel.text = model.name
        nameLabel.textColor = tokens.textSecondary
        amountLabel.text = model.amount
        amountLabel.textColor = tokens.textPrimary
        let summary = NSMutableAttributedString(string: model.value, attributes: [.foregroundColor: tokens.textSecondary])
        if let change = model.change {
            summary.append(NSAttributedString(string: "   " + change, attributes: [
                .foregroundColor: model.direction == .down ? tokens.error : tokens.success
            ]))
        }
        summary.append(NSAttributedString(string: "   " + model.share, attributes: [.foregroundColor: tokens.textSecondary]))
        summaryLabel.attributedText = summary
        sectionTitle.textColor = tokens.textPrimary
        countsLabel.setEyebrow(model.counts, color: tokens.textSecondary)
        navigationItem.title = scrollView.contentOffset.y > 220 ? PortfolioStrings.format("%@ · where it lives", model.symbol) : nil
        buildHoldings(model)
        buildPolkaswap(model)
    }

    private func select(_ holdingId: String) {
        guard holdingId != selectedHoldingId else { return }
        selectedHoldingId = holdingId
        if UIAccessibility.isReduceMotionEnabled {
            reload()
        } else {
            UIView.animate(withDuration: NeonMotion.base) {
                self.reload()
                self.view.layoutIfNeeded()
            }
        }
        if let index = model?.holdings.firstIndex(where: { $0.id == holdingId }),
           holdingsStack.arrangedSubviews.indices.contains(index) {
            UIAccessibility.post(notification: .layoutChanged, argument: holdingsStack.arrangedSubviews[index])
        }
    }

    // MARK: Holdings

    private func buildHoldings(_ model: PortfolioDetailModel) {
        holdingsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        holdingsCard.apply()
        for (index, holding) in model.holdings.enumerated() {
            let row = PortfolioDetailHoldingRow()
            row.configure(holding, showsSeparator: index > 0 && !(model.holdings[index - 1].isSelected))
            row.onTap = { [weak self] in self?.select(holding.id) }
            if holding.isSelected, let panel = model.panel {
                let container = UIStackView(arrangedSubviews: [row, makePanel(panel, symbol: model.symbol)])
                container.axis = .vertical
                container.isLayoutMarginsRelativeArrangement = true
                container.insetsLayoutMarginsFromSafeArea = false
                let accent = UIView()
                accent.backgroundColor = PortfolioTheme.flowerPink
                accent.layer.cornerRadius = 1.5
                accent.translatesAutoresizingMaskIntoConstraints = false
                let wrapper = UIView()
                wrapper.backgroundColor = PortfolioTheme.isDark ? PortfolioTheme.flowerPink.withAlphaComponent(0.07)
                    : PortfolioTheme.flowerPink.withAlphaComponent(0.04)
                container.translatesAutoresizingMaskIntoConstraints = false
                wrapper.addSubview(container)
                wrapper.addSubview(accent)
                NSLayoutConstraint.activate([
                    container.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
                    container.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
                    container.topAnchor.constraint(equalTo: wrapper.topAnchor),
                    container.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -16),
                    accent.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 4),
                    accent.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 12),
                    accent.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -12),
                    accent.widthAnchor.constraint(equalToConstant: 3)
                ])
                holdingsStack.addArrangedSubview(wrapper)
            } else {
                holdingsStack.addArrangedSubview(row)
            }
        }
    }

    private func makePanel(_ panel: PortfolioDetailModel.Panel, symbol: String) -> UIView {
        let tokens = PortfolioTheme.tokens
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.isLayoutMarginsRelativeArrangement = true
        stack.insetsLayoutMarginsFromSafeArea = false
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 2, leading: 16, bottom: 0, trailing: 16)

        // Breakdown: a bar with a pattern for the locked part, never colour alone.
        let breakdown = PortfolioBreakdownView()
        breakdown.configure(panel)
        stack.addArrangedSubview(breakdown)

        let route = PortfolioRouteCard()
        route.configure(panel.route)
        stack.addArrangedSubview(route)

        if let note = panel.switchNote {
            let label = UILabel.portfolio(FontType.paragraphS, .footnote, color: tokens.textSecondary, lines: 0, maximum: 26)
            let attachment = NSTextAttachment(image: PortfolioGlyphs.symbol("arrow.triangle.2.circlepath", pointSize: 12,
                                                                            color: tokens.info) ?? UIImage())
            let text = NSMutableAttributedString(attachment: attachment)
            text.append(NSAttributedString(string: " " + note))
            label.attributedText = text
            stack.addArrangedSubview(label)
        }

        let primary = PortfolioPrimaryButton(title: panel.primary.title,
                                             style: panel.primary.kind == .swap ? .swap : .primary,
                                             showsFlower: panel.primary.kind == .swap) { [weak self] in
            self?.onAction?(panel.primary.kind, panel.holdingId)
        }
        primary.isEnabled = panel.primary.isEnabled
        stack.addArrangedSubview(primary)
        if let reason = panel.primary.reason {
            stack.addArrangedSubview(reasonLabel(reason))
        }
        let secondary = UIStackView()
        secondary.axis = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? .vertical : .horizontal
        secondary.spacing = 10
        secondary.distribution = .fillEqually
        var reasons: [String] = []
        for action in panel.secondary {
            let button = PortfolioSecondaryButton(action: action) { [weak self] in
                self?.onAction?(action.kind, panel.holdingId)
            }
            secondary.addArrangedSubview(button)
            if let reason = action.reason { reasons.append("\(action.title): \(reason)") }
        }
        stack.addArrangedSubview(secondary)
        reasons.forEach { stack.addArrangedSubview(reasonLabel($0)) }
        return stack
    }

    private func reasonLabel(_ text: String) -> UILabel {
        let label = UILabel.portfolio(FontType.textXS, .caption1, color: PortfolioTheme.textSecondary, lines: 0, maximum: 22)
        label.text = text
        return label
    }

    // MARK: Polkaswap card

    private func buildPolkaswap(_ model: PortfolioDetailModel) {
        polkaswapStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        polkaswapCard.apply()
        let tokens = PortfolioTheme.tokens
        let badge = UIImageView(image: PortfolioGlyphs.flowerImage(size: 26, color: .white))
        badge.contentMode = .center
        badge.backgroundColor = PortfolioTheme.flowerPink
        badge.layer.cornerRadius = 24
        badge.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([badge.widthAnchor.constraint(equalToConstant: 48),
                                     badge.heightAnchor.constraint(equalToConstant: 48)])
        let title = UILabel.portfolio(FontType.headline2, .title3, maximum: 32)
        title.text = "Polkaswap"
        title.textColor = tokens.textPrimary
        let detail = UILabel.portfolio(FontType.paragraphS, .subheadline, color: tokens.textSecondary, lines: 0, maximum: 26)
        detail.text = PortfolioStrings.text("The SORA DEX. Swaps happen on SORA2, so the token has to be there.")
        let texts = UIStackView(arrangedSubviews: [title, detail])
        texts.axis = .vertical
        texts.spacing = 2
        let top = UIStackView(arrangedSubviews: [badge, texts])
        top.axis = .horizontal
        top.spacing = 14
        top.alignment = .center
        polkaswapStack.addArrangedSubview(top)
        for check in model.polkaswap.checks {
            let symbol = check.isMet ? "checkmark" : "circle"
            let color = check.isMet ? tokens.success : tokens.textTertiary
            let label = UILabel.portfolio(FontType.textS, .subheadline, lines: 0, maximum: 26)
            let text = NSMutableAttributedString(attachment: NSTextAttachment(
                image: PortfolioGlyphs.symbol(symbol, pointSize: 13, weight: .bold, color: color) ?? UIImage()))
            text.append(NSAttributedString(string: "  " + check.text, attributes: [.foregroundColor: tokens.textPrimary]))
            label.attributedText = text
            label.accessibilityLabel = check.text + ", " + (check.isMet ? PortfolioStrings.text("Done")
                                                                        : PortfolioStrings.text("Not yet"))
            polkaswapStack.addArrangedSubview(label)
        }
        let action = model.polkaswap.action
        let button = PortfolioPrimaryButton(title: action.title, style: action.kind == .swap ? .swap : .primary,
                                            showsFlower: action.kind == .swap) { [weak self] in
            guard let self else { return }
            if action.kind == .swap {
                self.onPolkaswap?(self.model?.polkaswap.holdingId)
            } else {
                self.onAction?(.receiveOnSora2, self.selectedHoldingId ?? "")
            }
        }
        polkaswapStack.setCustomSpacing(16, after: polkaswapStack.arrangedSubviews.last!)
        polkaswapStack.addArrangedSubview(button)
        if let reason = action.reason {
            polkaswapStack.addArrangedSubview(reasonLabel(reason))
        }
    }
}

extension PortfolioDetailViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let model else { return }
        let title = scrollView.contentOffset.y > 220 ? PortfolioStrings.format("%@ · where it lives", model.symbol) : nil
        if navigationItem.title != title { navigationItem.title = title }
        parallax?.setHeroVisible(scrollView.contentOffset.y < 240)
    }
}

extension PortfolioDetailViewController: SoramitsuObserver {
    func styleDidChange(options: UpdateOptions) {
        guard options.contains(.palette) else { return }
        orbit.applyTheme()
        reload()
    }
}

/// A holding row in Where it lives.
final class PortfolioDetailHoldingRow: UIControl {
    var onTap: (() -> Void)?
    private let separator = UIView()
    private let badge = PortfolioTokenIconView(size: 36)
    private let title = UILabel.portfolio(FontType.textBoldM, .body, maximum: 30)
    private let dot = UIView()
    private let subtitle = UILabel.portfolio(FontType.textS, .subheadline, color: PortfolioTheme.textSecondary, maximum: 26)
    private let tagView = PortfolioTagView()
    private let value = UILabel.portfolio(FontType.amountM, .body, maximum: 30)
    private let amount = UILabel.portfolio(FontType.amountS, .subheadline, color: PortfolioTheme.textSecondary, maximum: 26)

    override init(frame: CGRect) {
        super.init(frame: frame)
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)
        dot.layer.cornerRadius = 4
        dot.translatesAutoresizingMaskIntoConstraints = false
        let titleLine = UIStackView(arrangedSubviews: [title, tagView])
        titleLine.spacing = 6
        titleLine.alignment = .center
        // The tag and the fiat value never truncate; the amount scales down, then the names give way.
        tagView.setContentCompressionResistancePriority(.required, for: .horizontal)
        value.setContentCompressionResistancePriority(.required, for: .horizontal)
        title.setContentCompressionResistancePriority(.defaultHigh + 1, for: .horizontal)
        subtitle.setContentCompressionResistancePriority(.defaultHigh - 1, for: .horizontal)
        amount.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        let subtitleLine = UIStackView(arrangedSubviews: [dot, subtitle])
        subtitleLine.spacing = 6
        subtitleLine.alignment = .center
        let left = UIStackView(arrangedSubviews: [titleLine, subtitleLine])
        left.axis = .vertical
        left.spacing = 3
        left.alignment = .leading
        let right = UIStackView(arrangedSubviews: [value, amount])
        right.axis = .vertical
        right.spacing = 3
        right.alignment = .trailing
        value.textAlignment = .right
        amount.textAlignment = .right
        amount.adjustsFontSizeToFitWidth = true
        amount.minimumScaleFactor = 0.75
        let main = UIStackView(arrangedSubviews: [badge, left, UIView(), right])
        main.spacing = 12
        main.alignment = .center
        main.isUserInteractionEnabled = false
        main.translatesAutoresizingMaskIntoConstraints = false
        addSubview(main)
        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: topAnchor),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 64),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),
            main.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            main.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            main.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            main.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 68)
        ])
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(_ holding: PortfolioDetailModel.Holding, showsSeparator: Bool) {
        let tokens = PortfolioTheme.tokens
        separator.backgroundColor = tokens.hairline
        separator.isHidden = !showsSeparator
        badge.configure(.network(holding.network))
        title.text = PortfolioStrings.networkName(holding.network)
        title.textColor = tokens.textPrimary
        subtitle.text = holding.walletName
        subtitle.textColor = tokens.textSecondary
        dot.isHidden = holding.walletSlot == nil
        dot.backgroundColor = holding.walletSlot.map(PortfolioTheme.color(for:))
        if let tag = holding.tag {
            tagView.configure(tag)
            tagView.isHidden = false
        } else {
            tagView.isHidden = true
        }
        value.text = holding.value
        value.textColor = tokens.textPrimary
        amount.text = holding.amount
        amount.textColor = tokens.textSecondary
        accessibilityLabel = holding.accessibilityLabel
        accessibilityTraits = holding.isSelected ? [.button, .selected] : .button
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.7 : 1 }
    }

    @objc private func tapped() { onTap?() }
}

/// Transferable, Locked and Total counted, with a bar: solid for transferable, striped for locked.
final class PortfolioBreakdownView: UIView {
    private let bar = PortfolioBreakdownBar()
    private let rows = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 16
        layer.cornerCurve = .continuous
        rows.axis = .vertical
        rows.spacing = 10
        let stack = UIStackView(arrangedSubviews: [bar, rows])
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            bar.heightAnchor.constraint(equalToConstant: 8),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(_ panel: PortfolioDetailModel.Panel) {
        let tokens = PortfolioTheme.tokens
        backgroundColor = PortfolioTheme.isDark ? UIColor.black.withAlphaComponent(0.28) : tokens.layer1
        bar.fraction = CGFloat(panel.transferableFraction)
        rows.arrangedSubviews.forEach { $0.removeFromSuperview() }
        rows.addArrangedSubview(row(swatch: .solid, title: PortfolioStrings.transferable, value: panel.transferable))
        rows.addArrangedSubview(row(swatch: .striped, title: PortfolioStrings.locked, value: panel.locked))
        rows.addArrangedSubview(row(swatch: nil, title: PortfolioStrings.totalCounted, value: panel.total))
    }

    private enum Swatch {
        case solid
        case striped
    }

    private func row(swatch: Swatch?, title: String, value: String) -> UIView {
        let tokens = PortfolioTheme.tokens
        let label = UILabel.portfolio(FontType.textM, .body, color: tokens.textSecondary, maximum: 28)
        label.text = title
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        let amount = UILabel.portfolio(FontType.amountM, .body, maximum: 28)
        amount.text = value
        amount.textAlignment = .right
        amount.adjustsFontSizeToFitWidth = true
        amount.minimumScaleFactor = 0.7
        var views: [UIView] = []
        if let swatch {
            let image = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12)).image { _ in
                let rect = CGRect(x: 0, y: 0, width: 12, height: 12)
                let path = UIBezierPath(roundedRect: rect, cornerRadius: 3)
                switch swatch {
                case .solid:
                    PortfolioTheme.flowerPink.setFill()
                    path.fill()
                case .striped:
                    PortfolioBreakdownBar.lockedFill.setFill()
                    path.fill()
                    path.addClip()
                    PortfolioBreakdownBar.lockedStripe.setStroke()
                    for offset in stride(from: -12, through: 12, by: 4) {
                        let line = UIBezierPath()
                        line.move(to: CGPoint(x: CGFloat(offset), y: 12))
                        line.addLine(to: CGPoint(x: CGFloat(offset) + 12, y: 0))
                        line.lineWidth = 1.5
                        line.stroke()
                    }
                }
            }
            let swatchView = UIImageView(image: image)
            swatchView.setContentHuggingPriority(.required, for: .horizontal)
            views.append(swatchView)
        }
        views += [label, UIView(), amount]
        let line = UIStackView(arrangedSubviews: views)
        line.spacing = 10
        line.alignment = .center
        line.isAccessibilityElement = true
        line.accessibilityLabel = "\(title), \(value)"
        return line
    }
}

/// The breakdown's bar: a solid transferable part, a gap, then the locked part in stripes.
final class PortfolioBreakdownBar: UIView {
    static let lockedFill = UIColor(portfolioHex: 0x8B5CFF, alpha: 0.35)
    static let lockedStripe = UIColor(portfolioHex: 0x8B5CFF)

    var fraction: CGFloat = 1 {
        didSet { setNeedsLayout() }
    }

    private let solid = UIView()
    private let locked = UIView()
    private let stripes = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = false
        layer.cornerRadius = 4
        layer.cornerCurve = .continuous
        clipsToBounds = true
        addSubview(solid)
        addSubview(locked)
        locked.clipsToBounds = true
        locked.layer.addSublayer(stripes)
        solid.backgroundColor = PortfolioTheme.flowerPink
        locked.backgroundColor = Self.lockedFill
        stripes.strokeColor = Self.lockedStripe.cgColor
        stripes.lineWidth = 2
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let share = min(1, max(0, fraction))
        let width = bounds.width
        let solidWidth = (width * share).rounded()
        let gap: CGFloat = share > 0 && share < 1 ? 2 : 0
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        solid.frame = CGRect(x: 0, y: 0, width: solidWidth, height: bounds.height)
        locked.frame = CGRect(x: solidWidth + gap, y: 0, width: max(0, width - solidWidth - gap), height: bounds.height)
        let path = UIBezierPath()
        var x: CGFloat = -bounds.height
        while x < locked.bounds.width + bounds.height {
            path.move(to: CGPoint(x: x, y: bounds.height))
            path.addLine(to: CGPoint(x: x + bounds.height, y: 0))
            x += 5
        }
        stripes.frame = locked.bounds
        stripes.path = path.cgPath
        CATransaction.commit()
    }
}

/// What stands between the holding and a swap.
final class PortfolioRouteCard: UIView {
    private let chips = UIStackView()
    private let text = UILabel.portfolio(FontType.paragraphS, .subheadline, lines: 0, maximum: 28)

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 16
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        chips.axis = .horizontal
        chips.spacing = 8
        chips.alignment = .center
        let stack = UIStackView(arrangedSubviews: [chips, text])
        stack.axis = .vertical
        stack.spacing = 10
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14)
        ])
        isAccessibilityElement = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(_ route: PortfolioDetailModel.Route) {
        let tokens = PortfolioTheme.tokens
        chips.arrangedSubviews.forEach { $0.removeFromSuperview() }
        chips.addArrangedSubview(networkChip(route.network))
        switch route.style {
        case .ready:
            chips.addArrangedSubview(arrow(dashed: false))
            chips.addArrangedSubview(polkaswapChip(dimmed: false))
            backgroundColor = tokens.polkaswapContainer.withAlphaComponent(PortfolioTheme.isDark ? 0.6 : 1)
            layer.borderColor = PortfolioTheme.flowerPink.withAlphaComponent(0.35).cgColor
        case .noRoute:
            chips.addArrangedSubview(arrow(dashed: true))
            chips.addArrangedSubview(polkaswapChip(dimmed: true))
            backgroundColor = .clear
            layer.borderColor = tokens.hairline.cgColor
        case .notListed:
            backgroundColor = .clear
            layer.borderColor = tokens.hairline.cgColor
        case .test:
            let tag = PortfolioTagView()
            tag.configure(.network(.testnet))
            chips.addArrangedSubview(tag)
            backgroundColor = tokens.warningContainer.withAlphaComponent(PortfolioTheme.isDark ? 0.6 : 1)
            layer.borderColor = tokens.warning.withAlphaComponent(0.3).cgColor
        }
        text.text = route.text
        text.textColor = tokens.textPrimary
        accessibilityLabel = route.text
    }

    private func networkChip(_ network: PortfolioNetwork) -> UIView {
        chip(icon: PortfolioBadges.network(network, size: 22), title: PortfolioStrings.networkName(network), dimmed: false)
    }

    private func polkaswapChip(dimmed: Bool) -> UIView {
        chip(icon: PortfolioGlyphs.flowerImage(size: 18), title: "Polkaswap", dimmed: dimmed)
    }

    private func chip(icon: UIImage?, title: String, dimmed: Bool) -> UIView {
        let tokens = PortfolioTheme.tokens
        let image = UIImageView(image: icon)
        image.contentMode = .center
        let label = UILabel.portfolio(FontType.textBoldS, .subheadline, maximum: 24)
        label.text = title
        label.textColor = tokens.textPrimary
        let stack = UIStackView(arrangedSubviews: [image, label])
        stack.spacing = 6
        stack.alignment = .center
        stack.isLayoutMarginsRelativeArrangement = true
        stack.insetsLayoutMarginsFromSafeArea = false
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 5, leading: 6, bottom: 5, trailing: 12)
        stack.backgroundColor = PortfolioTheme.isDark ? UIColor.white.withAlphaComponent(0.07) : tokens.surface
        stack.layer.cornerRadius = 16
        stack.alpha = dimmed ? 0.45 : 1
        return stack
    }

    private func arrow(dashed: Bool) -> UIView {
        let view = UIImageView(image: PortfolioGlyphs.symbol(dashed ? "arrow.right" : "arrow.right", pointSize: 12,
                                                             color: PortfolioTheme.textSecondary))
        view.alpha = dashed ? 0.45 : 1
        return view
    }
}

/// An outlined capsule action with an optional unavailable state.
final class PortfolioSecondaryButton: UIControl {
    private let label = UILabel.portfolio(FontType.buttonM, .headline, maximum: 26)
    private let glyph = UIImageView()
    private let handler: () -> Void

    init(action: PortfolioDetailModel.Action, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(frame: .zero)
        let tokens = PortfolioTheme.tokens
        layer.borderWidth = 1
        layer.borderColor = (PortfolioTheme.isDark ? UIColor.white.withAlphaComponent(0.18) : tokens.hairline).cgColor
        layer.cornerCurve = .continuous
        backgroundColor = PortfolioTheme.isDark ? UIColor.white.withAlphaComponent(0.04) : tokens.surface
        switch action.kind {
        case .send: glyph.image = PortfolioGlyphs.symbol("arrow.up.right", pointSize: 15, color: tokens.textPrimary)
        case .move: glyph.image = PortfolioGlyphs.moveImage(size: 20, color: tokens.textPrimary)
        case .swap: glyph.image = PortfolioGlyphs.flowerImage(size: 18)
        case .receiveOnSora2: glyph.image = PortfolioGlyphs.symbol("arrow.down.left", pointSize: 15, color: tokens.textPrimary)
        }
        label.text = action.title
        label.textColor = tokens.textPrimary
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.75
        let stack = UIStackView(arrangedSubviews: [glyph, label])
        stack.spacing = 8
        stack.alignment = .center
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 48),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 12),
            stack.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 10)
        ])
        isEnabled = action.isEnabled
        alpha = action.isEnabled ? 1 : 0.45
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
        isAccessibilityElement = true
        accessibilityLabel = action.title
        accessibilityTraits = action.isEnabled ? .button : [.button, .notEnabled]
        accessibilityHint = action.reason
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.7 : (isEnabled ? 1 : 0.45) }
    }

    @objc private func tapped() { handler() }
}
