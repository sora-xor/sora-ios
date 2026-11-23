// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

import SoraUIKit
import UIKit

// MARK: - Lens control

/// Tokens · Networks · Wallets.
final class PortfolioLensItem: NSObject {
    var lenses: [PortfolioLens] = [.tokens, .networks, .wallets] {
        didSet { if lenses != oldValue { onChange?() } }
    }

    var selected: PortfolioLens = .tokens {
        didSet { if selected != oldValue { onChange?() } }
    }

    var onSelect: ((PortfolioLens) -> Void)?
    fileprivate var onChange: (() -> Void)?
}

extension PortfolioLensItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { PortfolioLensCell.self }
    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }
    var clipsToBounds: Bool { false }

    func itemHeight(forWidth width: CGFloat, context: SoramitsuTableViewContext?) -> CGFloat {
        UITableView.automaticDimension
    }
}

final class PortfolioLensCell: SoramitsuTableViewCell, SoramitsuTableViewCellProtocol {
    private weak var item: PortfolioLensItem?
    private let control = PortfolioSegmentedControl()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
        control.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(control)
        NSLayoutConstraint.activate([
            control.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            control.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            control.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            control.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
        control.onSelect = { [weak self] index in
            guard let self, let item = self.item, item.lenses.indices.contains(index) else { return }
            item.onSelect?(item.lenses[index])
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? PortfolioLensItem else { return }
        self.item?.onChange = nil
        self.item = item
        item.onChange = { [weak self] in self?.reload(animated: true) }
        reload(animated: false)
    }

    private func reload(animated: Bool) {
        guard let item else { return }
        control.configure(titles: item.lenses.map(PortfolioStrings.lensTitle),
                          selected: item.lenses.firstIndex(of: item.selected) ?? 0, animated: animated)
    }
}

/// A capsule segmented control in the Neon style; each segment is a 44 pt button.
final class PortfolioSegmentedControl: UIView {
    var onSelect: ((Int) -> Void)?

    private let background = PortfolioPressedWell()
    private let pill = GlassView()
    private let stack = UIStackView()
    private var buttons: [UIButton] = []
    private var selectedIndex = 0
    private var pillLeading: NSLayoutConstraint?
    private var pillWidth: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        background.isUserInteractionEnabled = false
        pill.shape = .capsule
        pill.elevation = 6
        pill.isUserInteractionEnabled = false
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        [background, pill, stack].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: leadingAnchor),
            background.trailingAnchor.constraint(equalTo: trailingAnchor),
            background.topAnchor.constraint(equalTo: topAnchor),
            background.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            stack.heightAnchor.constraint(greaterThanOrEqualToConstant: 42),
            pill.topAnchor.constraint(equalTo: stack.topAnchor),
            pill.bottomAnchor.constraint(equalTo: stack.bottomAnchor)
        ])
        accessibilityTraits = .tabBar
        SoramitsuUI.updates.addObserver(self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(titles: [String], selected: Int, animated: Bool) {
        if buttons.map({ $0.title(for: .normal) ?? "" }) != titles {
            buttons.forEach { $0.removeFromSuperview() }
            buttons = titles.enumerated().map { index, title in
                let button = UIButton(type: .custom)
                button.setTitle(title, for: .normal)
                button.titleLabel?.font = PortfolioTheme.font(FontType.textBoldS, .subheadline, maximum: 24)
                button.titleLabel?.adjustsFontForContentSizeCategory = true
                button.titleLabel?.adjustsFontSizeToFitWidth = true
                button.titleLabel?.minimumScaleFactor = 0.7
                button.tag = index
                button.accessibilityTraits = .button
                button.addTarget(self, action: #selector(tapped(_:)), for: .touchUpInside)
                stack.addArrangedSubview(button)
                return button
            }
        }
        selectedIndex = min(max(0, selected), max(0, buttons.count - 1))
        applyColors()
        pillLeading?.isActive = false
        pillWidth?.isActive = false
        guard buttons.indices.contains(selectedIndex) else { return }
        let target = buttons[selectedIndex]
        pillLeading = pill.leadingAnchor.constraint(equalTo: target.leadingAnchor)
        pillWidth = pill.widthAnchor.constraint(equalTo: target.widthAnchor)
        pillLeading?.isActive = true
        pillWidth?.isActive = true
        if animated && !UIAccessibility.isReduceMotionEnabled {
            UIView.animate(withDuration: NeonMotion.base, delay: 0, usingSpringWithDamping: 0.9,
                           initialSpringVelocity: 0) { self.layoutIfNeeded() }
        } else {
            layoutIfNeeded()
        }
    }

    private func applyColors() {
        let tokens = PortfolioTheme.tokens
        for (index, button) in buttons.enumerated() {
            let selected = index == selectedIndex
            button.setTitleColor(selected ? tokens.textPrimary : tokens.textSecondary, for: .normal)
            button.accessibilityTraits = selected ? [.button, .selected] : .button
        }
    }

    @objc private func tapped(_ sender: UIButton) {
        guard sender.tag != selectedIndex else { return }
        onSelect?(sender.tag)
    }
}

extension PortfolioSegmentedControl: SoramitsuObserver {
    func styleDidChange(options: UpdateOptions) {
        if options.contains(.palette) { applyColors() }
    }
}

// MARK: - List

final class PortfolioListItem: NSObject {
    var model: PortfolioListModel? {
        didSet { if model != oldValue { onModelChange?(oldValue) } }
    }

    var onRow: ((PortfolioRow) -> Void)?
    var onChild: ((PortfolioChildRow) -> Void)?
    var onLink: ((PortfolioRow) -> Void)?
    /// Custom accessibility actions on a token row.
    var onRowAction: ((PortfolioRow, PortfolioQuickAction?) -> Void)?
    /// Called after the cell changed its height so the table can settle.
    var onHeightChange: (() -> Void)?

    fileprivate var onModelChange: ((PortfolioListModel?) -> Void)?
}

extension PortfolioListItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { PortfolioListCell.self }
    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }
    var clipsToBounds: Bool { false }

    func itemHeight(forWidth width: CGFloat, context: SoramitsuTableViewContext?) -> CGFloat {
        UITableView.automaticDimension
    }
}

