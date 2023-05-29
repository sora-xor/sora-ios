import SoraUIKit
import Anchorage
import FearlessUtils

final class ContactHeaderCell: SoramitsuTableViewCell {
    
    private let containerView: SoramitsuView = {
        let view = SoramitsuView()
        view.sora.shadow = .small
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerMask = .top
        view.sora.cornerRadius = .max
        return view
    }()

    private let accountTitle: SoramitsuLabel = {
        var label = SoramitsuLabel()
        label.sora.textColor = .fgSecondary
        label.sora.font = FontType.headline4
        label.sora.numberOfLines = 2
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        sora.clipsToBounds = true
        contentView.addSubview(containerView)
        containerView.addSubview(accountTitle)
    }
    
    func setupConstraints() {
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 15),
            containerView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            containerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            accountTitle.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            accountTitle.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            accountTitle.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            accountTitle.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -8),
        ])
    }
}

extension ContactHeaderCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? ContactHeaderCellItem else {
            return
        }
        accountTitle.sora.text = item.title
    }
}
