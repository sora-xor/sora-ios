import SoraUIKit
import Anchorage
import FearlessUtils

final class ContactCell: SoramitsuTableViewCell {
    private let generator = PolkadotIconGenerator()
    
    private let contactView: ContactView = ContactView()
    
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
        contactView.sora.shadow = .small
        contentView.addSubview(contactView)
    }
    
    func setupConstraints() {
        
        NSLayoutConstraint.activate([
            contactView.topAnchor.constraint(equalTo: contentView.topAnchor),
            contactView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            contactView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            contactView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
        ])
    }
}

extension ContactCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? ContactCellItem else {
            return
        }
        contactView.accountTitle.sora.text = item.title
        contactView.accountImageView.image = try? generator.generateFromAddress(item.title)
            .imageWithFillColor(.white,
                                size: CGSize(width: 40.0, height: 40.0),
                                contentScale: UIScreen.main.scale)
    }
}