final class PortfolioListCell: SoramitsuTableViewCell, SoramitsuTableViewCellProtocol {
    private weak var item: PortfolioListItem?
    private let card = GlassView()
    private let stack = UIStackView()
    private let emptyLabel = UILabel.portfolio(FontType.paragraphS, .subheadline, color: PortfolioTheme.textSecondary,
                                               lines: 0)
    /// "Assets", the card's title, styled like "XOR on other networks" below it.
    private let titleLabel = UILabel.portfolio(FontType.headline2, .title3, maximum: 32)
    private var hasEntered = false
    private let header = UIView()
    private let emptyView = UIView()
    /// While balances are read: rows drawn as they will stand, with light passing over them, not a sentence.
    private let shimmer = PortfolioShimmerRowsView()
    private var rowViews: [String: PortfolioRowView] = [:]
    private var wellViews: [String: PortfolioWellView] = [:]

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
        card.shape = .rounded(26)
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.contentView.addSubview(stack)
        emptyLabel.textAlignment = .center
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.8
        titleLabel.accessibilityTraits = .header
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(titleLabel)
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyView.addSubview(emptyLabel)
        // Rows come and go inside the cell (balances read, a lens changed) and are laid out at once, while the
        // cell still has the height the table gave it for the old rows; the table measures it again right after
        // (`onHeightChange`). Just under required, the card's bottom gives way for that moment, instead of Auto
        // Layout breaking rows' own constraints (116 of them on every home build, at every size).
        let cardBottom = card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        cardBottom.priority = UILayoutPriority(999)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
            titleLabel.topAnchor.constraint(equalTo: header.topAnchor, constant: 12),
            titleLabel.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -2),
            emptyLabel.leadingAnchor.constraint(equalTo: emptyView.leadingAnchor, constant: 20),
            emptyLabel.trailingAnchor.constraint(equalTo: emptyView.trailingAnchor, constant: -20),
            emptyLabel.topAnchor.constraint(equalTo: emptyView.topAnchor, constant: 22),
            emptyLabel.bottomAnchor.constraint(equalTo: emptyView.bottomAnchor, constant: -22),
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            cardBottom,
            stack.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 6),
            stack.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -6)
        ])
        SoramitsuUI.updates.addObserver(self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? PortfolioListItem else { return }
        self.item?.onModelChange = nil
        self.item = item
        item.onModelChange = { [weak self] old in self?.reload(previous: old) }
        reload(previous: nil)
    }

    private func reload(previous: PortfolioListModel?) {
        guard let item, let model = item.model else { return }
        let animate = previous != nil && previous?.lens == model.lens &&
            previous?.rows.map(\.key) == model.rows.map(\.key) && !UIAccessibility.isReduceMotionEnabled
        let changes = {
            self.rebuild(model)
            self.layoutIfNeeded()
        }
        if animate {
            UIView.animate(withDuration: NeonMotion.base, delay: 0, options: [.curveEaseInOut]) {
                changes()
            }
        } else {
            UIView.performWithoutAnimation(changes)
        }
        item.onHeightChange?()
    }

    /// Rows stay the same views across updates and are named in `accessibilityElements`:
    /// `PortfolioOtherNetworksCell.reload()` says why.
    private func rebuild(_ model: PortfolioListModel) {
        card.apply()
        titleLabel.attributedText = NSAttributedString(string: PortfolioStrings.assets, attributes: [
            .font: titleLabel.font as Any, .foregroundColor: PortfolioTheme.textPrimary
        ])
        var availableRows = rowViews
        var availableWells = wellViews
        rowViews = [:]
        wellViews = [:]
        var views: [UIView] = [header]
        var elements: [UIView] = [titleLabel]
        if let empty = model.emptyText, empty == PortfolioStrings.readingBalances {
            shimmer.accessibilityLabel = empty
            views.append(shimmer)
            elements.append(shimmer)
        } else if let empty = model.emptyText {
            emptyLabel.text = empty
            emptyLabel.textColor = PortfolioTheme.textSecondary
            views.append(emptyView)
            elements.append(emptyLabel)
        } else {
            let entering = !hasEntered && !model.rows.isEmpty && window != nil && FxPolicy.current.litMotion
            if entering { hasEntered = true }
            for (index, row) in model.rows.enumerated() {
                let rowView = availableRows.removeValue(forKey: row.key) ?? PortfolioRowView()
                rowView.configure(row, showsSeparator: index > 0)
                rowView.onTap = { [weak self] in self?.item?.onRow?(row) }
                rowView.onCustomAction = { [weak self] action in self?.item?.onRowAction?(row, action) }
                rowViews[row.key] = rowView
                views.append(rowView)
                elements.append(rowView)
                if entering, index < 8 { LitMotion.rise(rowView, by: 10, after: 0.04 * Double(index)) }
                if row.isExpanded {
                    let well = availableWells.removeValue(forKey: row.key) ?? PortfolioWellView()
                    well.configure(row.children, link: row.link)
                    well.onChild = { [weak self] child in self?.item?.onChild?(child) }
                    well.onLink = { [weak self] in self?.item?.onLink?(row) }
                    wellViews[row.key] = well
                    views.append(well)
                    elements.append(contentsOf: well.elements)
                }
            }
        }
        stack.portfolioArrange(views)
        accessibilityElements = elements
    }
}

