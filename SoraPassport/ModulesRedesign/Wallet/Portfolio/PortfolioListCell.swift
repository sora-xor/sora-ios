// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

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

    private let background = GlassView()
    private let pill = UIView()
    private let stack = UIStackView()
    private var buttons: [UIButton] = []
    private var selectedIndex = 0
    private var pillLeading: NSLayoutConstraint?
    private var pillWidth: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        background.shape = .capsule
        background.isUserInteractionEnabled = false
        pill.layer.cornerCurve = .continuous
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
        background.apply()
        pill.backgroundColor = PortfolioTheme.isDark ? UIColor.white.withAlphaComponent(0.12) : tokens.surface
        pill.layer.borderWidth = 1
        pill.layer.borderColor = (PortfolioTheme.isDark ? UIColor.white.withAlphaComponent(0.16) : tokens.hairline).cgColor
        pill.layer.shadowColor = UIColor.black.cgColor
        pill.layer.shadowOpacity = PortfolioTheme.isDark ? 0 : 0.08
        pill.layer.shadowRadius = 6
        pill.layer.shadowOffset = CGSize(width: 0, height: 2)
        for (index, button) in buttons.enumerated() {
            let selected = index == selectedIndex
            button.setTitleColor(selected ? tokens.textPrimary : tokens.textSecondary, for: .normal)
            button.accessibilityTraits = selected ? [.button, .selected] : .button
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        pill.layer.cornerRadius = pill.bounds.height / 2
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

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
        card.shape = .rounded(24)
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.contentView.addSubview(stack)
        emptyLabel.textAlignment = .center
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
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

    private func rebuild(_ model: PortfolioListModel) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        card.apply()
        if let empty = model.emptyText {
            emptyLabel.text = empty
            emptyLabel.textColor = PortfolioTheme.textSecondary
            let wrapper = UIView()
            emptyLabel.translatesAutoresizingMaskIntoConstraints = false
            wrapper.addSubview(emptyLabel)
            NSLayoutConstraint.activate([
                emptyLabel.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 20),
                emptyLabel.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -20),
                emptyLabel.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 22),
                emptyLabel.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -22)
            ])
            stack.addArrangedSubview(wrapper)
            return
        }
        for (index, row) in model.rows.enumerated() {
            let rowView = PortfolioRowView()
            rowView.configure(row, showsSeparator: index > 0)
            rowView.onTap = { [weak self] in self?.item?.onRow?(row) }
            rowView.onCustomAction = { [weak self] action in self?.item?.onRowAction?(row, action) }
            stack.addArrangedSubview(rowView)
            if row.isExpanded {
                let well = PortfolioWellView()
                well.configure(row.children, link: row.link)
                well.onChild = { [weak self] child in self?.item?.onChild?(child) }
                well.onLink = { [weak self] in self?.item?.onLink?(row) }
                stack.addArrangedSubview(well)
            }
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

    private let separator = UIView()
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
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),
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
        self.row = row
        let tokens = PortfolioTheme.tokens
        separator.backgroundColor = tokens.hairline
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
        chevron.transform = row.isExpanded ? CGAffineTransform(rotationAngle: .pi) : .identity

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
        didSet { backgroundColor = isHighlighted ? PortfolioTheme.tokens.glassFillPressed : .clear }
    }

    @objc private func tapped() { onTap?() }
}

/// The expanded well under a row: holdings or largest tokens, and an optional link.
final class PortfolioWellView: UIView {
    var onChild: ((PortfolioChildRow) -> Void)?
    var onLink: (() -> Void)?

    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
        ])
        layer.cornerCurve = .continuous
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(_ children: [PortfolioChildRow], link: String?) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let tokens = PortfolioTheme.tokens
        let well = UIView()
        well.backgroundColor = PortfolioTheme.isDark ? UIColor.white.withAlphaComponent(0.035) : tokens.layer1
        well.layer.cornerRadius = 18
        well.layer.cornerCurve = .continuous
        let inner = UIStackView()
        inner.axis = .vertical
        inner.translatesAutoresizingMaskIntoConstraints = false
        well.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.leadingAnchor.constraint(equalTo: well.leadingAnchor),
            inner.trailingAnchor.constraint(equalTo: well.trailingAnchor),
            inner.topAnchor.constraint(equalTo: well.topAnchor, constant: 4),
            inner.bottomAnchor.constraint(equalTo: well.bottomAnchor, constant: -4)
        ])
        for (index, child) in children.enumerated() {
            let view = PortfolioChildRowView()
            view.configure(child, showsSeparator: index > 0)
            view.onTap = { [weak self] in self?.onChild?(child) }
            inner.addArrangedSubview(view)
        }
        if let link {
            let button = UIButton(type: .system)
            var configuration = UIButton.Configuration.plain()
            configuration.attributedTitle = AttributedString(link, attributes: AttributeContainer([
                .font: PortfolioTheme.font(FontType.textBoldS, .subheadline, maximum: 24),
                .foregroundColor: tokens.link
            ]))
            configuration.image = PortfolioGlyphs.symbol("arrow.right", pointSize: 12, color: tokens.link)
            configuration.imagePlacement = .trailing
            configuration.imagePadding = 6
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
            button.configuration = configuration
            button.contentHorizontalAlignment = .leading
            button.addTarget(self, action: #selector(linkTapped), for: .touchUpInside)
            inner.addArrangedSubview(button)
        }
        stack.addArrangedSubview(well)
    }

    @objc private func linkTapped() { onLink?() }
}

/// A holding (network, wallet) or a token inside an expanded row.
final class PortfolioChildRowView: UIControl {
    var onTap: (() -> Void)?

    private let separator = UIView()
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
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),
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
        separator.backgroundColor = tokens.hairline
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
        didSet { backgroundColor = isHighlighted ? PortfolioTheme.tokens.glassFillPressed : .clear }
    }

    @objc private func tapped() { onTap?() }
}
