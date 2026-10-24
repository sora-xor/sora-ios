// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import SoraUIKit
import UIKit

/// Move between the user's own wallets on one network. Picks the parameters and hands off to Send.
final class PortfolioMoveSheet: PortfolioSheetViewController, UITextFieldDelegate {
    struct Destination: Equatable {
        let walletId: String
        let name: String
        let address: String
    }

    enum Availability: Equatable {
        /// SORA2: Send with the recipient, the asset and the amount prefilled.
        case send
        /// Taira: the app's Nexus send, where the recipient is pasted.
        case nexusSend
        case unavailable(String)
    }

    var holding: PortfolioHolding?
    var sourceWalletName = ""
    var sourceIsSelected = true
    var destinations: [Destination] = []
    var availability: Availability = .send
    var onReview: ((Destination, PortfolioAmountChoice?) -> Void)?
    var onCopyAddress: ((String) -> Void)?

    private var selectedDestination: String?
    private var amountText = ""
    private var amountIsMax = false
    private let field = UITextField()
    private var primary: PortfolioPrimaryButton?
    private let validation = UILabel.portfolio(FontType.textXS, .caption1, color: PortfolioTheme.tokens.error, lines: 0,
                                               maximum: 22)

    override func buildContent() {
        guard let holding else { return }
        let symbol = holding.token.symbol
        if selectedDestination == nil { selectedDestination = destinations.first?.walletId }
        contentStack.addArrangedSubview(eyebrow(PortfolioStrings.from))
        contentStack.addArrangedSubview(fromCard(
            icon: .network(holding.network),
            title: PortfolioStrings.networkName(holding.network),
            subtitle: sourceWalletName + " · " + PortfolioStrings.transferable + " " +
                PortfolioFormat.amount(holding.transferable, symbol: symbol)))
        contentStack.setCustomSpacing(18, after: contentStack.arrangedSubviews.last ?? contentStack)
        contentStack.addArrangedSubview(eyebrow(PortfolioStrings.to))
        for destination in destinations {
            let row = optionRow(icon: .wallet(id: destination.walletId, name: destination.name),
                                title: destination.name,
                                subtitle: PortfolioStrings.networkName(holding.network) + " · " +
                                    PortfolioFormat.shortAddress(destination.address),
                                value: nil, detail: nil,
                                selected: destination.walletId == selectedDestination) { [weak self] in
                self?.selectedDestination = destination.walletId
                self?.rebuild()
            }
            contentStack.addArrangedSubview(row)
        }

        switch availability {
        case .send:
            contentStack.setCustomSpacing(18, after: contentStack.arrangedSubviews.last ?? contentStack)
            contentStack.addArrangedSubview(eyebrow(PortfolioStrings.upper(PortfolioStrings.amount)))
            contentStack.addArrangedSubview(amountField(symbol: symbol, icon: .token(id: holding.token.id, symbol: symbol,
                                                                                    icon: holding.token.icon)))
            validation.isHidden = true
            contentStack.addArrangedSubview(validation)
            contentStack.addArrangedSubview(banner(PortfolioStrings.moveExplainer))
        case .nexusSend:
            if let destination = destinations.first(where: { $0.walletId == selectedDestination }) {
                contentStack.addArrangedSubview(banner(
                    PortfolioStrings.format("The %@ send asks for the recipient. Copy %@'s address and paste it there.",
                                            PortfolioStrings.networkName(holding.network), destination.name),
                    link: PortfolioStrings.text("Copy address")) { [weak self] in
                        self?.onCopyAddress?(destination.address)
                    })
            }
        case let .unavailable(reason):
            contentStack.addArrangedSubview(banner(reason))
        }

        if !sourceIsSelected {
            let note = paragraph(PortfolioStrings.switchNote(sourceWalletName), color: PortfolioTheme.textPrimary)
            contentStack.addArrangedSubview(note)
        }
        let title = sourceIsSelected ? PortfolioStrings.reviewInSend : PortfolioStrings.switchAndReview(sourceWalletName)
        let button = PortfolioPrimaryButton(title: title) { [weak self] in self?.review() }
        primary = button
        contentStack.setCustomSpacing(18, after: contentStack.arrangedSubviews.last ?? contentStack)
        contentStack.addArrangedSubview(button)
        updateValidation()
    }

