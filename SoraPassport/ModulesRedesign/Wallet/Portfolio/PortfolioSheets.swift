// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import SoraUIKit
import UIKit

/// A bottom sheet in the Neon style: grabber, title, close button, scrolling content.
class PortfolioSheetViewController: UIViewController {
    let contentStack = UIStackView()
    private let scrollView = UIScrollView()
    private let titleLabel = UILabel.portfolio(FontType.headline1, .title2, lines: 0, maximum: 40)
    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.accessibilityLabel = PortfolioStrings.text("Close")
        button.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        return button
    }()
    private let header = UIStackView()

    init(title: String) {
        super.init(nibName: nil, bundle: nil)
        titleLabel.text = title
        titleLabel.accessibilityTraits = .header
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        header.addArrangedSubview(titleLabel)
        header.addArrangedSubview(closeButton)
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 12
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = false
        view.addSubview(scrollView)
        contentStack.axis = .vertical
        contentStack.spacing = 12
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor, constant: 28),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),
            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40)
        ])
        buildContent()
        applyTheme()
        SoramitsuUI.updates.addObserver(self)
    }

    /// Subclasses add their rows to `contentStack`.
    func buildContent() {}

    func applyTheme() {
        let tokens = PortfolioTheme.tokens
        view.backgroundColor = tokens.sheet
        titleLabel.textColor = tokens.textPrimary
        var configuration = UIButton.Configuration.plain()
        configuration.image = PortfolioGlyphs.symbol("xmark", pointSize: 15, color: tokens.textPrimary)
        configuration.background.backgroundColor = PortfolioTheme.isDark ? UIColor.white.withAlphaComponent(0.08)
            : tokens.surfaceVariant
        configuration.background.cornerRadius = 22
        closeButton.configuration = configuration
    }

    func rebuild() {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        buildContent()
        view.setNeedsLayout()
        view.layoutIfNeeded()
        sheetPresentationController?.animateChanges { sheetPresentationController?.invalidateDetents() }
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    /// Presents as a bottom sheet sized to its content, up to 90 % of the screen (then it scrolls).
    func present(from presenter: UIViewController) {
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.custom(identifier: .init("portfolio.fit")) { [weak self] context in
                guard let self else { return context.maximumDetentValue * 0.6 }
                self.loadViewIfNeeded()
                let width = self.view.bounds.width > 0 ? self.view.bounds.width : presenter.view.bounds.width
                return min(context.maximumDetentValue * 0.9, self.fittedHeight(width: width))
            }, .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 28
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        presenter.present(self, animated: true)
    }

    /// Header and content at this width. A custom detent excludes the bottom safe area, so it is not added.
    private func fittedHeight(width: CGFloat) -> CGFloat {
        let innerWidth = width - 40
        func fit(_ view: UIView) -> CGFloat {
            view.systemLayoutSizeFitting(CGSize(width: innerWidth, height: 0),
                                         withHorizontalFittingPriority: .required,
                                         verticalFittingPriority: .fittingSizeLevel).height
        }
        return 28 + max(44, fit(header)) + 16 + fit(contentStack) + 24
    }

    // MARK: Building blocks

    func eyebrow(_ text: String) -> UILabel {
        let label = UILabel.portfolio(FontType.eyebrow, .caption2, color: PortfolioTheme.textSecondary, maximum: 18)
        label.setEyebrow(text, color: PortfolioTheme.textSecondary)
        return label
    }

    func paragraph(_ text: String, color: UIColor? = nil) -> UILabel {
        let label = UILabel.portfolio(FontType.paragraphS, .subheadline, color: color ?? PortfolioTheme.textSecondary,
                                      lines: 0, maximum: 28)
        label.text = text
        return label
    }

    func banner(_ text: String, link: String? = nil, action: (() -> Void)? = nil) -> UIView {
        let tokens = PortfolioTheme.tokens
        let container = UIView()
        container.backgroundColor = tokens.infoContainer
        container.layer.cornerRadius = 16
        container.layer.cornerCurve = .continuous
        let accent = UIView()
        accent.backgroundColor = tokens.info
        let icon = UIImageView(image: PortfolioGlyphs.symbol("info.circle", pointSize: 16, color: tokens.info))
        icon.setContentHuggingPriority(.required, for: .horizontal)
        let label = paragraph(text, color: tokens.textPrimary)
        let texts = UIStackView(arrangedSubviews: [label])
        texts.axis = .vertical
        texts.spacing = 8
        texts.alignment = .leading
        if let link, let action {
            let button = UIButton(type: .system, primaryAction: UIAction { _ in action() })
            button.setTitle(link, for: .normal)
            button.titleLabel?.font = PortfolioTheme.font(FontType.textBoldS, .subheadline, maximum: 26)
            button.setTitleColor(tokens.link, for: .normal)
            button.contentHorizontalAlignment = .leading
            texts.addArrangedSubview(button)
        }
        let stack = UIStackView(arrangedSubviews: [icon, texts])
        stack.spacing = 10
        stack.alignment = .top
        [accent, stack].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview($0)
        }
        NSLayoutConstraint.activate([
            accent.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            accent.topAnchor.constraint(equalTo: container.topAnchor),
            accent.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            accent.widthAnchor.constraint(equalToConstant: 4),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14)
        ])
        container.clipsToBounds = true
        return container
    }

    /// A selectable card row: icon, title, subtitle, trailing value and detail.
    func optionRow(icon: PortfolioIcon, title: String, subtitle: String, value: String?, detail: String?,
                   selected: Bool, action: @escaping () -> Void) -> UIControl {
        let row = PortfolioOptionRow()
        row.configure(icon: icon, title: title, subtitle: subtitle, value: value, detail: detail, selected: selected)
        row.onTap = action
        return row
    }

    func fromCard(icon: PortfolioIcon, title: String, subtitle: String) -> UIView {
        let row = PortfolioOptionRow()
        row.configure(icon: icon, title: title, subtitle: subtitle, value: nil, detail: nil, selected: false)
        row.isUserInteractionEnabled = false
        row.accessibilityTraits = .staticText
        return row
    }
}

