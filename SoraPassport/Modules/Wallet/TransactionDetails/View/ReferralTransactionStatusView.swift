/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import SoraUI
import CommonWallet

final class ReferralTransactionStatusView: UIView, WalletFormBordering {
    var borderType: BorderType = .bottom

    private var titleLabel: UILabel = {
        var label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.styled(for: .paragraph1)
        return label
    }()

    private var statusLabel: UILabel = {
        var label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.styled(for: .paragraph1, isBold: true)
        return label
    }()

    private var statusIcon: UIImageView = {
        var view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var detailsLabel: UILabel = {
        var label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.styled(for: .paragraph1)
        return label
    }()

    private var separatorView: UIView = {
        var view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = R.color.neumorphism.separator()
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: .zero)

        addSubview(titleLabel)
        addSubview(statusLabel)
        addSubview(statusIcon)
        addSubview(detailsLabel)
        addSubview(separatorView)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),

            statusLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: statusIcon.leadingAnchor, constant: -4),

            statusIcon.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            statusIcon.trailingAnchor.constraint(equalTo: trailingAnchor),
            statusIcon.widthAnchor.constraint(equalToConstant: 16),
            statusIcon.heightAnchor.constraint(equalToConstant: 12),

            detailsLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 12),
            detailsLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            detailsLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),

            separatorView.leadingAnchor.constraint(equalTo: leadingAnchor),
            separatorView.centerXAnchor.constraint(equalTo: centerXAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 1),
            separatorView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: SoraReferralTransactionStatusViewModel) {
        titleLabel.text = viewModel.title
        statusLabel.text = viewModel.details
        statusIcon.image = viewModel.detailsIcon
        detailsLabel.text = viewModel.transactionTypeText
    }

}