    private func amountField(symbol: String, icon: PortfolioIcon) -> UIView {
        let tokens = PortfolioTheme.tokens
        let container = UIView()
        container.backgroundColor = tokens.inputFill
        container.layer.cornerRadius = 20
        container.layer.cornerCurve = .continuous
        container.layer.borderWidth = 1
        container.layer.borderColor = tokens.borderInput.withAlphaComponent(0.5).cgColor
        field.text = amountText
        field.placeholder = "0"
        field.keyboardType = .decimalPad
        field.font = PortfolioTheme.font(FontType.textL, .title3, maximum: 34)
        field.adjustsFontForContentSizeCategory = true
        field.textColor = tokens.textPrimary
        field.delegate = self
        field.accessibilityLabel = PortfolioStrings.amount
        field.addTarget(self, action: #selector(amountChanged), for: .editingChanged)
        let tokenIcon = PortfolioTokenIconView(size: 26)
        tokenIcon.configure(icon)
        let symbolLabel = UILabel.portfolio(FontType.textBoldM, .body, maximum: 28)
        symbolLabel.text = symbol
        symbolLabel.textColor = tokens.textPrimary
        let max = UIButton(type: .system, primaryAction: UIAction { [weak self] _ in self?.selectMax() })
        var configuration = UIButton.Configuration.plain()
        configuration.attributedTitle = AttributedString(PortfolioStrings.max, attributes: AttributeContainer([
            .font: PortfolioTheme.font(FontType.textBoldS, .subheadline, maximum: 24),
            .foregroundColor: tokens.textPrimary
        ]))
        configuration.background.strokeColor = tokens.hairline
        configuration.background.strokeWidth = 1
        configuration.background.cornerRadius = 18
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
        max.configuration = configuration
        let stack = UIStackView(arrangedSubviews: [field, tokenIcon, symbolLabel, max])
        stack.spacing = 8
        stack.alignment = .center
        stack.setCustomSpacing(12, after: symbolLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        // The field takes the free width; the token and Max keep their natural size.
        field.setContentHuggingPriority(UILayoutPriority(1), for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        [tokenIcon, symbolLabel, max].forEach {
            $0.setContentHuggingPriority(.required, for: .horizontal)
            $0.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 60)
        ])
        return container
    }

    @objc private func amountChanged() {
        amountText = field.text ?? ""
        amountIsMax = false
        updateValidation()
    }

    private func selectMax() {
        guard let holding else { return }
        amountIsMax = true
        amountText = PortfolioFormat.plain(holding.transferable, maxFraction: 8, locale: .current)
        field.text = amountText
        updateValidation()
    }

    /// The typed amount; nil when the field is empty or not a number.
    private var parsedAmount: Decimal? {
        var text = amountText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        let separator = Locale.current.decimalSeparator ?? "."
        if separator != "." {
            text = text.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: separator, with: ".")
        }
        return Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))
    }

    private func updateValidation() {
        guard let holding else { return }
        var message: String?
        var enabled = selectedDestination != nil
        if case let .unavailable(reason) = availability {
            enabled = false
            message = reason
        } else if availability == .send, !amountIsMax, !amountText.isEmpty {
            if let amount = parsedAmount, amount > 0 {
                if amount > holding.transferable {
                    enabled = false
                    message = PortfolioStrings.text("More than this wallet can move.")
                }
            } else {
                enabled = false
                message = PortfolioStrings.text("Enter a valid amount.")
            }
        }
        primary?.isEnabled = enabled
        validation.text = message
        validation.isHidden = message == nil || availability != .send
    }

    private func review() {
        guard let destination = destinations.first(where: { $0.walletId == selectedDestination }) else { return }
        let amount: PortfolioAmountChoice?
        if amountIsMax {
            amount = .max
        } else if let value = parsedAmount, value > 0 {
            amount = .exact(value)
        } else {
            amount = nil
        }
        onReview?(destination, amount)
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        let allowed = CharacterSet(charactersIn: "0123456789" + (Locale.current.decimalSeparator ?? "."))
        return string.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}

/// Swap: the pay token, a short row of popular targets, the checks, then Polkaswap.
final class PortfolioSwapSheet: PortfolioSheetViewController {
    struct Target: Equatable {
        let id: String
        let symbol: String
        let icon: String?
    }

    var holding: PortfolioHolding?
    var walletName = ""
    var isSelectedWallet = true
    var targets: [Target] = []
    var checks: [PortfolioDetailModel.Check] = []
    var onOpen: ((Target) -> Void)?
    var onReceiveOnSora2: (() -> Void)?

    private var selectedTarget: String?

