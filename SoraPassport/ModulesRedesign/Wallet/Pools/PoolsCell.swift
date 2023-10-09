import SoraUIKit
import SoraFoundation

final class PoolsCell: SoramitsuTableViewCell {
    
    private var poolsItem: PoolsItem?
    
    private let shimmerView: SoramitsuShimmerView = {
        let view = SoramitsuShimmerView()
        view.sora.cornerRadius = .max
        return view
    }()
    
    private lazy var arrowButton: WalletHeaderView = {
        let button = WalletHeaderView()
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.poolsItem?.arrowButtonHandler?()
        }
        return button
    }()

    private let moneyLabel: SoramitsuLabel = {
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
        view.sora.isHidden = true
        view.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }()
    
    private let mainInfoView: UIView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.sora.axis = .horizontal
        view.sora.distribution = .fill
        return view
    }()

    private lazy var openFullListPoolsButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .small, type: .text(.primary))
        button.sora.horizontalOffset = 0
        button.sora.attributedText = SoramitsuTextItem(text: R.string.localizable.commonExpand(preferredLanguages: .currentLocale),
                                                       fontData: FontType.buttonM,
                                                       textColor: .accentPrimary,
                                                       alignment: .left)
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.poolsItem?.expandButtonHandler?()
        }
        return button
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupView() {
        contentView.addSubviews(fullStackView)
        contentView.addSubviews(shimmerView)
        
        mainInfoView.addSubviews(arrowButton, moneyLabel)
        fullStackView.addArrangedSubviews(mainInfoView)
        fullStackView.setCustomSpacing(16, after: mainInfoView)
        
        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.commonExpand(preferredLanguages: locale.rLanguages)
        }
        
        LocalizationManager.shared.addObserver(with: openFullListPoolsButton) { [weak openFullListPoolsButton, weak arrowButton] (_, _) in
            guard let poolsItem = self.poolsItem else { return }
            let currentTitle = localizableTitle.value(for: LocalizationManager.shared.selectedLocale)
            arrowButton?.configure(title: poolsItem.title, isExpand: poolsItem.isExpand)
            openFullListPoolsButton?.sora.attributedText = SoramitsuTextItem(text: currentTitle,
                                                           fontData: FontType.buttonM,
                                                           textColor: .accentPrimary,
                                                           alignment: .left)
        }
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            arrowButton.leadingAnchor.constraint(equalTo: mainInfoView.leadingAnchor),
            arrowButton.topAnchor.constraint(equalTo: mainInfoView.topAnchor),
            arrowButton.centerYAnchor.constraint(equalTo: mainInfoView.centerYAnchor),
            arrowButton.trailingAnchor.constraint(equalTo: moneyLabel.leadingAnchor),
            
            moneyLabel.trailingAnchor.constraint(equalTo: mainInfoView.trailingAnchor),
            moneyLabel.centerYAnchor.constraint(equalTo: arrowButton.centerYAnchor),

            fullStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            fullStackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            fullStackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            fullStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            
            shimmerView.leadingAnchor.constraint(equalTo: fullStackView.leadingAnchor),
            shimmerView.centerYAnchor.constraint(equalTo: fullStackView.centerYAnchor),
            shimmerView.centerXAnchor.constraint(equalTo: fullStackView.centerXAnchor),
            shimmerView.topAnchor.constraint(equalTo: fullStackView.topAnchor),
        ])
    }
}

extension PoolsCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? PoolsItem else {
            assertionFailure("Incorect type of item")
            return
        }
        poolsItem = item
        
        moneyLabel.sora.text = item.moneyText

        arrowButton.configure(title: item.title, isExpand: item.isExpand)

        fullStackView.arrangedSubviews.filter { $0 is PoolView || $0 is SoramitsuButton }.forEach { subview in
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
            poolView.sora.isHidden = !item.isExpand
            poolView.sora.upAmountText = poolModel.fiatText
            poolView.firstCurrencyImageView.sora.loadingPlaceholder.type = .none
            poolView.secondCurrencyImageView.sora.loadingPlaceholder.type = .none
            poolView.rewardImageView.sora.loadingPlaceholder.type = .none
            poolView.titleLabel.sora.loadingPlaceholder.type = .none
            poolView.subtitleLabel.sora.loadingPlaceholder.type = .none
            poolView.amountUpLabel.sora.loadingPlaceholder.type = .none
            poolView.amountDownLabel.sora.loadingPlaceholder.type = .none
            poolView.sora.addHandler(for: .touchUpInside) { [weak poolsItem] in
                poolsItem?.poolHandler?(poolModel.identifier)
            }
            return poolView
        }

        fullStackView.addArrangedSubviews(poolViews)
        
        if let poolView = poolViews.last {
            fullStackView.setCustomSpacing(8, after: poolView)
        }

        openFullListPoolsButton.sora.isHidden = !item.isExpand
        fullStackView.addArrangedSubviews(openFullListPoolsButton)
        fullStackView.sora.isHidden = item.poolViewModels.isEmpty
        shimmerView.sora.alpha = item.state == .loading ? 1 : 0
    }
}

