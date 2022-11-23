/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import Then
import Anchorage
import SoraUI

protocol ReferrerCellDelegate: AnyObject {
    func enterLinkButtonTapped()
}

final class ReferrerCell: UITableViewCell {

    private var delegate: ReferrerCellDelegate?

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
            $0.text = R.string.localizable.referralYourReferrer(preferredLanguages: .currentLocale)
        }
    }()
    
    private var subtitleLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .paragraph3)
            $0.textColor = R.color.neumorphism.textGray()
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.text = R.string.localizable.referralReferrerAddress(preferredLanguages: .currentLocale)
        }
    }()

    private var addressLabel: UILabel = {
        UILabel().then {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.font = UIFont.styled(for: .paragraph1)
            $0.textColor = R.color.baseContentPrimary()
            $0.lineBreakMode = .byTruncatingMiddle
        }
    }()

    private var enterLinkButton: NeumorphismButton = {
        NeumorphismButton().then {
            if let color = R.color.neumorphism.shareButtonGrey() {
                $0.color = color
            }
            $0.heightAnchor == 56
            $0.setTitleColor(R.color.neumorphism.brown(), for: .normal)
            $0.font = UIFont.styled(for: .button)
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.forceUppercase = false
            $0.setTitle(R.string.localizable.referralReferralLink(preferredLanguages: .currentLocale), for: .normal)
            $0.addTarget(nil, action: #selector(enterLinkButtonTapped), for: .touchUpInside)
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
    func enterLinkButtonTapped() {
        delegate?.enterLinkButtonTapped()
    }
}

extension ReferrerCell: Reusable {
    func bind(viewModel: CellViewModel) {
        guard let viewModel = viewModel as? ReferrerViewModel else { return }

        addressLabel.text = viewModel.address
        addressLabel.isHidden = viewModel.address.isEmpty
        subtitleLabel.isHidden = viewModel.address.isEmpty
        enterLinkButton.isHidden = !viewModel.address.isEmpty
        delegate = viewModel.delegate
    }
}

private extension ReferrerCell {

    func configure() {
        backgroundColor = R.color.baseBackground()
        selectionStyle = .none

        contentView.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)
        containerView.addSubview(addressLabel)
        containerView.addSubview(enterLinkButton)

        containerView.do {
            $0.topAnchor == contentView.topAnchor + 6
            $0.bottomAnchor == contentView.bottomAnchor - 10
            $0.centerXAnchor == contentView.centerXAnchor
            $0.leadingAnchor == contentView.leadingAnchor + 16
        }

        titleLabel.do {
            $0.topAnchor == containerView.topAnchor + 24
            $0.leadingAnchor == containerView.leadingAnchor + 24
            $0.centerXAnchor == containerView.centerXAnchor
        }

        subtitleLabel.do {
            $0.topAnchor == titleLabel.bottomAnchor + 16
            $0.leadingAnchor == containerView.leadingAnchor + 24
            $0.centerXAnchor == containerView.centerXAnchor
        }

        addressLabel.do {
            $0.topAnchor == subtitleLabel.bottomAnchor + 4
            $0.leadingAnchor == containerView.leadingAnchor + 24
            $0.centerXAnchor == containerView.centerXAnchor
            $0.bottomAnchor == containerView.bottomAnchor - 32
        }

        enterLinkButton.do {
            $0.topAnchor == titleLabel.bottomAnchor + 16
            $0.leadingAnchor == containerView.leadingAnchor + 24
            $0.centerXAnchor == containerView.centerXAnchor
            $0.heightAnchor == 56
            $0.bottomAnchor == containerView.bottomAnchor - 24
        }
    }
}
