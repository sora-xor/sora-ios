import SoraUIKit

final class PriceCell: SoramitsuTableViewCell {
    
    private let containerView: SoramitsuView = {
        var view = SoramitsuView()
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerRadius = .max
        view.sora.shadow = .small
        return view
    }()
    
    private let stackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.axis = .vertical
        view.sora.cornerRadius = .max
        view.sora.distribution = .fill
        view.sora.alignment = .center
        view.spacing = 8
        view.layoutMargins = UIEdgeInsets(top: 0, left: 24, bottom: 24, right: 24)
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }()

    let oneCurrencyImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 72).isActive = true
        view.widthAnchor.constraint(equalToConstant: 72).isActive = true
        return view
    }()
    
    let symbolLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.textColor = .fgSecondary
        label.sora.font = FontType.textBoldXS
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()
    
    let ecosystemLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.textColor = .fgPrimary
        label.sora.font = FontType.headline1
        return label
    }()
    
    private let priceLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline3
        label.sora.textColor = .fgSecondary
        return label
    }()

    private var assetView = AssetView(mode: .view)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupView() {
        stackView.addArrangedSubviews(oneCurrencyImageView, symbolLabel, ecosystemLabel, priceLabel)
        contentView.addSubviews(containerView, stackView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: stackView.bottomAnchor),
            containerView.topAnchor.constraint(equalTo: stackView.topAnchor, constant: 36),
            
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
        ])
    }
}

extension PriceCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? PriceItem else {
            assertionFailure("Incorect type of item")
            return
        }

        oneCurrencyImageView.image = item.assetViewModel.icon
        symbolLabel.sora.text = item.assetViewModel.subtitle
        ecosystemLabel.sora.text = item.assetViewModel.title
        priceLabel.sora.text = item.assetViewModel.fiatText
    }
}