extension UIStackView {
    /// Makes `views` the arranged subviews, in this order, and leaves alone those already in place.
    func portfolioArrange(_ views: [UIView]) {
        arrangedSubviews.filter { !views.contains($0) }.forEach { $0.removeFromSuperview() }
        for (index, view) in views.enumerated() where index >= arrangedSubviews.count || arrangedSubviews[index] !== view {
            insertArrangedSubview(view, at: index)
        }
    }
}

extension PortfolioListCell: SoramitsuObserver {
    func styleDidChange(options: UpdateOptions) {
        guard options.contains(.palette), let model = item?.model else { return }
        rebuild(model)
    }
}

/// One lens row: icon, title with change, subtitle with wallet dots, value over detail, chevron.
final class PortfolioRowView: UIControl {
    var onTap: (() -> Void)?
    var onCustomAction: ((PortfolioQuickAction?) -> Void)?

    private let separator = LitEngravedLine()
    private let icon = PortfolioTokenIconView(size: 40)
    private let title = UILabel.portfolio(FontType.textBoldM, .body, maximum: 30)
    private let change = UILabel.portfolio(FontType.textBoldXS, .caption1, maximum: 20)
    private let tagView = PortfolioTagView()
    private let subtitle = UILabel.portfolio(FontType.textS, .subheadline, color: PortfolioTheme.textSecondary,
                                             maximum: 26)
    private let dots = PortfolioDotsView()
    private let value = UILabel.portfolio(FontType.amountM, .body, maximum: 30)
    private let detail = UILabel.portfolio(FontType.amountS, .subheadline, color: PortfolioTheme.textSecondary,
                                           maximum: 26)
    private let chevron = UIImageView()
    private let leftStack = UIStackView()
    private let rightStack = UIStackView()
    private let main = UIStackView()
    private var row: PortfolioRow?

