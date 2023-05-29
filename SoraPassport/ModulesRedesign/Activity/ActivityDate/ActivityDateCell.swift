import SoraUIKit

final class ActivityDateCell: SoramitsuTableViewCell {

    private var assetItem: ActivityDateItem?
    private var topConstaint: NSLayoutConstraint?
    
    private let containerView: SoramitsuView = {
        let label = SoramitsuView()
        label.sora.backgroundColor = .bgSurface
        return label
    }()
    
    private let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline4
        label.sora.textColor = .fgSecondary
        label.sora.backgroundColor = .bgSurface
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
        contentView.addSubview(containerView)
        contentView.addSubview(titleLabel)
    }

    private func setupConstraints() {
        let topConstaint = titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 32)
        self.topConstaint = topConstaint
        
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            topConstaint,
        ])
    }
}

extension ActivityDateCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? ActivityDateItem else {
            assertionFailure("Incorect type of item")
            return
        }

        titleLabel.sora.text = item.text.uppercased()
        topConstaint?.constant =  item.isFirstSection ? 32 : 8
        containerView.sora.cornerMask = item.isFirstSection ? .top : .none
        containerView.sora.cornerRadius = item.isFirstSection ? .extraLarge : .zero
    }
}

