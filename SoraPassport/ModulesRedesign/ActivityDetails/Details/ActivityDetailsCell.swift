import SoraUIKit

final class ActivityDetailsCell: SoramitsuTableViewCell {
    
    private var poolDetailsItem: ActivityDetailsItem?
    private var item: ActivityDetailsItem?
    
    private let stackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .bgSurface
        view.sora.axis = .vertical
        view.sora.cornerRadius = .max
        view.sora.distribution = .fill
        view.sora.shadow = .small
        view.spacing = 24
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
        contentView.addSubview(stackView)
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

extension ActivityDetailsCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? ActivityDetailsItem else {
            assertionFailure("Incorect type of item")
            return
        }
        self.item = item

        stackView.arrangedSubviews.filter { $0 is ActivityDetailView }.forEach { subview in
            stackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        
        let detailsViews = item.detailViewModels.map { detailModel -> ActivityDetailView in
            let view = ActivityDetailView()
            view.titleLabel.sora.text = detailModel.title
            view.valueLabel.sora.text = detailModel.value
            view.sora.addHandler(for: .touchUpInside) { [weak self] in
                self?.item?.copyToClipboardHander?(detailModel.value)
            }
            return view
        }
        
        detailsViews.forEach { view in
            stackView.addArrangedSubview(view)
        }
    }
}

