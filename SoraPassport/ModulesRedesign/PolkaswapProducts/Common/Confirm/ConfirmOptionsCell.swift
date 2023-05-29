import SoraUIKit

final class ConfirmOptionsCell: SoramitsuTableViewCell {
    
    private lazy var optionsView: OptionsView = {
        let view = OptionsView()
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.marketLabel.sora.isHidden = true
        view.marketButton.sora.isHidden = true
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
        contentView.addSubview(optionsView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            optionsView.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 16),
            optionsView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            optionsView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            optionsView.topAnchor.constraint(equalTo: contentView.topAnchor),
        ])
    }
}

extension ConfirmOptionsCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? ConfirmOptionsItem else {
            assertionFailure("Incorect type of item")
            return
        }
        
        optionsView.slipageButton.sora.title = item.toleranceText
        optionsView.marketButton.sora.title = item.market?.titleForLocale(.current)
        optionsView.marketLabel.sora.isHidden = item.market == nil
        optionsView.marketButton.sora.isHidden = item.market == nil
    }
}

