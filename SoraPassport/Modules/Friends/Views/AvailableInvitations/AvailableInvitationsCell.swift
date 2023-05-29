import UIKit
import Then
import Anchorage
import SoraUI

protocol AvailableInvitationsCellDelegate: InvitationLinkViewDelegate {
    func changeBoundedAmount(to type: InputRewardAmountType)
}

final class AvailableInvitationsCell: UITableViewCell {

    private var delegate: AvailableInvitationsCellDelegate? {
        didSet {
            linkView.delegate = delegate
        }
    }

    // MARK: - Outlets
    private var containerView: UIView = {
        RoundedView().then {
            $0.fillColor = R.color.neumorphism.backgroundLightGrey() ?? .white
            $0.cornerRadius = 24
            $0.roundingCorners = [ .topLeft, .topRight, .bottomLeft, .bottomRight ]
            $0.shadowRadius = 3
            $0.shadowOpacity = 0.3
            $0.shadowOffset = CGSize(width: 0, height: -1)
            $0.shadowColor = UIColor(white: 0, alpha: 0.3)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }()

    private var titleLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .title4)
            $0.textColor = R.color.baseContentPrimary()
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.text = R.string.localizable.referralInvitationLinkTitle(preferredLanguages: .currentLocale)
        }
    }()

    private var amountInvitationsLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .title4)
            $0.textColor = R.color.baseContentPrimary()
            $0.textAlignment = .right
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }()

    private var linkView: InvitationLinkView = {
        InvitationLinkView().then {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.backgroundColor = R.color.neumorphism.buttonLightGrey()
        }
    }()

    private var bondedLabel: UILabel = {
        UILabel().then {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.font = UIFont.styled(for: .paragraph1)
            $0.textColor = R.color.baseContentPrimary()
            $0.text = R.string.localizable.walletBonded(preferredLanguages: .currentLocale)
        }
    }()

    private var xorLabel: UILabel = {
        UILabel().then {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.font = UIFont.styled(for: .paragraph1)
            $0.textAlignment = .right
            $0.lineBreakMode = .byTruncatingMiddle
            $0.textColor = R.color.baseContentPrimary()
        }
    }()

    private lazy var getInvitationButton: NeumorphismButton = {
        NeumorphismButton().then {
            if let color = R.color.neumorphism.tint() {
                $0.color = color
            }
            $0.heightAnchor == 56
            $0.tintColor = R.color.brandWhite()
            $0.font = UIFont.styled(for: .button)
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.forceUppercase = false
            $0.setTitle(R.string.localizable.referralGetMoreInvitationButtonTitle(preferredLanguages: .currentLocale), for: .normal)
            $0.addTarget(self, action: #selector(getInvitationButtonTapped), for: .touchUpInside)
        }
    }()
    
    private lazy var unbondXorButton: NeumorphismButton = {
        NeumorphismButton().then {
            if let color = R.color.neumorphism.shareButtonGrey() {
                $0.color = color
            }
            $0.heightAnchor == 56
            $0.setTitleColor(R.color.neumorphism.brown(), for: .normal) 
            $0.font = UIFont.styled(for: .button)
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.forceUppercase = false
            $0.setTitle(R.string.localizable.referralUnbondButtonTitle(preferredLanguages: .currentLocale), for: .normal)
            $0.addTarget(self, action: #selector(unbondXorButtonTapped), for: .touchUpInside)
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

extension AvailableInvitationsCell: Reusable {
    func bind(viewModel: CellViewModel) {
        guard let viewModel = viewModel as? AvailableInvitationsViewModel else { return }
        linkView.linkLabel.text = "polkaswap.io/#/referral/" + viewModel.accountAddress
        amountInvitationsLabel.text = "\(viewModel.invitationCount)"
        xorLabel.text = "\(viewModel.bondedAmount) XOR"
        delegate = viewModel.delegate
    }
}

private extension AvailableInvitationsCell {

    func configure() {
        selectionStyle = .none
        backgroundColor = R.color.baseBackground()

        contentView.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(amountInvitationsLabel)
        containerView.addSubview(linkView)
        containerView.addSubview(bondedLabel)
        containerView.addSubview(xorLabel)
        containerView.addSubview(getInvitationButton)
        containerView.addSubview(unbondXorButton)

        containerView.do {
            $0.topAnchor == contentView.topAnchor + 10
            $0.bottomAnchor == contentView.bottomAnchor - 6
            $0.centerXAnchor == contentView.centerXAnchor
            $0.leadingAnchor == contentView.leadingAnchor + 16
        }

        titleLabel.do {
            $0.topAnchor == containerView.topAnchor + 24
            $0.leadingAnchor == containerView.leadingAnchor + 24
            $0.widthAnchor >= 100
        }

        amountInvitationsLabel.do {
            $0.topAnchor == containerView.topAnchor + 24
            $0.leadingAnchor == titleLabel.trailingAnchor + 10
            $0.trailingAnchor == containerView.trailingAnchor - 24
        }

        linkView.do {
            $0.topAnchor == titleLabel.bottomAnchor + 16
            $0.leadingAnchor == containerView.leadingAnchor + 16
            $0.centerXAnchor == containerView.centerXAnchor
            $0.heightAnchor == 56
        }

        bondedLabel.do {
            $0.topAnchor == linkView.bottomAnchor + 16
            $0.leadingAnchor == containerView.leadingAnchor + 24
            $0.widthAnchor >= 100
        }

        xorLabel.do {
            $0.trailingAnchor == containerView.trailingAnchor - 24
            $0.leadingAnchor == bondedLabel.trailingAnchor + 10
            $0.centerYAnchor == bondedLabel.centerYAnchor
        }

        getInvitationButton.do {
            $0.topAnchor == bondedLabel.bottomAnchor + 24
            $0.leadingAnchor == containerView.leadingAnchor + 24
            $0.centerXAnchor == containerView.centerXAnchor
            $0.heightAnchor == 56
        }

        unbondXorButton.do {
            $0.topAnchor == getInvitationButton.bottomAnchor + 16
            $0.leadingAnchor == containerView.leadingAnchor + 24
            $0.centerXAnchor == containerView.centerXAnchor
            $0.heightAnchor == 56
            $0.bottomAnchor == containerView.bottomAnchor - 24
        }
    }

    @objc
    func getInvitationButtonTapped() {
        delegate?.changeBoundedAmount(to: .bond)
    }

    @objc
    func unbondXorButtonTapped() {
        delegate?.changeBoundedAmount(to: .unbond)
    }
}
