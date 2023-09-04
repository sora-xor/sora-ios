import UIKit
import Then
import Anchorage
import SoraUI
import SoraUIKit

final class RewardFooterCell: SoramitsuTableViewCell {

    // MARK: - Outlets
    private var containerView: SoramitsuView = {
        SoramitsuView().then {
            $0.sora.backgroundColor = .bgSurface
            $0.sora.cornerRadius = .max
            $0.sora.cornerMask = .bottom
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
    }
}

private extension RewardFooterCell {

    func configure() {
        sora.backgroundColor = .custom(uiColor: .clear)
        sora.selectionStyle = .none
        sora.clipsToBounds = true

        contentView.addSubview(containerView)

        containerView.do {
            $0.topAnchor == contentView.topAnchor - 24
            $0.bottomAnchor == contentView.bottomAnchor - 10
            $0.centerXAnchor == contentView.centerXAnchor
            $0.heightAnchor == 50
            $0.leadingAnchor == contentView.leadingAnchor + 16
        }
    }
}
