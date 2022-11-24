/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import Then
import Anchorage

final class TextCell: UITableViewCell {

    // MARK: - Outlets
    private var titleLabel: UILabel = {
        UILabel().then {
            $0.numberOfLines = 0
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

extension TextCell: Reusable {
    func bind(viewModel: CellViewModel) {
        guard let viewModel = viewModel as? TextViewModel else { return }
        titleLabel.text = viewModel.title
        titleLabel.font = viewModel.font
        titleLabel.textColor = viewModel.textColor
        titleLabel.textAlignment = viewModel.textAligment
    }
}

private extension TextCell {

    func configure() {
        selectionStyle = .none
        backgroundColor = .clear

        contentView.addSubview(titleLabel)

        titleLabel.do {
            $0.topAnchor == contentView.topAnchor
            $0.centerXAnchor == contentView.centerXAnchor
            $0.centerYAnchor == contentView.centerYAnchor
            $0.leadingAnchor == contentView.leadingAnchor + 24
        }
    }
}
