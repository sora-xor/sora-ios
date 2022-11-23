/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import Then
import Anchorage
import SoraUI

protocol TotalRewardsCellDelegate: AnyObject {
    func expandButtonTapped()
}

final class TotalRewardsCell: UITableViewCell {

    weak var delegate: TotalRewardsCellDelegate?

    private var rotated: Bool = false

    // MARK: - Outlets
    private var containerView: UIView = {
        RoundedView().then {
            $0.fillColor = R.color.neumorphism.backgroundLightGrey() ?? .white
            $0.cornerRadius = 24
            $0.roundingCorners = [ .topLeft, .topRight ]
            $0.shadowRadius = 3
            $0.shadowOpacity = 0.3
            $0.shadowOffset = CGSize(width: 1, height: 0)
            $0.shadowColor = UIColor(white: 0, alpha: 0.3)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }()
    
    private var titleLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .title4)
            $0.textColor = R.color.baseContentPrimary()
            $0.numberOfLines = 0
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.text = R.string.localizable.referralYourReferrals(preferredLanguages: .currentLocale)
        }
    }()

    lazy var expandLabelButton: UIButton = {
        let view = UIButton()
        view.addTarget(self, action: #selector(expandButtonTap), for: .touchUpInside)
        return view
    }()
    
    private var amountInvitationsLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .title4)
            $0.textColor = R.color.baseContentPrimary()
            $0.textAlignment = .right
            $0.numberOfLines = 0
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }()
    
    private var bondedLabel: UILabel = {
        UILabel().then {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.font = UIFont.styled(for: .paragraph1)
            $0.textColor = R.color.baseContentPrimary()
            $0.text = R.string.localizable.referralTotalRewards(preferredLanguages: .currentLocale)
        }
    }()

    private var xorLabel: UILabel = {
        UILabel().then {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.font = UIFont.styled(for: .paragraph1)
            $0.textColor = R.color.baseContentPrimary()
            $0.lineBreakMode = .byTruncatingMiddle
        }
    }()

    lazy var expandButton: UIButton = {
        let view = UIButton()
        view.transform = CGAffineTransform(rotationAngle: .pi)
        view.setImage(R.image.arrow(), for: .normal)
        view.addTarget(self, action: #selector(expandButtonTap), for: .touchUpInside)
        return view
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
            self.expandButton.transform = self.rotated ? CGAffineTransform.identity : CGAffineTransform(rotationAngle: .pi)
        }

        delegate?.expandButtonTapped()
    }
}

extension TotalRewardsCell: Reusable {
    func bind(viewModel: CellViewModel) {
        guard let viewModel = viewModel as? TotalRewardsViewModel else { return }
        amountInvitationsLabel.text = "\(viewModel.invetationCount)"
        xorLabel.text = "\(viewModel.totalRewardsAmount) " + viewModel.assetSymbol
        delegate = viewModel.delegate
    }
}

private extension TotalRewardsCell {

    func configure() {
        selectionStyle = .none
        backgroundColor = R.color.baseBackground()
        clipsToBounds = true

        contentView.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(amountInvitationsLabel)
        containerView.addSubview(bondedLabel)
        containerView.addSubview(xorLabel)
        containerView.addSubview(expandButton)
        containerView.addSubview(expandLabelButton)

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
            $0.heightAnchor == 24
            $0.widthAnchor == 24
            $0.leadingAnchor == titleLabel.trailingAnchor + 8
            $0.centerYAnchor == titleLabel.centerYAnchor
        }

        expandLabelButton.do {
            $0.topAnchor == amountInvitationsLabel.topAnchor
            $0.leadingAnchor == amountInvitationsLabel.leadingAnchor
            $0.centerYAnchor == amountInvitationsLabel.centerYAnchor
            $0.centerXAnchor == amountInvitationsLabel.centerXAnchor
        }

        amountInvitationsLabel.do {
            $0.topAnchor == containerView.topAnchor + 24
            $0.trailingAnchor == containerView.trailingAnchor - 24
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
    }
}
