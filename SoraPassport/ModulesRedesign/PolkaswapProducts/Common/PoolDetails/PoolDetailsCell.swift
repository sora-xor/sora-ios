import SoraUIKit

final class PoolDetailsCell: SoramitsuTableViewCell {
    
    private var poolDetailsItem: PoolDetailsItem?
    
    private let stackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .bgSurface
        view.sora.axis = .vertical
        view.sora.cornerRadius = .max
        view.sora.distribution = .fill
        view.sora.shadow = .small
        view.spacing = 14
        view.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }()
    
    private lazy var headerView = PoolDetailsHeaderView()
    
    private lazy var supplyLiquidity: SoramitsuButton = {
        let button = SoramitsuButton()
        button.sora.horizontalOffset = 0
        button.sora.title = R.string.localizable.commonSupply(preferredLanguages: .currentLocale)
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .additionalPolkaswap
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.poolDetailsItem?.handler?(Liquidity.TransactionLiquidityType.add)
        }
        return button
    }()
    
    private lazy var removeLiquidity: SoramitsuButton = {
        let button = SoramitsuButton()
        button.sora.horizontalOffset = 0
        button.sora.attributedText = SoramitsuTextItem(text: R.string.localizable.commonRemove(preferredLanguages: .currentLocale),
                                                       fontData: FontType.buttonM ,
                                                       textColor: .additionalPolkaswap,
                                                       alignment: .center)
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .additionalPolkaswapContainer
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.poolDetailsItem?.handler?(Liquidity.TransactionLiquidityType.withdraw)
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
        contentView.addSubview(stackView)
        
        stackView.addArrangedSubviews(headerView)
        stackView.setCustomSpacing(24, after: headerView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
        ])
    }
}

extension PoolDetailsCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? PoolDetailsItem else {
            assertionFailure("Incorect type of item")
            return
        }
        poolDetailsItem = item
        
        headerView.titleLabel.sora.text = item.title
        item.firstAssetImage?.loadImage { [weak self] (icon, _) in
            self?.headerView.firstCurrencyImageView.image = icon
        }
        
        item.secondAssetImage?.loadImage { [weak self] (icon, _) in
            self?.headerView.secondCurrencyImageView.image = icon
        }
        
        item.rewardAssetImage?.loadImage { [weak self] (icon, _) in
            self?.headerView.rewardImageView.image = icon
        }

        stackView.arrangedSubviews.filter { $0 is DetailView || $0 is SoramitsuButton }.forEach { subview in
            stackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        
        let detailsViews = item.detailsViewModel.map { detailModel -> DetailView in
            let view = DetailView()

            view.assetImageView.isHidden = detailModel.rewardAssetImage == nil
            detailModel.rewardAssetImage?.loadImage { (icon, _) in
                view.assetImageView.image = icon
            }

            view.titleLabel.sora.text = detailModel.title
            view.valueLabel.sora.attributedText = detailModel.assetAmountText
            view.fiatValueLabel.sora.attributedText = detailModel.fiatAmountText
            view.fiatValueLabel.sora.isHidden = detailModel.fiatAmountText == nil
            view.infoButton.sora.isHidden = detailModel.infoHandler == nil
            view.infoButton.sora.addHandler(for: .touchUpInside) { [weak detailModel] in
                detailModel?.infoHandler?()
            }
            
            return view
        }

        if let detailsView = detailsViews.first {
            stackView.setCustomSpacing(14, after: detailsView)
        }
        
        detailsViews.enumerated().forEach { index, view in
            stackView.addArrangedSubview(view)
            
            if index != detailsViews.count - 1 {
                let separatorView = SoramitsuView()
                separatorView.heightAnchor.constraint(equalToConstant: 1).isActive = true
                separatorView.sora.backgroundColor = .bgPage
                stackView.addArrangedSubview(separatorView)
            }
        }
        
        
        if let assetView = detailsViews.last {
            stackView.setCustomSpacing(24, after: assetView)
        }

        stackView.addArrangedSubviews(supplyLiquidity, removeLiquidity)
        stackView.setCustomSpacing(16, after: supplyLiquidity)
    }
}

