import SoraUIKit

final class ActivityCell: SoramitsuTableViewCell {

    private var assetItem: ActivityItem?

    private lazy var historyView: HistoryTransactionView = {
        let view = HistoryTransactionView()
        view.isUserInteractionEnabled = false
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        setupConstraints()
        SoramitsuUI.updates.addObserver(self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupView() {
        contentView.addSubview(historyView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            historyView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            historyView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            historyView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            historyView.topAnchor.constraint(equalTo: contentView.topAnchor),
        ])
    }
}

extension ActivityCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? ActivityItem else {
            assertionFailure("Incorect type of item")
            return
        }
        
        assetItem = item

        item.model.firstAssetImageViewModel?.loadImage { [weak self] (icon, _) in
            self?.historyView.sora.firstHistoryTransactionImage  = icon
        }
        
        item.model.secondAssetImageViewModel?.loadImage { [weak self] (icon, _) in
            self?.historyView.sora.secondHistoryTransactionImage = icon
        }

        historyView.sora.titleText = item.model.title
        historyView.sora.subtitleText = item.model.subtitle
        historyView.sora.transactionType = item.model.typeTransactionImage
        historyView.sora.upAmountText = item.model.firstBalanceText
        historyView.sora.fiatText = item.model.fiatText
        historyView.sora.isNeedTwoTokens = item.model.isNeedTwoImage
        historyView.sora.statusImage = item.model.status.image
    }
}

extension ActivityCell: SoramitsuObserver {
    func styleDidChange(options: UpdateOptions) {
        guard let assetItem = assetItem else { return }
        historyView.sora.upAmountText = assetItem.model.firstBalanceText
    }
}

