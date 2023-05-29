import SoraUIKit

final class RecentActivityCell: SoramitsuTableViewCell {
    
    private var activityItem: RecentActivityItem?

    private let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline2
        label.sora.textColor = .fgPrimary
        label.sora.text = R.string.localizable.assetDetailsRecentActivity(preferredLanguages: .currentLocale)
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

    private lazy var openFullActivityButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .small, type: .text(.primary))
        button.sora.horizontalOffset = 0
        button.sora.attributedText = SoramitsuTextItem(text: R.string.localizable.showMore(preferredLanguages: .currentLocale),
                                                       fontData: FontType.buttonM,
                                                       textColor: .accentPrimary,
                                                       alignment: .left)
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.activityItem?.openFullActivityHandler?()
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
        fullStackView.addArrangedSubviews(titleLabel)
        fullStackView.setCustomSpacing(16, after: titleLabel)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            fullStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            fullStackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            fullStackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            fullStackView.topAnchor.constraint(equalTo: contentView.topAnchor),

            openFullActivityButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
}

extension RecentActivityCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? RecentActivityItem else {
            assertionFailure("Incorect type of item")
            return
        }
        
        fullStackView.arrangedSubviews.filter { $0 is HistoryTransactionView || $0 is SoramitsuButton }.forEach { subview in
            fullStackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        
        let assetViews = item.historyViewModels.map { model -> HistoryTransactionView in
            let view = HistoryTransactionView()
            view.isUserInteractionEnabled = true
            model.firstAssetImageViewModel?.loadImage { (icon, _) in
                view.sora.firstHistoryTransactionImage  = icon
            }
            
            model.secondAssetImageViewModel?.loadImage { (icon, _) in
                view.sora.secondHistoryTransactionImage = icon
            }

            view.sora.titleText = model.title
            view.sora.subtitleText = model.subtitle
            view.sora.transactionType = model.typeTransactionImage
            view.sora.upAmountText = model.firstBalanceText
            view.sora.fiatText = model.fiatText
            view.sora.isNeedTwoTokens = model.isNeedTwoImage
            view.sora.statusImage = model.status.image
            view.sora.addHandler(for: .touchUpInside) {
                item.openActivityDetailsHandler?(model.txHash)
            }
            return view
        }

        fullStackView.addArrangedSubviews(assetViews)
        if let assetView = assetViews.last {
            fullStackView.setCustomSpacing(8, after: assetView)
        }

        fullStackView.addArrangedSubviews(openFullActivityButton)

        self.activityItem = item
    }
}

