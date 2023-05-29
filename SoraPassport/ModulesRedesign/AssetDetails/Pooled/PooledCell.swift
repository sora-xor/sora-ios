import SoraUIKit

final class PooledCell: SoramitsuTableViewCell {
    
    private var activityItem: PooledItem?

    private let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline2
        label.sora.textColor = .fgPrimary
        return label
    }()

    private let fullStackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .bgSurface
        view.sora.axis = .vertical
        view.sora.cornerRadius = .max
        view.sora.distribution = .fill
        view.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        view.isLayoutMarginsRelativeArrangement = true
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
        contentView.addSubview(fullStackView)
        fullStackView.addArrangedSubviews(titleLabel)
        fullStackView.setCustomSpacing(16, after: titleLabel)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            fullStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            fullStackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            fullStackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            fullStackView.topAnchor.constraint(equalTo: contentView.topAnchor),
        ])
    }
}

extension PooledCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? PooledItem else {
            assertionFailure("Incorect type of item")
            return
        }
        
        titleLabel.sora.text = R.string.localizable.assetDetailsYourPools(item.assetInfo.symbol, preferredLanguages: .currentLocale)
        
        fullStackView.arrangedSubviews.filter { $0 is PoolView }.forEach { subview in
            fullStackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        
        let poolViews = item.poolViewModels.map { poolModel -> PoolView in
            let poolView = PoolView(mode: .view)
            poolView.sora.firstPoolImage = poolModel.baseAssetImage
            poolView.sora.secondPoolImage = poolModel.targetAssetImage
            poolView.sora.rewardTokenImage = poolModel.rewardAssetImage
            poolView.sora.titleText = poolModel.title
            poolView.sora.subtitleText = poolModel.subtitle
            poolView.sora.upAmountText = poolModel.fiatText
            poolView.sora.addHandler(for: .touchUpInside) {
                item.openPoolDetailsHandler?(poolModel.identifier)
            }
            return poolView
        }

        fullStackView.addArrangedSubviews(poolViews)
        activityItem = item
    }
}

