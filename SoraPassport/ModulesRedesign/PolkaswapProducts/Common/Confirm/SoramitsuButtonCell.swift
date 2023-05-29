import SoraUIKit

final class SoramitsuButtonCell: SoramitsuTableViewCell {
    
    var buttonItem: SoramitsuButtonItem?
    
    private lazy var button: SoramitsuButton = {
        let button = SoramitsuButton()
        button.sora.horizontalOffset = 0
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .additionalPolkaswap
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.buttonItem?.handler?()
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
        contentView.addSubview(button)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            button.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            button.topAnchor.constraint(equalTo: contentView.topAnchor),
            button.heightAnchor.constraint(equalToConstant: 56),
            button.centerXAnchor.constraint(equalTo: contentView.centerXAnchor)
        ])
    }
}

extension SoramitsuButtonCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? SoramitsuButtonItem else {
            assertionFailure("Incorect type of item")
            return
        }

        buttonItem = item
        button.sora.isEnabled = item.isEnable
        if let color = item.buttonBackgroudColor, item.isEnable {
            button.sora.backgroundColor = color
        }
        button.sora.attributedText = item.title.attributedString
    }
}

