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