    override init(frame: CGRect) {
        super.init(frame: frame)
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)

        let titleLine = UIStackView(arrangedSubviews: [title, change, tagView])
        titleLine.axis = .horizontal
        titleLine.spacing = 6
        titleLine.alignment = .center
        let subtitleLine = UIStackView(arrangedSubviews: [subtitle, dots])
        subtitleLine.axis = .horizontal
        subtitleLine.spacing = 8
        subtitleLine.alignment = .center
        leftStack.axis = .vertical
        leftStack.spacing = 3
        leftStack.alignment = .leading
        leftStack.addArrangedSubview(titleLine)
        leftStack.addArrangedSubview(subtitleLine)
        rightStack.axis = .vertical
        rightStack.spacing = 3
        rightStack.alignment = .trailing
        rightStack.addArrangedSubview(value)
        rightStack.addArrangedSubview(detail)
        value.textAlignment = .right
        detail.textAlignment = .right
        title.setContentCompressionResistancePriority(.required, for: .horizontal)
        value.setContentCompressionResistancePriority(.required, for: .horizontal)
        // On narrow phones the right-hand detail scales down before the subtitle ("8 tokens · 95%") does.
        subtitle.setContentCompressionResistancePriority(.defaultHigh + 1, for: .horizontal)
        subtitle.adjustsFontSizeToFitWidth = true
        subtitle.minimumScaleFactor = 0.85
        // A long token name beside a long value takes a second line on a narrow phone instead of being
        // cut ("SORA Validator To…" on an iPhone SE and on 393-point phones).
        subtitle.numberOfLines = 2
        detail.setContentCompressionResistancePriority(.defaultHigh - 1, for: .horizontal)
        detail.adjustsFontSizeToFitWidth = true
        detail.minimumScaleFactor = 0.75
        chevron.contentMode = .center
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        main.axis = .horizontal
        main.spacing = 12
        main.alignment = .center
        main.isUserInteractionEnabled = false
        [icon, leftStack, UIView(), rightStack, chevron].forEach { main.addArrangedSubview($0) }
        main.translatesAutoresizingMaskIntoConstraints = false
        addSubview(main)
        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: topAnchor),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 70),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            separator.heightAnchor.constraint(equalToConstant: 2),
            main.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            main.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            main.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            main.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 72),
            chevron.widthAnchor.constraint(equalToConstant: 18)
        ])
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(_ row: PortfolioRow, showsSeparator: Bool) {
        let tokens = PortfolioTheme.tokens
        defer { self.row = row }
        separator.isHidden = !showsSeparator
        icon.configure(row.icon)
        title.text = row.title
        title.textColor = tokens.textPrimary
        change.text = row.change
        change.isHidden = row.change == nil
        change.textColor = row.direction == .down ? tokens.error : tokens.success
        if let tag = row.tag {
            tagView.configure(tag)
            tagView.isHidden = false
        } else {
            tagView.isHidden = true
        }
        subtitle.text = row.subtitle
        subtitle.textColor = tokens.textSecondary
        dots.configure(row.walletDots)
        value.text = row.value
        value.textColor = tokens.textPrimary
        detail.text = row.detail
        detail.textColor = tokens.textSecondary
        chevron.isHidden = !row.isExpandable
        chevron.image = PortfolioGlyphs.symbol("chevron.down", pointSize: 13, color: tokens.textSecondary)
        // The chevron turns over as the row opens.
        let turned: CGAffineTransform = row.isExpanded ? CGAffineTransform(rotationAngle: .pi) : .identity
        if self.row?.key == row.key, window != nil, LitMotion.allowed {
            UIView.animate(withDuration: 0.34, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0) {
                self.chevron.transform = turned
            }
        } else {
            chevron.transform = turned
        }

        let large = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        main.axis = large ? .vertical : .horizontal
        main.alignment = large ? .leading : .center
        rightStack.alignment = large ? .leading : .trailing

        accessibilityLabel = row.accessibilityLabel
        if row.isExpandable {
            accessibilityValue = row.isExpanded ? PortfolioStrings.text("Expanded") : PortfolioStrings.text("Collapsed")
        } else {
            accessibilityValue = nil
        }
        if row.kind == .token {
            accessibilityCustomActions = [
                UIAccessibilityCustomAction(name: PortfolioStrings.whereItLives) { [weak self] _ in
                    self?.onCustomAction?(nil); return true
                },
                UIAccessibilityCustomAction(name: PortfolioStrings.move) { [weak self] _ in
                    self?.onCustomAction?(.move); return true
                },
                UIAccessibilityCustomAction(name: PortfolioStrings.swap) { [weak self] _ in
                    self?.onCustomAction?(.swap); return true
                }
            ]
        } else {
            accessibilityCustomActions = nil
        }
    }

    override var isHighlighted: Bool {
        didSet {
            guard isHighlighted != oldValue else { return }
            LitMotion.press(icon, pressed: isHighlighted, scale: 0.9)
            UIView.animate(withDuration: isHighlighted ? 0.08 : 0.28, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.backgroundColor = self.isHighlighted ? PortfolioTheme.tokens.glassFillPressed.withAlphaComponent(0.55) : .clear
            }
        }
    }

    @objc private func tapped() { onTap?() }
}

