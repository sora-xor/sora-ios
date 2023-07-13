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
    
    public let limitationLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphBoldXS
        label.sora.textColor = .fgSecondary
        label.sora.text = R.string.localizable.polkaswapFarmingUnstakeToRemove(preferredLanguages: .currentLocale)
        label.sora.alignment = .center
        label.sora.numberOfLines = 0
        return label
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
            stackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
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
        
        removeLiquidity.sora.isEnabled = item.isRemoveLiquidityEnabled
        
        let titleColor: SoramitsuColor = item.isRemoveLiquidityEnabled ? .additionalPolkaswap : .fgTertiary
        removeLiquidity.sora.attributedText = SoramitsuTextItem(text: R.string.localizable.commonRemove(preferredLanguages: .currentLocale),
                                                                fontData: FontType.buttonM ,
                                                                textColor: titleColor,
                                                                alignment: .center)
        removeLiquidity.sora.backgroundColor = item.isRemoveLiquidityEnabled ? .additionalPolkaswapContainer : .bgSurfaceVariant

        headerView.titleLabel.sora.text = item.title

        DispatchQueue.global(qos: .userInitiated).async {
            let icon = RemoteSerializer.shared.image(with: item.firstAssetImage ?? "")
            DispatchQueue.main.async {
                self.headerView.firstCurrencyImageView.image = icon
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let icon = RemoteSerializer.shared.image(with: item.secondAssetImage ?? "")
            DispatchQueue.main.async {
                self.headerView.secondCurrencyImageView.image = icon
            }
        }
    
        DispatchQueue.global(qos: .userInitiated).async {
            let icon = RemoteSerializer.shared.image(with: item.rewardAssetImage ?? "")
            DispatchQueue.main.async {
                self.headerView.rewardImageView.image = icon
            }
        }

        stackView.arrangedSubviews.filter { $0 is DetailView || $0 is SoramitsuButton || $0 is SoramitsuView }.forEach { subview in
            stackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        stackView.removeArrangedSubview(limitationLabel)
        
        let detailsViews = item.detailsViewModel.map { detailModel -> DetailView in
            let view = DetailView()

            view.assetImageView.isHidden = detailModel.rewardAssetImage == nil
            DispatchQueue.global(qos: .userInitiated).async {
                let icon = RemoteSerializer.shared.image(with: detailModel.rewardAssetImage ?? "")
                DispatchQueue.main.async {
                    view.assetImageView.image = icon
                }
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
        stackView.setCustomSpacing(16, after: removeLiquidity)
        
        stackView.addArrangedSubview(limitationLabel)
        limitationLabel.sora.isHidden = item.isRemoveLiquidityEnabled
    }
}

