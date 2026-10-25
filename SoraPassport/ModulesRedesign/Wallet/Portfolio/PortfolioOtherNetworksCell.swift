// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import SoraUIKit
import UIKit

/// XOR on a network other than SORA2: one row of "XOR on other networks".
struct NetworkAssetRow: Equatable {
    let account: NetworkAccount
    /// "SORA · Taira". A row on the main network has no network label.
    let title: String
    /// "50 XOR", "Address ready" for a network that is not live yet, or empty
    /// while the balance loads.
    let amount: String
    let tag: WalletNetworkTag?
    let icon: UIImage?
}

/// "XOR on other networks": the selected wallet's XOR rows on networks other than SORA2, under the
/// portfolio list, each opening that network's page. The Wallet tab fills the rows
/// (`RedesignWalletViewModel.refreshNetworkRows`). Without rows it takes no space.
final class PortfolioOtherNetworksItem: NSObject {
    var rows: [NetworkAssetRow] = []
    /// Opens the network's page (`RedesignWalletViewModel.openNetwork(account:)`).
    var onOpen: ((NetworkAccount) -> Void)?

    func open(_ account: NetworkAccount) {
        onOpen?(account)
    }
}

extension PortfolioOtherNetworksItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { PortfolioOtherNetworksCell.self }
    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }
    var clipsToBounds: Bool { false }

    /// A fixed height from the fonts: one line of title, then the rows. Measured self-sizing put
    /// this card at the wrong height when it was bound before the table knew its width.
    func itemHeight(forWidth width: CGFloat, context: SoramitsuTableViewContext?) -> CGFloat {
        rows.isEmpty ? 0 : PortfolioOtherNetworksCell.height(rowCount: rows.count)
    }
}

final class PortfolioOtherNetworksCell: SoramitsuTableViewCell, SoramitsuTableViewCellProtocol {
    private weak var item: PortfolioOtherNetworksItem?
    private let card = GlassView()
    private let content = UIStackView()
    private let title = UILabel.portfolio(FontType.headline2, .title3, maximum: 32)
    private let outer = UIStackView()

    static let rowSpacing: CGFloat = 4

    /// The card's height for `rowCount` rows at the current text size.
    static func height(rowCount: Int) -> CGFloat {
        let title = ceil(PortfolioTheme.font(FontType.headline2, .title3, maximum: 32).lineHeight)
        let rows = CGFloat(rowCount) * PortfolioNetworkAssetRowView.height
            + CGFloat(max(0, rowCount - 1)) * rowSpacing
        // Outer margins 6 and 10, card insets 18 and 12, 10 under the title.
        return 6 + 18 + title + 10 + rows + 12 + 10
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
        card.shape = .rounded(24)
        content.axis = .vertical
        content.spacing = Self.rowSpacing
        title.adjustsFontSizeToFitWidth = true
        title.minimumScaleFactor = 0.8
        content.translatesAutoresizingMaskIntoConstraints = false
        card.contentView.addSubview(content)
        title.accessibilityTraits = .header
        // The card collapses with its last row: a hidden arranged subview takes no height.
        outer.axis = .vertical
        outer.isLayoutMarginsRelativeArrangement = true
        // Margins are the design's, not widened where a row passes the home indicator.
        outer.insetsLayoutMarginsFromSafeArea = false
        outer.translatesAutoresizingMaskIntoConstraints = false
        outer.addArrangedSubview(card)
        contentView.addSubview(outer)
        NSLayoutConstraint.activate([
            outer.topAnchor.constraint(equalTo: contentView.topAnchor),
            outer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            outer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            outer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            content.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 18),
            content.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -16),
            // Never stretch the rows if the fixed height leaves a point to spare.
            content.bottomAnchor.constraint(lessThanOrEqualTo: card.contentView.bottomAnchor, constant: -12)
        ])
        SoramitsuUI.updates.addObserver(self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? PortfolioOtherNetworksItem else { return }
        self.item = item
        reload()
    }

    private func reload() {
        let rows = item?.rows ?? []
        content.arrangedSubviews.forEach { $0.removeFromSuperview() }
        card.isHidden = rows.isEmpty
        outer.directionalLayoutMargins = rows.isEmpty
            ? .zero : NSDirectionalEdgeInsets(top: 6, leading: 16, bottom: 10, trailing: 16)
        guard !rows.isEmpty else { return }
        card.apply()
        title.text = PortfolioStrings.otherNetworksTitle
        title.textColor = PortfolioTheme.textPrimary
        content.addArrangedSubview(title)
        content.setCustomSpacing(10, after: title)
        rows.forEach { content.addArrangedSubview(makeRow($0)) }
    }

    private func makeRow(_ row: NetworkAssetRow) -> UIView {
        let view = PortfolioNetworkAssetRowView(row: row)
        let account = row.account
        view.onTap = { [weak self] in self?.item?.open(account) }
        return view
    }
}

