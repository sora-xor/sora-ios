// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import SoraUIKit
import UIKit

/// The selected account's key warning (watch-only, missing or invalid keys, a pending repair),
/// kept on the portfolio home under the hero with the account header's own text and Restore action.
final class PortfolioNoticeItem: NSObject {
    private(set) weak var account: AccountTableViewItem?
    fileprivate var onChange: (() -> Void)?

    static func needsNotice(_ state: WalletAccountCapability.State) -> Bool {
        switch state {
        case .signing, .checking: return false
        case .watchOnly, .missingKeys, .invalidKeys, .repairPending, .unavailable: return true
        }
    }

    func bind(_ account: AccountTableViewItem) {
        self.account = account
        onChange?()
    }
}

extension PortfolioNoticeItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { PortfolioNoticeCell.self }
    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }
    var clipsToBounds: Bool { false }

    func itemHeight(forWidth width: CGFloat, context: SoramitsuTableViewContext?) -> CGFloat {
        UITableView.automaticDimension
    }
}

final class PortfolioNoticeCell: SoramitsuTableViewCell, SoramitsuTableViewCellProtocol {
    private weak var item: PortfolioNoticeItem?
    private let card = GlassView()
    private let badge = UILabel.portfolio(FontType.textBoldS, .subheadline, lines: 0, maximum: 26)
    private let reason = UILabel.portfolio(FontType.paragraphS, .subheadline, lines: 0, maximum: 28)
    private lazy var restore = PortfolioPrimaryButton(title: WalletUX.text("Restore keys for this account")) {
        [weak self] in self?.item?.account?.restoreKeysHandler?()
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
        card.shape = .rounded(20)
        card.border = .none
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)
        let stack = UIStackView(arrangedSubviews: [badge, reason, restore])
        stack.axis = .vertical
        stack.spacing = 8
        stack.setCustomSpacing(14, after: reason)
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            stack.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -16)
        ])
        badge.accessibilityIdentifier = "wallet-selected-account-capability-badge"
        reason.accessibilityIdentifier = "wallet-selected-account-read-only-reason"
        restore.accessibilityIdentifier = "wallet-selected-account-restore-keys"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? PortfolioNoticeItem else { return }
        self.item?.onChange = nil
        self.item = item
        item.onChange = { [weak self] in self?.reload() }
        reload()
    }

    private func reload() {
        guard let state = item?.account?.capability else { return }
        let tokens = PortfolioTheme.tokens
        card.apply()
        card.backgroundColor = tokens.warningContainer.withAlphaComponent(PortfolioTheme.isDark ? 0.7 : 1)
        card.layer.cornerRadius = 20
        badge.text = state.badge
        badge.textColor = tokens.warning
        reason.text = state.reason
        reason.textColor = tokens.textPrimary
        restore.isHidden = !state.canRestore
    }
}
