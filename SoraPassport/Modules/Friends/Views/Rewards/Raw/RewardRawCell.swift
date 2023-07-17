import UIKit
import Then
import Anchorage
import SoraUI
import SoraUIKit

final class RewardRawCell: SoramitsuTableViewCell {

    // MARK: - Outlets
    private var containerView: SoramitsuView = {
        SoramitsuView().then {
            $0.sora.backgroundColor = .bgSurface
        }
    }()
    
    private var titleLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.textColor = .fgPrimary
            $0.sora.font = FontType.textM
            $0.sora.lineBreakMode = .byTruncatingMiddle
        }
    }()

    private var amountLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.textColor = .fgPrimary
            $0.sora.alignment = .right
            $0.sora.font = FontType.textM
            $0.sora.lineBreakMode = .byTruncatingMiddle
            $0.setContentCompressionResistancePriority(.required, for: .horizontal)
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

    override func layoutSubviews() {
        super.layoutSubviews()

        var path = UIBezierPath()

        path.append(UIBezierPath(rect: CGRect(x: -3,
                                              y: 0,
                                              width: 3,
                                              height: containerView.bounds.height + 10)))

        path.append(UIBezierPath(rect: CGRect(x: containerView.bounds.width + 3,
                                              y: 0,
                                              width: 3,
                                              height: containerView.bounds.height + 10)))

        containerView.layer.shadowPath = path.cgPath
    }
}

extension RewardRawCell: Reusable {
    func bind(viewModel: CellViewModel) {
        guard let viewModel = viewModel as? RewardRawViewModel else { return }
        titleLabel.sora.text = viewModel.title
        amountLabel.sora.text = "\(viewModel.amount) " + viewModel.assetSymbol
    }
}

private extension RewardRawCell {

    func configure() {
        sora.backgroundColor = .custom(uiColor: .clear)
        sora.selectionStyle = .none
        sora.clipsToBounds = true

        contentView.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(amountLabel)

        containerView.do {
            $0.topAnchor == contentView.topAnchor
            $0.bottomAnchor == contentView.bottomAnchor
            $0.centerXAnchor == contentView.centerXAnchor
            $0.heightAnchor == 40
            $0.leadingAnchor == contentView.leadingAnchor + 16
        }

        titleLabel.do {
            $0.centerYAnchor == containerView.centerYAnchor
            $0.leadingAnchor == containerView.leadingAnchor + 24
            $0.trailingAnchor == amountLabel.leadingAnchor - 20
            $0.widthAnchor >= 100
        }

        amountLabel.do {
            $0.centerYAnchor == containerView.centerYAnchor
            $0.trailingAnchor == containerView.trailingAnchor - 24
        }
    }
}
