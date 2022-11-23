import SoraSwiftUI

final class AssetListCell: SoramitsuTableViewCell {

    private var assetItem: AssetListItem?

    private lazy var assetView: AssetView = {
        let view = AssetView(type: .asset, mode: .view)
        view.sora.favoriteButtonImage = R.image.wallet.star()
        view.sora.unfavoriteButtonImage = R.image.wallet.unstar()
        view.sora.unvisibilityButtonImage = R.image.wallet.crossedOutEye()
        view.sora.visibilityButtonImage = R.image.wallet.eye()
        view.sora.dragDropImage = R.image.wallet.burger()
        view.favoriteButton.sora.associate(states: .pressed) { [weak self] g in
            guard let item = self?.assetItem else { return }
            view.sora.isFavorite.toggle()
            self?.assetItem?.favoriteHandle?(item)
        }
        view.visibilityButton.sora.associate(states: .pressed) { [weak self] g in
            view.sora.isVisible.toggle()
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

extension AssetListCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? AssetListItem else {
            assertionFailure("Incorect type of item")
            return
        }

        item.assetViewModel.imageViewModel?.loadImage { [weak self] (icon, _) in
            self?.assetView.sora.firstAssetImage = icon
        }

        assetView.sora.titleText = item.assetViewModel.title
        assetView.sora.subtitleText = item.assetViewModel.subtitle
        assetView.sora.mode = item.assetViewModel.mode
        assetView.sora.isFavorite = item.assetInfo.visible

        assetItem = item
    }
}

