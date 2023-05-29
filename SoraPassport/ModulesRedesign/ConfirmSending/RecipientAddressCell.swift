import SoraUIKit
import UIKit
import FearlessUtils

final class RecipientAddressCell: SoramitsuTableViewCell {
    private let generator = PolkadotIconGenerator()
    public lazy var recipientView = RecipientAddressView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupView() {
        recipientView.contactView.arrowImageView.isHidden = true
        contentView.addSubviews(recipientView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            recipientView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            recipientView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            recipientView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            recipientView.topAnchor.constraint(equalTo: contentView.topAnchor),
        ])
    }
}

extension RecipientAddressCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? RecipientAddressItem else {
            assertionFailure("Incorect type of item")
            return
        }
        
        recipientView.contactView.accountTitle.sora.text = item.address
        recipientView.contactView.accountImageView.image = try? generator.generateFromAddress(item.address)
            .imageWithFillColor(.white,
                                size: CGSize(width: 40.0, height: 40.0),
                                contentScale: UIScreen.main.scale)
    }
}

