import SoraUIKit

final class PoolListCell: SoramitsuTableViewCell {

    private var assetItem: PoolListItem?

    private lazy var poolView: PoolView = {
        let view = PoolView(mode: .view)
        view.sora.favoriteButtonImage = R.image.wallet.star()
        view.sora.unfavoriteButtonImage = R.image.wallet.unstar()
        view.sora.unvisibilityButtonImage = R.image.wallet.crossedOutEye()
        view.firstCurrencyImageView.sora.loadingPlaceholder.type = .none
        view.secondCurrencyImageView.sora.loadingPlaceholder.type = .none
        view.rewardImageView.sora.loadingPlaceholder.type = .none
        view.titleLabel.sora.loadingPlaceholder.type = .none
        view.subtitleLabel.sora.loadingPlaceholder.type = .none
        view.amountUpLabel.sora.loadingPlaceholder.type = .none
        view.amountDownLabel.sora.loadingPlaceholder.type = .none
        view.favoriteButton.sora.associate(states: .pressed) { [weak self] g in
            guard let item = self?.assetItem else { return }
            view.sora.isFavorite.toggle()
            self?.assetItem?.favoriteHandle?(item)
        }
        return view
    }()

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

extension PoolListCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? PoolListItem else {
            assertionFailure("Incorect type of item")
            return
        }
        
        poolView.sora.firstPoolImage = item.poolViewModel.baseAssetImage
        poolView.sora.secondPoolImage = item.poolViewModel.targetAssetImage
        poolView.sora.rewardTokenImage = item.poolViewModel.rewardAssetImage
        poolView.sora.titleText = item.poolViewModel.title
        poolView.sora.subtitleText = item.poolViewModel.subtitle
        poolView.sora.mode = item.poolViewModel.mode
        poolView.sora.upAmountText = item.poolViewModel.fiatText
        poolView.sora.isFavorite = item.poolInfo.isFavorite

        assetItem = item
    }
}