extension PortfolioSheetViewController: SoramitsuObserver {
    func styleDidChange(options: UpdateOptions) {
        guard options.contains(.palette) else { return }
        applyTheme()
        rebuild()
    }
}

/// A card row used by the sheets.
final class PortfolioOptionRow: UIControl {
    var onTap: (() -> Void)?
    private let icon = PortfolioTokenIconView(size: 40)
    private let title = UILabel.portfolio(FontType.textBoldM, .body, lines: 0, maximum: 30)
    private let subtitle = UILabel.portfolio(FontType.textS, .subheadline, color: PortfolioTheme.textSecondary,
                                             lines: 0, maximum: 26)
    private let value = UILabel.portfolio(FontType.amountM, .body, maximum: 30)
    private let detail = UILabel.portfolio(FontType.amountS, .subheadline, color: PortfolioTheme.textSecondary, maximum: 26)

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 20
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        let left = UIStackView(arrangedSubviews: [title, subtitle])
        left.axis = .vertical
        left.spacing = 3
        let right = UIStackView(arrangedSubviews: [value, detail])
        right.axis = .vertical
        right.spacing = 3
        right.alignment = .trailing
        value.textAlignment = .right
        detail.textAlignment = .right
        let main = UIStackView(arrangedSubviews: [icon, left, UIView(), right])
        main.spacing = 12
        main.alignment = .center
        main.isUserInteractionEnabled = false
        main.translatesAutoresizingMaskIntoConstraints = false
        addSubview(main)
        NSLayoutConstraint.activate([
            main.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            main.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            main.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            main.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 68)
        ])
        title.setContentCompressionResistancePriority(.required, for: .horizontal)
        value.setContentCompressionResistancePriority(.required, for: .horizontal)
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(icon iconModel: PortfolioIcon, title: String, subtitle: String, value: String?, detail: String?,
                   selected: Bool) {
        let tokens = PortfolioTheme.tokens
        icon.configure(iconModel)
        self.title.text = title
        self.title.textColor = tokens.textPrimary
        self.subtitle.text = subtitle
        self.subtitle.textColor = tokens.textSecondary
        self.value.text = value
        self.value.isHidden = value == nil
        self.value.textColor = tokens.textPrimary
        self.detail.text = detail
        self.detail.isHidden = detail == nil
        self.detail.textColor = tokens.textSecondary
        backgroundColor = selected ? PortfolioTheme.flowerPink.withAlphaComponent(PortfolioTheme.isDark ? 0.14 : 0.07)
            : (PortfolioTheme.isDark ? UIColor.white.withAlphaComponent(0.04) : tokens.surface)
        layer.borderColor = (selected ? PortfolioTheme.flowerPink : tokens.hairline).cgColor
        layer.borderWidth = selected ? 1.5 : 1
        accessibilityLabel = [title, subtitle, value, detail].compactMap { $0 }.joined(separator: ", ")
        accessibilityTraits = selected ? [.button, .selected] : .button
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.75 : 1 }
    }

    @objc private func tapped() { onTap?() }
}

// MARK: - Wallets

final class PortfolioWalletsSheet: PortfolioSheetViewController {
    struct Entry {
        let scope: PortfolioScope
        let icon: PortfolioIcon
        let title: String
        let subtitle: String
        let value: String
        let detail: String
    }

