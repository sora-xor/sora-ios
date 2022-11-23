import SoraSwiftUI

final class AssetsCell: SoramitsuTableViewCell {
    
    private var assetsItem: AssetsItem?
    
    private lazy var arrowButton: AssetHeaderView = {
        let button = AssetHeaderView()
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.assetsItem?.arrowButtonHandler?()
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
        view.layer.cornerRadius = 32
        view.sora.distribution = .fill
        view.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }()

    private let mainInfoStackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.sora.axis = .horizontal
        view.sora.distribution = .fill
        return view
    }()

    private lazy var openFullListAssetsButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .small, type: .text(.primary))
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
        
        mainInfoStackView.addArrangedSubviews(arrowButton, moneyLabel)
        mainInfoStackView.setCustomSpacing(16, after: arrowButton)
        fullStackView.addArrangedSubviews(mainInfoStackView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            fullStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            fullStackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            fullStackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            fullStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),

            openFullListAssetsButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
}

extension AssetsCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? AssetsItem else {
            assertionFailure("Incorect type of item")
            return
        }

        moneyLabel.sora.text = item.moneyText

        arrowButton.configure(title: item.title, isExpand: item.isExpand)

        fullStackView.arrangedSubviews.filter { $0 is AssetView || $0 is SoramitsuButton }.forEach { subview in
            fullStackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        let assetViews = item.assetViewModels.map { assetModel -> AssetView in
            let assetView = AssetView(type: .asset, mode: .view)

            assetModel.imageViewModel?.loadImage { (icon, _) in
                assetView.sora.firstAssetImage = icon
            }

            assetView.sora.titleText = assetModel.title
            assetView.sora.subtitleText = assetModel.subtitle
            assetView.sora.isHidden = !item.isExpand
            return assetView
        }

        fullStackView.addArrangedSubviews(assetViews)

        openFullListAssetsButton.sora.isHidden = !item.isExpand
        fullStackView.addArrangedSubviews(openFullListAssetsButton)

        assetsItem = item
    }
}

