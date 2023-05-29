import UIKit
import Then
import Anchorage
import SoraUI

final class RewardFooterCell: UITableViewCell {

    // MARK: - Outlets
    private var containerView: UIView = {
        RoundedView().then {
            $0.fillColor = R.color.neumorphism.backgroundLightGrey() ?? .white
            $0.roundingCorners = [ .bottomLeft, .bottomRight ]
            $0.cornerRadius = 100
            $0.shadowOpacity = 0.3
            $0.shadowOffset = CGSize(width: 0, height: -1)
            $0.shadowColor = UIColor(white: 0, alpha: 0.3)
            $0.translatesAutoresizingMaskIntoConstraints = false
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

extension RewardFooterCell: Reusable {
    func bind(viewModel: CellViewModel) {
        guard let viewModel = viewModel as? RewardFooterViewModel else { return }
//        containerView.roundingCorners = [ .topLeft, .topRight ]
    }
}

private extension RewardFooterCell {

    func configure() {
        selectionStyle = .none
        backgroundColor = R.color.baseBackground()
        clipsToBounds = true

        contentView.addSubview(containerView)

        containerView.do {
            $0.topAnchor == contentView.topAnchor - 24
            $0.bottomAnchor == contentView.bottomAnchor - 10
            $0.centerXAnchor == contentView.centerXAnchor
            $0.heightAnchor == 40
            $0.leadingAnchor == contentView.leadingAnchor + 16
        }
    }
}
