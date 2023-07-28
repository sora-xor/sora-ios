import SoraUIKit

final class ExploreAssetListCell: SoramitsuTableViewCell {

    private var assetItem: ExploreAssetListItem?

    private var assetView = ExploreAssetView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupView() {
        contentView.addSubview(assetView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            assetView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            assetView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            assetView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            assetView.topAnchor.constraint(equalTo: contentView.topAnchor),
        ])
    }
    
}

extension ExploreAssetListCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? ExploreAssetListItem else {
            assertionFailure("Incorect type of item")
            return
        }

        assetItem = item
        
        assetView.serialNumber.sora.text = item.viewModel.serialNumber

        assetView.assetImageView.image = item.viewModel.icon
        assetView.assetImageView.sora.loadingPlaceholder.type = .none

        if let title = item.viewModel.title {
            assetView.titleLabel.sora.text = title
            assetView.titleLabel.sora.loadingPlaceholder.type = .none
        }

        if let subtitle = item.viewModel.marketCap {
            assetView.subtitleLabel.sora.text = subtitle
            assetView.subtitleLabel.sora.loadingPlaceholder.type = .none
        }

        if let price = item.viewModel.price {
            assetView.amountUpLabel.sora.text = price
            assetView.amountUpLabel.sora.loadingPlaceholder.type = .none
        }
    }
}

