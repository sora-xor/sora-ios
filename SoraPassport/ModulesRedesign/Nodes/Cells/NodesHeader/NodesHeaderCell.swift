// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import Then
import Anchorage
import SoraUI

final class NodesHeaderCell: UITableViewCell {

    // MARK: - Outlets
    private var titleLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .display2).withSize(13.0)
            $0.textColor = R.color.neumorphism.brown()
            $0.numberOfLines = 0
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

extension NodesHeaderCell: Reusable {
    func bind(viewModel: CellViewModel) {
        guard let viewModel = viewModel as? NodesHeaderViewModel else { return }
        titleLabel.text = viewModel.title
    }
}

private extension NodesHeaderCell {

    func configure() {
        backgroundColor = R.color.baseBackground()
        selectionStyle = .none

        contentView.addSubview(titleLabel)

        titleLabel.do {
            $0.topAnchor == contentView.topAnchor
            $0.bottomAnchor == contentView.bottomAnchor
            $0.centerXAnchor == contentView.centerXAnchor
            $0.leadingAnchor == contentView.leadingAnchor + 24
        }
    }
}