/// One row: XOR's icon, "XOR · SORA Nexus", the amount (or "Address ready"), and the network's tag
/// where the row has no value to show.
final class PortfolioNetworkAssetRowView: UIControl {
    var onTap: (() -> Void)?

    /// Icon or two lines of text, whichever is taller, with 12 above and below.
    static var height: CGFloat {
        let texts = ceil(PortfolioTheme.font(FontType.textM, .body, maximum: 28).lineHeight)
            + 4 + ceil(PortfolioTheme.font(FontType.textBoldXS, .footnote, maximum: 22).lineHeight)
        return 24 + max(40, texts)
    }

    private let icon = UIImageView()
    private let title = UILabel.portfolio(FontType.textM, .body, maximum: 28)
    private let amount = UILabel.portfolio(FontType.textBoldXS, .footnote, maximum: 22)
    private let tagLabel = UILabel.portfolio(FontType.textBoldXS, .caption1, maximum: 20)

    init(row: NetworkAssetRow) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        icon.image = row.icon
        icon.contentMode = .scaleAspectFit
        icon.layer.cornerRadius = 20
        icon.clipsToBounds = true
        icon.translatesAutoresizingMaskIntoConstraints = false
        title.text = row.title
        title.textColor = PortfolioTheme.textPrimary
        amount.text = row.amount
        amount.textColor = PortfolioTheme.textPrimary
        amount.isHidden = row.amount.isEmpty
        switch row.tag {
        case .testnet:
            tagLabel.text = row.tag?.title
            tagLabel.textColor = .systemOrange
        case .comingSoon:
            tagLabel.text = row.tag?.title
            tagLabel.textColor = PortfolioTheme.textSecondary
        case .main, nil:
            tagLabel.text = nil
        }
        tagLabel.isHidden = tagLabel.text == nil
        tagLabel.setContentHuggingPriority(.required, for: .horizontal)
        tagLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        let texts = UIStackView(arrangedSubviews: [title, amount])
        texts.axis = .vertical
        texts.spacing = 4
        let line = UIStackView(arrangedSubviews: [icon, texts, tagLabel])
        line.spacing = 12
        line.alignment = .center
        line.isUserInteractionEnabled = false
        line.translatesAutoresizingMaskIntoConstraints = false
        addSubview(line)
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 40),
            icon.heightAnchor.constraint(equalToConstant: 40),
            line.leadingAnchor.constraint(equalTo: leadingAnchor),
            line.trailingAnchor.constraint(equalTo: trailingAnchor),
            line.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            line.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = [row.title, row.amount, row.tag?.title].compactMap { $0 }
            .filter { !$0.isEmpty }.joined(separator: ", ")
        accessibilityIdentifier = "portfolio.network-row.\(row.account.networkId.rawValue)"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.7 : 1 }
    }

    @objc private func tapped() { onTap?() }
}

extension PortfolioOtherNetworksCell: SoramitsuObserver {
    func styleDidChange(options: UpdateOptions) {
        guard options.contains(.palette) else { return }
        reload()
    }
}
