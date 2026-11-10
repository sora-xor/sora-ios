// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

import SoraUIKit
import UIKit

/// "XOR on other networks": the selected wallet's XOR rows on networks other than SORA2, under the
/// portfolio list, each opening that network's page. The Wallet tab fills the rows
/// (`RedesignWalletViewModel.refreshNetworkRows`). Without rows it takes no space, and it steps aside
/// while the portfolio shows another wallet, whose numbers these rows are not.
final class PortfolioOtherNetworksItem: NSObject {
    var rows: [NetworkAssetRow] = []
    /// False while the portfolio's scope is a wallet other than the selected one.
    var isShown = true
    /// The selected wallet's name, while All wallets could make the rows look like everyone's.
    var walletName: String?
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
        rows.isEmpty || !isShown ? 0 : PortfolioOtherNetworksCell.height(rowCount: rows.count)
    }
}

final class PortfolioOtherNetworksCell: SoramitsuTableViewCell, SoramitsuTableViewCellProtocol {
    private weak var item: PortfolioOtherNetworksItem?
    private let card = GlassView()
    private let content = UIStackView()
    private let title = UILabel.portfolio(FontType.headline2, .title3, maximum: 32)
    private let outer = UIStackView()
    private var rowViews: [PortfolioNetworkAssetRowView] = []

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
        content.addArrangedSubview(title)
        content.setCustomSpacing(10, after: title)
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
        let rows = item?.isShown == true ? item?.rows ?? [] : []
        card.isHidden = rows.isEmpty
        outer.directionalLayoutMargins = rows.isEmpty
            ? .zero : NSDirectionalEdgeInsets(top: 6, leading: 16, bottom: 10, trailing: 16)
        showRows(rows)
        // VoiceOver reads this list. Left to itself, UIKit keeps its own copy of a cell's elements and refreshes it
        // only when a direct subview of the content view comes or goes, which never happens down here in the card.
        accessibilityElements = rows.isEmpty ? nil : [title] + rowViews
        guard !rows.isEmpty else { return }
        card.apply()
        title.text = [PortfolioStrings.otherNetworksTitle, item?.walletName].compactMap { $0 }.joined(separator: " · ")
        title.textColor = PortfolioTheme.textPrimary
    }

    /// A row keeps its view while its network stays in the card, so VoiceOver stays on a row whose amount changes.
    private func showRows(_ rows: [NetworkAssetRow]) {
        var unused = rowViews
        rowViews = rows.map { row in
            let index = unused.firstIndex { $0.networkId == row.account.networkId }
            let view = index.map { unused.remove(at: $0) } ?? PortfolioNetworkAssetRowView()
            view.configure(row)
            view.onTap = { [weak self] in self?.item?.open(row.account) }
            return view
        }
        unused.forEach { $0.removeFromSuperview() }
        // The title stays first. Inserting a view that is already arranged moves it.
        for (offset, view) in rowViews.enumerated() where content.arrangedSubviews.dropFirst(offset + 1).first !== view {
            content.insertArrangedSubview(view, at: offset + 1)
        }
    }
}

/// One row: XOR's icon, "XOR · SORA Nexus", the amount (or "Address ready"), and the network's tag
/// where the row has no value to show.
final class PortfolioNetworkAssetRowView: UIControl {
    var onTap: (() -> Void)?
    private(set) var networkId: NetworkId?

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

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        icon.contentMode = .scaleAspectFit
        icon.layer.cornerRadius = 20
        icon.clipsToBounds = true
        icon.translatesAutoresizingMaskIntoConstraints = false
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
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(_ row: NetworkAssetRow) {
        networkId = row.account.networkId
        icon.image = row.icon
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
        accessibilityLabel = [row.title, row.amount, row.tag?.title].compactMap { $0 }
            .filter { !$0.isEmpty }.joined(separator: ", ")
        accessibilityIdentifier = "portfolio.network-row.\(row.account.networkId.rawValue)"
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
