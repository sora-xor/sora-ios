import UIKit
import Then
import Anchorage
import SoraUI
import SoraUIKit

protocol TotalRewardsCellDelegate: AnyObject {
    func expandButtonTapped()
}

final class TotalRewardsCell: SoramitsuTableViewCell {

    weak var delegate: TotalRewardsCellDelegate?

    private var rotated: Bool = false

    // MARK: - Outlets
    private var containerView: SoramitsuView = {
        SoramitsuView().then {
            $0.sora.backgroundColor = .bgSurface
            $0.sora.cornerRadius = .max
            $0.sora.cornerMask = .top
        }
    }()
    
    private var titleLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.text = R.string.localizable.referralYourReferrals(preferredLanguages: .currentLocale)
            $0.sora.textColor = .fgPrimary
            $0.sora.font = FontType.headline2
            $0.sora.numberOfLines = 0
        }
    }()
    
    private var amountInvitationsLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.textColor = .fgPrimary
            $0.sora.alignment = .right
            $0.sora.font = FontType.headline2
            $0.sora.numberOfLines = 0
        }
    }()
    
    private var bondedLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.text = R.string.localizable.referralTotalRewards(preferredLanguages: .currentLocale)
            $0.sora.textColor = .fgPrimary
            $0.sora.font = FontType.textM
        }
    }()

    private var xorLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.textColor = .fgPrimary
            $0.sora.font = FontType.textM
            $0.sora.lineBreakMode = .byTruncatingMiddle
        }
    }()

    private lazy var expandButton: ImageButton = {
        ImageButton(size: CGSize(width: 24, height: 24)).then {
            $0.sora.image = R.image.arrow()
            $0.sora.transform = CGAffineTransform(rotationAngle: .pi)
        }
    }()
    
    private lazy var expandableArea: SoramitsuControl = {
        SoramitsuControl().then {
            $0.sora.backgroundColor = .custom(uiColor: .clear)
            $0.sora.isHidden = true
            $0.sora.addHandler(for: .touchUpInside) { [weak self] in
                self?.expandButtonTap()
            }
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

    @objc
    func expandButtonTap() {
        rotated = !rotated

        UIView.animate(withDuration: 0.3) {
            self.expandButton.sora.transform = self.rotated ? CGAffineTransform.identity : CGAffineTransform(rotationAngle: .pi)
        }

        delegate?.expandButtonTapped()
    }
}

extension TotalRewardsCell: Reusable {
    func bind(viewModel: CellViewModel) {
        guard let viewModel = viewModel as? TotalRewardsViewModel else { return }
        amountInvitationsLabel.sora.text = "\(viewModel.invetationCount)"
        xorLabel.sora.text = "\(viewModel.totalRewardsAmount) " + viewModel.assetSymbol
        expandableArea.sora.isHidden = false
        delegate = viewModel.delegate
    }
}

private extension TotalRewardsCell {

    func configure() {
        sora.backgroundColor = .custom(uiColor: .clear)
        sora.selectionStyle = .none
        sora.clipsToBounds = true

        contentView.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(amountInvitationsLabel)
        containerView.addSubview(bondedLabel)
        containerView.addSubview(xorLabel)
        containerView.addSubview(expandButton)
        containerView.addSubview(expandableArea)

        containerView.do {
            $0.topAnchor == contentView.topAnchor + 10
            $0.bottomAnchor == contentView.bottomAnchor
            $0.centerXAnchor == contentView.centerXAnchor
            $0.leadingAnchor == contentView.leadingAnchor + 16
        }

        titleLabel.do {
            $0.topAnchor == containerView.topAnchor + 24
            $0.leadingAnchor == containerView.leadingAnchor + 24
        }

        expandButton.do {
            $0.leadingAnchor == titleLabel.trailingAnchor + 8
            $0.centerYAnchor == titleLabel.centerYAnchor
        }

        amountInvitationsLabel.do {
            $0.topAnchor == containerView.topAnchor + 24
            $0.trailingAnchor == containerView.trailingAnchor - 24
            $0.heightAnchor == titleLabel.heightAnchor
        }

        bondedLabel.do {
            $0.topAnchor == titleLabel.bottomAnchor + 16
            $0.leadingAnchor == containerView.leadingAnchor + 24
            $0.bottomAnchor == containerView.bottomAnchor - 8
            $0.widthAnchor >= 100
        }

        xorLabel.do {
            $0.trailingAnchor == containerView.trailingAnchor - 24
            $0.leadingAnchor == bondedLabel.trailingAnchor + 10
            $0.centerYAnchor == bondedLabel.centerYAnchor
        }
        
        expandableArea.do {
            $0.edgeAnchors == containerView.edgeAnchors
        }
    }
}
