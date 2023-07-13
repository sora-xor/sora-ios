import UIKit
import SoraUIKit
import Then
import Anchorage

final class FeeCell: UITableViewCell {

    // MARK: - Outlets
    private var titleLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.textColor = .fgSecondary
            $0.sora.font = FontType.textBoldXS
            $0.sora.numberOfLines = 0
        }
    }()
    
    private var infoButton: ImageButton = {
        ImageButton(size: CGSize(width: 14, height: 14)).then {
            $0.sora.image = R.image.wallet.info()
        }
    }()
    
    private var feeLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.textColor = .fgPrimary
            $0.sora.font = FontType.textS
            $0.sora.numberOfLines = 0
        }
    }()

    // MARK: - Init

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configure()
    }
}

extension FeeCell: Reusable {
    func bind(viewModel: CellViewModel) {
        guard let viewModel = viewModel as? FeeViewModel else { return }
        titleLabel.sora.text = viewModel.title
        feeLabel.sora.text = viewModel.feeAmount
    }
}

private extension FeeCell {

    func configure() {
        selectionStyle = .none
        backgroundColor = .clear

        contentView.addSubview(titleLabel)
        contentView.addSubview(infoButton)
        contentView.addSubview(feeLabel)

        titleLabel.do {
            $0.centerYAnchor == contentView.centerYAnchor
            $0.leadingAnchor == contentView.leadingAnchor + 24
        }
        
        infoButton.do {
            $0.centerYAnchor == contentView.centerYAnchor
            $0.leadingAnchor == titleLabel.trailingAnchor + 5
        }
        
        feeLabel.do {
            $0.topAnchor == contentView.topAnchor
            $0.centerYAnchor == contentView.centerYAnchor
            $0.trailingAnchor == contentView.trailingAnchor - 24
        }
    }
}