/// The expanded well under a row: holdings or largest tokens, and an optional link.
final class PortfolioWellView: UIView {
    var onChild: ((PortfolioChildRow) -> Void)?
    var onLink: (() -> Void)?
    /// The well's rows and link, in reading order, for the cell's `accessibilityElements`.
    private(set) var elements: [UIView] = []

    private let stack = UIStackView()
    private let well = PortfolioPressedWell()
    private let inner = UIStackView()
    private let linkButton = UIButton(type: .system)
    private var childViews: [String: PortfolioChildRowView] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        inner.axis = .vertical
        inner.translatesAutoresizingMaskIntoConstraints = false
        well.addSubview(inner)
        stack.addArrangedSubview(well)
        linkButton.contentHorizontalAlignment = .leading
        linkButton.addTarget(self, action: #selector(linkTapped), for: .touchUpInside)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            inner.leadingAnchor.constraint(equalTo: well.leadingAnchor),
            inner.trailingAnchor.constraint(equalTo: well.trailingAnchor),
            inner.topAnchor.constraint(equalTo: well.topAnchor, constant: 4),
            inner.bottomAnchor.constraint(equalTo: well.bottomAnchor, constant: -4)
        ])
        layer.cornerCurve = .continuous
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(_ children: [PortfolioChildRow], link: String?) {
        let tokens = PortfolioTheme.tokens
        var available = childViews
        childViews = [:]
        var views: [UIView] = children.enumerated().map { index, child in
            let view = available.removeValue(forKey: child.key) ?? PortfolioChildRowView()
            view.configure(child, showsSeparator: index > 0)
            view.onTap = { [weak self] in self?.onChild?(child) }
            childViews[child.key] = view
            return view
        }
        if let link {
            var configuration = UIButton.Configuration.plain()
            configuration.attributedTitle = AttributedString(link, attributes: AttributeContainer([
                .font: PortfolioTheme.font(FontType.textBoldS, .subheadline, maximum: 24),
                .foregroundColor: tokens.link
            ]))
            configuration.image = PortfolioGlyphs.symbol("arrow.right", pointSize: 12, color: tokens.link)
            configuration.imagePlacement = .trailing
            configuration.imagePadding = 6
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
            linkButton.configuration = configuration
            views.append(linkButton)
        }
        inner.portfolioArrange(views)
        elements = views
    }

    @objc private func linkTapped() { onLink?() }
}

