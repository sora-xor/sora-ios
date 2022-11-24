/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

//
//  ProfileNodeTableViewCell.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 02.09.2022.
//  Copyright © 2022 Ruslan Rezin. All rights reserved.
//

import Foundation
import UIKit
import Then
import Anchorage

final class ProfileNodeTableViewCell: UITableViewCell, Reusable {

    private var titleLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .paragraph1)
            $0.textColor = R.color.baseContentPrimary()
        }
    }()

    private var iconImageView: UIImageView = {
        UIImageView(image: nil).then {
            $0.widthAnchor == 24
            $0.contentMode = .center
            $0.tintColor = R.color.baseContentQuaternary()
        }
    }()

    private var arrowImageView: UIImageView = {
        UIImageView(
            image: R.image.circleChevronRight()?.withRenderingMode(.alwaysTemplate)).then {
            $0.widthAnchor == 16
            $0.contentMode = .center
            $0.tintColor = R.color.baseContentQuaternary()
        }
    }()

    private var nodeStatusView: UIView = {
        UIView().then {
            $0.backgroundColor = R.color.statusSuccess()
            $0.widthAnchor == 8.0
            $0.heightAnchor == 8.0
            $0.layer.cornerRadius = 4
        }
    }()

    private var nodeNameLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .paragraph2, isBold: false)
            $0.textColor = R.color.neumorphism.swiperTextGrey()
        }
    }()

    private var separatorView: UIView = {
        UIView().then {
            $0.backgroundColor = R.color.neumorphism.separator()
            $0.widthAnchor == UIScreen.main.bounds.width
            $0.heightAnchor == 1.0
        }
    }()

    private(set) var viewModel: ProfileOptionViewModelProtocol?

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configure()
    }

    func bind(viewModel: CellViewModel) {
        guard let viewModel = viewModel as? ProfileNodeOptionViewModel else { return }

        titleLabel.text = viewModel.title
        iconImageView.image = viewModel.iconImage?.withRenderingMode(.alwaysTemplate)
        nodeNameLabel.text = viewModel.curentNodeName

        arrowImageView.isHidden = false
        contentView.isUserInteractionEnabled = true
    }
}

private extension ProfileNodeTableViewCell {

    func configure() {
        backgroundColor = R.color.baseBackground()
        let stackView = createContentStackView()

        stackView.do {
            addSubview($0)
            $0.topAnchor == topAnchor + 15
            $0.leadingAnchor == leadingAnchor + 16
            $0.centerXAnchor == centerXAnchor
            $0.heightAnchor == 24
        }

        createNodeContentStackView().do {
            addSubview($0)
            $0.topAnchor == stackView.bottomAnchor + 4
            $0.bottomAnchor == bottomAnchor - 17
            $0.leadingAnchor == leadingAnchor + 56
            $0.trailingAnchor == trailingAnchor - 16
            $0.heightAnchor == 16
        }

        separatorView.do {
            addSubview($0)
            $0.centerXAnchor == centerXAnchor
            $0.bottomAnchor == bottomAnchor
        }
    }

    func createContentStackView() -> UIView {
        UIStackView(arrangedSubviews: [
            iconImageView,
            titleLabel,
            arrowImageView
        ]).then {
            $0.axis = .horizontal
            $0.alignment = .center
            $0.spacing = 16
        }
    }

    func createNodeContentStackView() -> UIView {
        UIStackView(arrangedSubviews: [
            nodeStatusView,
            nodeNameLabel
        ]).then {
            $0.axis = .horizontal
            $0.alignment = .center
            $0.spacing = 4
        }
    }
}
