import SoraUIKit

final class AccountCell: SoramitsuTableViewCell {
    
    private var accountItem: AccountTableViewItem?
    
    private let accountLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.sora.font = FontType.displayS
        label.sora.textColor = .fgPrimary
        label.sora.lineBreakMode = .byTruncatingMiddle
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()

    private let arrowImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.image = R.image.wallet.rightArrow()
        view.sora.tintColor = .fgPrimary
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        return view
    }()
    
    private lazy var button: SoramitsuControl = {
        let view = SoramitsuControl()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.sora.addHandler(for: .touchUpInside) { [weak self] in
            guard let item = self?.accountItem else { return }
            self?.accountItem?.accountHandler?(item)
        }
        return view
    }()
    
    private lazy var scanQrButton: ImageButton = {
        let view = ImageButton(size: CGSize(width: 40, height: 40))
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.tintColor = .accentTertiary
        view.sora.backgroundColor = .bgSurface
        view.sora.shadow = .small
        view.sora.image = R.image.wallet.qrScan()
        view.sora.cornerRadius = .circle
        view.sora.clipsToBounds = false
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        view.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.accountItem?.scanQRHandler?()
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
        clipsToBounds = false
        contentView.clipsToBounds = false
        contentView.addSubview(accountLabel)
        contentView.addSubview(arrowImageView)
        contentView.addSubview(scanQrButton)
        contentView.addSubview(button)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            accountLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            accountLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            arrowImageView.leadingAnchor.constraint(equalTo: accountLabel.trailingAnchor, constant: 12),
            arrowImageView.centerYAnchor.constraint(equalTo: accountLabel.centerYAnchor),
            arrowImageView.heightAnchor.constraint(equalToConstant: 16),
            arrowImageView.widthAnchor.constraint(equalToConstant: 16),
            arrowImageView.trailingAnchor.constraint(lessThanOrEqualTo: scanQrButton.leadingAnchor, constant: -12),
            
            button.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: arrowImageView.trailingAnchor),
            button.topAnchor.constraint(equalTo: contentView.topAnchor),
            button.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            scanQrButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            scanQrButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            scanQrButton.topAnchor.constraint(equalTo: contentView.topAnchor),
        ])
    }
}

extension AccountCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? AccountTableViewItem else {
            assertionFailure("Incorect type of item")
            return
        }

        accountItem = item
        accountLabel.sora.text = item.accountName
    }
}

