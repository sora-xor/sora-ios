import SoraUIKit
import SoraFoundation

final class AssetsCell: SoramitsuTableViewCell {
    
    private var assetsItem: AssetsItem?
    private var localizationManager = LocalizationManager.shared
    
    private let shimmerView: SoramitsuShimmerView = {
        let view = SoramitsuShimmerView()
        view.sora.cornerRadius = .max
        return view
    }()
    
    private lazy var arrowButton: WalletHeaderView = {
        let button = WalletHeaderView()
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.assetsItem?.arrowButtonHandler?()
        }
        return button
    }()

    private let moneyLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline2
        label.sora.textColor = .fgPrimary
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
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

    private let mainInfoView: UIView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.sora.axis = .horizontal
        view.sora.distribution = .fill
        return view
    }()

    private lazy var openFullListAssetsButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .extraSmall, type: .text(.primary))
        button.sora.horizontalOffset = 0
        button.sora.attributedText = SoramitsuTextItem(text: R.string.localizable.commonExpand(preferredLanguages: .currentLocale),
                                                       fontData: FontType.buttonM,
                                                       textColor: .accentPrimary,
                                                       alignment: .left)
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.assetsItem?.expandButtonHandler?()
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
        contentView.addSubview(fullStackView)
        contentView.addSubview(shimmerView)
        
        mainInfoView.addSubviews(arrowButton, moneyLabel)
        fullStackView.addArrangedSubviews(mainInfoView)
        fullStackView.setCustomSpacing(16, after: mainInfoView)
        
        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.commonExpand(preferredLanguages: locale.rLanguages)
        }
        
        localizationManager.addObserver(with: openFullListAssetsButton) { [weak openFullListAssetsButton, weak arrowButton] (_, _) in
            guard let assetsItem = self.assetsItem else { return }
            let currentTitle = localizableTitle.value(for: self.localizationManager.selectedLocale)
            arrowButton?.configure(title: assetsItem.title, isExpand: assetsItem.isExpand)
            openFullListAssetsButton?.sora.attributedText = SoramitsuTextItem(text: currentTitle,
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

extension AssetsCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? AssetsItem else {
            assertionFailure("Incorect type of item")
            return
        }
        assetsItem = item
        
        moneyLabel.sora.text = item.moneyText

        arrowButton.configure(title: item.title, isExpand: item.isExpand)

        fullStackView.arrangedSubviews.filter { $0 is AssetView || $0 is SoramitsuButton }.forEach { subview in
            fullStackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        let assetViews = item.assetViewModels.map { assetModel -> AssetView in
            let assetView = AssetView(mode: .view)
            assetView.sora.firstAssetImage = assetModel.icon
            assetView.sora.titleText = assetModel.title
            assetView.sora.subtitleText = assetModel.subtitle
            assetView.sora.isHidden = !item.isExpand
            assetView.sora.upAmountText = assetModel.fiatText
            assetView.tappableArea.sora.isHidden = false
            assetView.tappableArea.sora.addHandler(for: .touchUpInside) { [weak assetsItem] in
                assetsItem?.assetHandler?(assetModel.identifier)
            }
            return assetView
        }

        fullStackView.addArrangedSubviews(assetViews)
        
        if let assetView = assetViews.last {
            fullStackView.setCustomSpacing(8, after: assetView)
        }

        openFullListAssetsButton.sora.isHidden = !item.isExpand
        fullStackView.addArrangedSubviews(openFullListAssetsButton)
        shimmerView.sora.alpha = (assetsItem?.assetViewModels.isEmpty ?? true) ? 1 : 0
    }
}

