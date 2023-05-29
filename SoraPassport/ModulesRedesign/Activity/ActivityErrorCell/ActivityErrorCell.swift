import SoraUIKit

final class ActivityErrorCell: SoramitsuTableViewCell {

    private var errorItem: ActivityErrorItem?
    
    private let containerView: SoramitsuView = {
        let view = SoramitsuView()
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerMask = .top
        view.sora.cornerRadius = .extraLarge
        return view
    }()

    private lazy var errorView: ErrorView = {
        let title = SoramitsuTextItem(text: R.string.localizable.commonRefresh(preferredLanguages: .currentLocale),
                                      fontData: FontType.textBoldS,
                                      textColor: .fgSecondary,
                                      alignment: .center)
        
        let view = ErrorView()
        view.titleLabel.sora.text = R.string.localizable.activityDataNotUpToDateTitle(preferredLanguages: .currentLocale)
        view.button.sora.attributedText = title
        view.button.sora.associate(states: .pressed) { [weak self] _ in
            self?.errorItem?.handler?()
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
        contentView.addSubview(containerView)
        contentView.addSubview(errorView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            
            errorView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            errorView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            errorView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            errorView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
        ])
    }
}

extension ActivityErrorCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? ActivityErrorItem else {
            assertionFailure("Incorect type of item")
            return
        }

        errorItem = item
    }
}

