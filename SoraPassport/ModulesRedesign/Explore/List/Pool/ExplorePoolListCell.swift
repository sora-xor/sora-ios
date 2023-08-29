import SoraUIKit

final class ExplorePoolListCell: SoramitsuTableViewCell {

    private var poolItem: ExplorePoolListItem?

    private lazy var poolView = ExplorePoolView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupView() {
        contentView.addSubview(poolView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            poolView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            poolView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            poolView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            poolView.topAnchor.constraint(equalTo: contentView.topAnchor),
        ])
    }
    
}

extension ExplorePoolListCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? ExplorePoolListItem else {
            assertionFailure("Incorect type of item")
            return
        }

        poolItem = item
        
        poolView.serialNumber.sora.text = item.viewModel.serialNumber
        poolView.isUserInteractionEnabled = false
        poolView.firstCurrencyImageView.image = item.viewModel.baseAssetIcon
        poolView.firstCurrencyImageView.sora.loadingPlaceholder.type = .none
        
        poolView.secondCurrencyImageView.image = item.viewModel.targetAssetIcon
        poolView.secondCurrencyImageView.sora.loadingPlaceholder.type = .none

        if let title = item.viewModel.title {
            poolView.titleLabel.sora.text = title
            poolView.titleLabel.sora.loadingPlaceholder.type = .none
        }

        if let subtitle = item.viewModel.tvl {
            poolView.subtitleLabel.sora.text = subtitle
            poolView.subtitleLabel.sora.loadingPlaceholder.type = .none
        }

        if let price = item.viewModel.apy {
            poolView.amountUpLabel.sora.text = price
            poolView.amountUpLabel.sora.loadingPlaceholder.type = .none
        }
    }
}

