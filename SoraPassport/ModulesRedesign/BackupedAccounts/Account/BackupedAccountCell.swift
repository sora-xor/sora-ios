import SoraUIKit
import Anchorage
import FearlessUtils

final class BackupedAccountCell: SoramitsuTableViewCell {
    private let generator = PolkadotIconGenerator()
    
    private let accountView: AccountView = AccountView()
    
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
        contentView.addSubview(accountView)
    }
    
    func setupConstraints() {
        NSLayoutConstraint.activate([
            accountView.topAnchor.constraint(equalTo: contentView.topAnchor),
            accountView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            accountView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            accountView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
        ])
    }
}

extension BackupedAccountCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? BackupedAccountItem else {
            return
        }
        accountView.sora.cornerMask = item.config.cornerMask
        accountView.sora.cornerRadius = item.config.cornerRaduis
        accountView.accountTitle.sora.text = item.accountName
        accountView.accountTitle.sora.isHidden = item.accountName?.isEmpty ?? true
        accountView.accountAddress.sora.text = item.accountAddress
        accountView.topConstraint?.constant = item.config.topOffset
        accountView.bottomConstraint?.constant = item.config.bottomOffset
        accountView.accountImageView.image = try? generator.generateFromAddress(item.accountAddress)
            .imageWithFillColor(.white,
                                size: CGSize(width: 40.0, height: 40.0),
                                contentScale: UIScreen.main.scale)
    }
}