    override func buildContent() {
        guard let holding else { return }
        let symbol = holding.token.symbol
        contentStack.addArrangedSubview(eyebrow(PortfolioStrings.youPay))
        contentStack.addArrangedSubview(fromCard(
            icon: .token(id: holding.token.id, symbol: symbol, icon: holding.token.icon),
            title: symbol,
            subtitle: walletName + " · " + PortfolioStrings.networkName(holding.network) + " · " +
                PortfolioStrings.transferable + " " + PortfolioFormat.amount(holding.transferable, symbol: symbol)))

        guard holding.network == .sora2 else {
            contentStack.addArrangedSubview(banner(PortfolioStrings.polkaswapRunsOnSora2 + " " +
                PortfolioStrings.noRoute(from: PortfolioStrings.networkName(holding.network))))
            contentStack.addArrangedSubview(PortfolioPrimaryButton(title: PortfolioStrings.receiveOnSora2) { [weak self] in
                self?.onReceiveOnSora2?()
            })
            return
        }

        if selectedTarget == nil { selectedTarget = targets.first?.id }
        contentStack.setCustomSpacing(18, after: contentStack.arrangedSubviews.last ?? contentStack)
        contentStack.addArrangedSubview(eyebrow(PortfolioStrings.youGet))
        let chips = UIStackView()
        chips.spacing = 8
        chips.distribution = .fillEqually
        for target in targets {
            let chip = PortfolioTargetChip()
            chip.configure(target, selected: target.id == selectedTarget)
            chip.onTap = { [weak self] in
                self?.selectedTarget = target.id
                self?.rebuild()
            }
            chips.addArrangedSubview(chip)
        }
        contentStack.addArrangedSubview(chips)
        contentStack.setCustomSpacing(18, after: chips)
        let tokens = PortfolioTheme.tokens
        for check in checks {
            let label = UILabel.portfolio(FontType.textS, .subheadline, lines: 0, maximum: 26)
            let text = NSMutableAttributedString(attachment: NSTextAttachment(
                image: PortfolioGlyphs.symbol(check.isMet ? "checkmark" : "circle", pointSize: 13, weight: .bold,
                                              color: check.isMet ? tokens.success : tokens.textTertiary) ?? UIImage()))
            text.append(NSAttributedString(string: "  " + check.text, attributes: [.foregroundColor: tokens.textPrimary]))
            label.attributedText = text
            contentStack.addArrangedSubview(label)
        }
        contentStack.addArrangedSubview(paragraph(PortfolioStrings.priceFeeImpact))
        if !isSelectedWallet {
            contentStack.addArrangedSubview(paragraph(PortfolioStrings.switchNote(walletName),
                                                      color: PortfolioTheme.textPrimary))
        }
        let title = isSelectedWallet ? PortfolioStrings.openPolkaswap : PortfolioStrings.switchAndReview(walletName)
        let button = PortfolioPrimaryButton(title: title, style: .swap, showsFlower: isSelectedWallet) { [weak self] in
            guard let self, let target = self.targets.first(where: { $0.id == self.selectedTarget }) else { return }
            self.onOpen?(target)
        }
        contentStack.setCustomSpacing(18, after: contentStack.arrangedSubviews.last ?? contentStack)
        contentStack.addArrangedSubview(button)
    }
}

/// A target token in the Swap sheet.
final class PortfolioTargetChip: UIControl {
    var onTap: (() -> Void)?
    private let icon = PortfolioTokenIconView(size: 22)
    private let label = UILabel.portfolio(FontType.textBoldS, .subheadline, maximum: 22)

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.spacing = 6
        stack.alignment = .center
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(_ target: PortfolioSwapSheet.Target, selected: Bool) {
        let tokens = PortfolioTheme.tokens
        icon.configure(.token(id: target.id, symbol: target.symbol, icon: target.icon))
        label.text = target.symbol
        label.textColor = tokens.textPrimary
        backgroundColor = selected ? PortfolioTheme.flowerPink.withAlphaComponent(PortfolioTheme.isDark ? 0.18 : 0.08)
            : (PortfolioTheme.isDark ? UIColor.white.withAlphaComponent(0.05) : tokens.surface)
        layer.borderColor = (selected ? PortfolioTheme.flowerPink : tokens.hairline).cgColor
        layer.borderWidth = selected ? 1.5 : 1
        accessibilityLabel = target.symbol
        accessibilityTraits = selected ? [.button, .selected] : .button
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }

    @objc private func tapped() { onTap?() }
}