/// A recess pressed into the plate, holding what a row opens to.
final class PortfolioPressedWell: UIView {
    private let well = LitWellLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        well.cornerRadiusValue = 18
        well.depth = 3
        layer.addSublayer(well)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setFloor(_ floor: UIColor?, depth: CGFloat = 3, radius: CGFloat = 18) {
        well.floorColor = floor
        well.depth = depth
        well.cornerRadiusValue = radius
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        well.place(in: bounds)
    }
}

/// A holding (network, wallet) or a token inside an expanded row.
final class PortfolioChildRowView: UIControl {
    var onTap: (() -> Void)?

    private let separator = LitEngravedLine()
    private let icon = PortfolioTokenIconView(size: 30)
    private let title = UILabel.portfolio(FontType.textBoldS, .subheadline, maximum: 26)
    private let walletDot = UIView()
    private let subtitle = UILabel.portfolio(FontType.textXS, .caption1, color: PortfolioTheme.textSecondary, maximum: 22)
    private let tagView = PortfolioTagView()
    private let value = UILabel.portfolio(FontType.amountS, .subheadline, maximum: 26)
    private let detail = UILabel.portfolio(FontType.textXS, .caption1, color: PortfolioTheme.textSecondary, maximum: 22)
    private let main = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)
        walletDot.layer.cornerRadius = 3.5
        walletDot.translatesAutoresizingMaskIntoConstraints = false
        let subtitleLine = UIStackView(arrangedSubviews: [walletDot, subtitle])
        subtitleLine.axis = .horizontal
        subtitleLine.spacing = 5
        subtitleLine.alignment = .center
        let titleLine = UIStackView(arrangedSubviews: [title, tagView])
        titleLine.axis = .horizontal
        titleLine.spacing = 6
        titleLine.alignment = .center
        let left = UIStackView(arrangedSubviews: [titleLine, subtitleLine])
        left.axis = .vertical
        left.spacing = 2
        left.alignment = .leading
        let right = UIStackView(arrangedSubviews: [value, detail])
        right.axis = .vertical
        right.spacing = 2
        right.alignment = .trailing
        value.textAlignment = .right
        detail.textAlignment = .right
        detail.adjustsFontSizeToFitWidth = true
        detail.minimumScaleFactor = 0.75
        // The symbol or network, its tag and the fiat value stay whole; the amount scales down first.
        [title, value].forEach { $0.setContentCompressionResistancePriority(.required, for: .horizontal) }
        detail.setContentCompressionResistancePriority(.defaultHigh - 1, for: .horizontal)
        subtitle.setContentCompressionResistancePriority(.defaultHigh - 2, for: .horizontal)
        main.axis = .horizontal
        main.spacing = 10
        main.alignment = .center
        main.isUserInteractionEnabled = false
        [icon, left, UIView(), right].forEach { main.addArrangedSubview($0) }
        main.translatesAutoresizingMaskIntoConstraints = false
        addSubview(main)
        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: topAnchor),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 54),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            separator.heightAnchor.constraint(equalToConstant: 2),
            walletDot.widthAnchor.constraint(equalToConstant: 7),
            walletDot.heightAnchor.constraint(equalToConstant: 7),
            main.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            main.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            main.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            main.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 56)
        ])
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(_ child: PortfolioChildRow, showsSeparator: Bool) {
        let tokens = PortfolioTheme.tokens
        separator.isHidden = !showsSeparator
        icon.configure(child.icon)
        title.text = child.title
        title.textColor = tokens.textPrimary
        subtitle.text = child.subtitle
        subtitle.textColor = tokens.textSecondary
        walletDot.isHidden = child.walletSlot == nil
        walletDot.backgroundColor = child.walletSlot.map(PortfolioTheme.color(for:))
        if let tag = child.tag {
            tagView.configure(tag)
            tagView.isHidden = false
        } else {
            tagView.isHidden = true
        }
        value.text = child.value
        value.textColor = tokens.textPrimary
        detail.text = child.detail
        detail.textColor = tokens.textSecondary
        accessibilityLabel = child.accessibilityLabel
        accessibilityHint = PortfolioStrings.whereItLives
    }

    override var isHighlighted: Bool {
        didSet {
            guard isHighlighted != oldValue else { return }
            LitMotion.press(icon, pressed: isHighlighted, scale: 0.9)
        }
    }

    @objc private func tapped() { onTap?() }
}


