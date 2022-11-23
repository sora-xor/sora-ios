import UIKit
import Then
import Anchorage
import SoraUI

final class RewardRawCell: UITableViewCell {

    // MARK: - Outlets
    private var containerView: UIView = {
        ShadowShapeView().then {
            $0.fillColor = R.color.neumorphism.backgroundLightGrey() ?? .white
            $0.shadowOpacity = 0.3
            $0.shadowColor = UIColor(white: 0, alpha: 0.3)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }()
    
    private var titleLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .paragraph1)
            $0.textColor = R.color.baseContentPrimary()
            $0.lineBreakMode = .byTruncatingMiddle
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }()

    private var amountLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .paragraph1)
            $0.textColor = R.color.baseContentPrimary()
            $0.textAlignment = .right
            $0.lineBreakMode = .byTruncatingMiddle
            $0.translatesAutoresizingMaskIntoConstraints = false
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
        titleLabel.text = viewModel.title
        amountLabel.text = "\(viewModel.amount) " + viewModel.assetSymbol
    }
}

private extension RewardRawCell {

    func configure() {
        selectionStyle = .none
        backgroundColor = R.color.baseBackground()
        clipsToBounds = true

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