    var entries: [Entry] = []
    var selected: PortfolioScope = .allWallets
    var onSelect: ((PortfolioScope) -> Void)?
    var onRefresh: (() -> Void)?
    var onManage: (() -> Void)?
    var onManageAssets: (() -> Void)?

    override func buildContent() {
        for entry in entries {
            contentStack.addArrangedSubview(optionRow(icon: entry.icon, title: entry.title, subtitle: entry.subtitle,
                                                      value: entry.value, detail: entry.detail,
                                                      selected: entry.scope == selected) { [weak self] in
                self?.onSelect?(entry.scope)
            })
        }
        contentStack.setCustomSpacing(18, after: contentStack.arrangedSubviews.last ?? contentStack)
        contentStack.addArrangedSubview(banner(
            PortfolioStrings.text("All wallets adds each wallet's own total. Wallets that are not selected refresh about once a minute while you look, so each one shows how old its numbers are."),
            link: PortfolioStrings.text("Refresh all wallets")) { [weak self] in self?.onRefresh?() })
        let manage = UIButton(type: .system, primaryAction: UIAction { [weak self] _ in self?.onManage?() })
        var configuration = UIButton.Configuration.plain()
        configuration.attributedTitle = AttributedString(PortfolioStrings.text("Manage wallets"), attributes: AttributeContainer([
            .font: PortfolioTheme.font(FontType.textBoldS, .subheadline, maximum: 26),
            .foregroundColor: PortfolioTheme.tokens.link
        ]))
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 4, bottom: 12, trailing: 4)
        manage.configuration = configuration
        manage.contentHorizontalAlignment = .leading
        contentStack.addArrangedSubview(manage)
        let assets = UIButton(type: .system, primaryAction: UIAction { [weak self] _ in self?.onManageAssets?() })
        configuration.attributedTitle = AttributedString(PortfolioStrings.text("Manage selected wallet's assets"), attributes: AttributeContainer([
            .font: PortfolioTheme.font(FontType.textBoldS, .subheadline, maximum: 26),
            .foregroundColor: PortfolioTheme.tokens.link
        ]))
        assets.configuration = configuration
        assets.contentHorizontalAlignment = .leading
        assets.accessibilityIdentifier = "portfolio.manage-assets"
        contentStack.addArrangedSubview(assets)
    }
}

// MARK: - Picker

final class PortfolioPickerSheet: PortfolioSheetViewController {
    struct Option {
        let id: String
        let icon: PortfolioIcon
        let title: String
        let subtitle: String
        let value: String?
        let detail: String?
    }

    var options: [Option] = []
    var note: String?
    var onPick: ((String) -> Void)?

    override func buildContent() {
        if let note { contentStack.addArrangedSubview(paragraph(note)) }
        for option in options {
            contentStack.addArrangedSubview(optionRow(icon: option.icon, title: option.title, subtitle: option.subtitle,
                                                      value: option.value, detail: option.detail,
                                                      selected: false) { [weak self] in
                self?.onPick?(option.id)
            })
        }
    }
}

// MARK: - Info

final class PortfolioInfoSheet: PortfolioSheetViewController {
    var paragraphs: [String] = []
    var bullets: [String] = []
    var buttonTitle: String?
    var onButton: (() -> Void)?

    override func buildContent() {
        paragraphs.forEach { contentStack.addArrangedSubview(paragraph($0, color: PortfolioTheme.textPrimary)) }
        for bullet in bullets {
            let label = paragraph("•  " + bullet)
            contentStack.addArrangedSubview(label)
        }
        if let buttonTitle {
            contentStack.setCustomSpacing(18, after: contentStack.arrangedSubviews.last ?? contentStack)
            contentStack.addArrangedSubview(PortfolioPrimaryButton(title: buttonTitle) { [weak self] in self?.onButton?() })
        }
    }
}

// MARK: - Switch confirmation

final class PortfolioSwitchSheet: PortfolioSheetViewController {
    var walletName = ""
    var walletIcon: PortfolioIcon = .allWallets
    var onConfirm: (() -> Void)?

    override func buildContent() {
        contentStack.addArrangedSubview(fromCard(icon: walletIcon, title: walletName,
                                                 subtitle: PortfolioStrings.switchNote(walletName)))
        contentStack.setCustomSpacing(18, after: contentStack.arrangedSubviews.last ?? contentStack)
        contentStack.addArrangedSubview(PortfolioPrimaryButton(title: PortfolioStrings.switchAndReview(walletName)) {
            [weak self] in self?.onConfirm?()
        })
    }
}