/// Three asset rows drawn as they will stand (coin, name, amount) with a band of light passing over them.
final class PortfolioShimmerRowsView: UIView {
    private static let rowHeight: CGFloat = 64
    private let shapes = CAShapeLayer()
    private let sweep = CAGradientLayer()
    private let sweepMask = CAShapeLayer()
    private var builtWidth: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true
        accessibilityTraits = .updatesFrequently
        layer.addSublayer(shapes)
        sweep.colors = [UIColor.white.withAlphaComponent(0).cgColor, UIColor.white.withAlphaComponent(0.75).cgColor,
                        UIColor.white.withAlphaComponent(0).cgColor]
        sweep.locations = [0.38, 0.5, 0.62]
        sweep.startPoint = CGPoint(x: 0, y: 0.4)
        sweep.endPoint = CGPoint(x: 1, y: 0.6)
        sweep.mask = sweepMask
        layer.addSublayer(sweep)
        let height = heightAnchor.constraint(equalToConstant: 3 * Self.rowHeight + 8)
        height.priority = UILayoutPriority(999)
        height.isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width
        guard width > 0, width != builtWidth else { return }
        builtWidth = width
        let path = UIBezierPath()
        for row in 0..<3 {
            let y = CGFloat(row) * Self.rowHeight + 12
            path.append(UIBezierPath(ovalIn: CGRect(x: 0, y: y, width: 40, height: 40)))
            path.append(UIBezierPath(roundedRect: CGRect(x: 52, y: y + 5, width: width * 0.36, height: 13), cornerRadius: 6.5))
            path.append(UIBezierPath(roundedRect: CGRect(x: 52, y: y + 25, width: width * 0.2, height: 10), cornerRadius: 5))
            path.append(UIBezierPath(roundedRect: CGRect(x: width - 76, y: y + 5, width: 76, height: 13), cornerRadius: 6.5))
            path.append(UIBezierPath(roundedRect: CGRect(x: width - 48, y: y + 25, width: 48, height: 10), cornerRadius: 5))
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shapes.path = path.cgPath
        shapes.fillColor = PortfolioTheme.textSecondary.withAlphaComponent(0.13).cgColor
        sweep.frame = CGRect(x: -width, y: 0, width: width * 3, height: bounds.height)
        sweepMask.path = path.cgPath
        sweepMask.frame = CGRect(x: width, y: 0, width: width, height: bounds.height)
        CATransaction.commit()
        startSweep()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { startSweep() }
    }

    private func startSweep() {
        sweep.removeAnimation(forKey: "sweep")
        sweepMask.removeAnimation(forKey: "sweep")
        guard builtWidth > 0, window != nil, !UIAccessibility.isReduceMotionEnabled else { return }
        // The band moves right while its mask stays on the rows.
        let band = CABasicAnimation(keyPath: "transform.translation.x")
        band.fromValue = -builtWidth
        band.toValue = builtWidth
        band.duration = 1.5
        band.repeatCount = .infinity
        band.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        let hold = band.copy() as! CABasicAnimation
        hold.fromValue = builtWidth
        hold.toValue = -builtWidth
        sweep.add(band, forKey: "sweep")
        sweepMask.add(hold, forKey: "sweep")
    }
}
