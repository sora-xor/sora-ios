/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import Then
import Anchorage

final class SpaceCell: UITableViewCell {

    // MARK: - Outlets
    private var spaceView: UIView = {
        UIView().then {
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

extension SpaceCell: Reusable {
    func bind(viewModel: CellViewModel) {
        guard let viewModel = viewModel as? SpaceViewModel else { return }
        
        spaceView.do {
            $0.heightAnchor == viewModel.height
        }

        backgroundColor = viewModel.backgroundColor
    }
}

private extension SpaceCell {

    func configure() {
        selectionStyle = .none
        contentView.addSubview(spaceView)

        spaceView.do {
            $0.topAnchor == contentView.topAnchor
            $0.centerXAnchor == contentView.centerXAnchor
            $0.leadingAnchor == contentView.leadingAnchor
            $0.centerYAnchor == contentView.centerYAnchor
        }
    }
}
