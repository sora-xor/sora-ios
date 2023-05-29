import SoraUIKit
import Anchorage
import FearlessUtils

final class ContactFooterCell: SoramitsuTableViewCell {
    
    private let containerView: SoramitsuView = {
        let view = SoramitsuView()
        view.sora.shadow = .small
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerMask = .bottom
        view.sora.cornerRadius = .max
        return view
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
    }
    
    func setupConstraints() {
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 15),
            containerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            containerView.heightAnchor.constraint(equalToConstant: 48)
        ])
    }
}

extension ContactFooterCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? ContactFooterItem else {
            return
        }
    }
}
