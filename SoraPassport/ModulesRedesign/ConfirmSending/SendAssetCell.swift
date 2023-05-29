import SoraUIKit
import UIKit
import FearlessUtils

final class SendAssetCell: SoramitsuTableViewCell {
    
    private let sendAssetView: SendAssetView = SendAssetView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupView() {
        contentView.addSubviews(sendAssetView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            sendAssetView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            sendAssetView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            sendAssetView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            sendAssetView.topAnchor.constraint(equalTo: contentView.topAnchor),
        ])
    }
}

extension SendAssetCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? SendAssetItem else {
            assertionFailure("Incorect type of item")
            return
        }
        
        item.imageViewModel?.loadImage { [weak self] (icon, _) in
            self?.sendAssetView.assetImageView.image = icon
        }

        sendAssetView.symbolLabel.sora.text = item.symbol
        sendAssetView.balanceLabel.sora.text = item.balance
        sendAssetView.amountLabel.sora.text = item.amount
        sendAssetView.fiatLabel.sora.text = item.fiat
    }
}

