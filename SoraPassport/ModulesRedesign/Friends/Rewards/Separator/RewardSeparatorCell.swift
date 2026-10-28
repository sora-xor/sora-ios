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

final class RewardSeparatorCell: SoramitsuTableViewCell {

    // MARK: - Outlets
    private var containerView: SoramitsuView = {
        SoramitsuView().then {
            $0.sora.backgroundColor = .bgSurface
        }
    }()
    
    private var graySeparatorView: SoramitsuView = {
        SoramitsuView().then {
            $0.sora.backgroundColor = .fgOutline
        }
    }()
    
    private var whiteSeparatorView: SoramitsuView = {
        SoramitsuView().then {
            $0.sora.backgroundColor = .bgSurface
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
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        var path = UIBezierPath()
        
        path.append(UIBezierPath(rect: CGRect(x: -3,
                                              y: 0,
                                              width: 3,
                                              height: containerView.bounds.height)))
        
        path.append(UIBezierPath(rect: CGRect(x: containerView.bounds.width + 3,
                                              y: 0,
                                              width: 3,
                                              height: containerView.bounds.height)))
        
        containerView.layer.shadowPath = path.cgPath
    }
}

extension RewardSeparatorCell: Reusable {
    func bind(viewModel: CellViewModel) {
        guard let viewModel = viewModel as? RewardSeparatorViewModel else { return }
    }
}

private extension RewardSeparatorCell {

    func configure() {
        sora.backgroundColor = .custom(uiColor: .clear)
        sora.selectionStyle = .none

        contentView.addSubview(containerView)
        containerView.addSubview(graySeparatorView)
        containerView.addSubview(whiteSeparatorView)

        containerView.do {
            $0.topAnchor == contentView.topAnchor
            $0.bottomAnchor == contentView.bottomAnchor
            $0.centerXAnchor == contentView.centerXAnchor
            $0.heightAnchor == 17
            $0.leadingAnchor == contentView.leadingAnchor + 16
        }

        graySeparatorView.do {
            $0.topAnchor == containerView.topAnchor + 8
            $0.leadingAnchor == containerView.leadingAnchor
            $0.centerXAnchor == containerView.centerXAnchor
            $0.widthAnchor == UIScreen.main.bounds.width
            $0.heightAnchor == 1.0
        }

        whiteSeparatorView.do {
            $0.topAnchor == graySeparatorView.bottomAnchor
            $0.leadingAnchor == containerView.leadingAnchor
            $0.centerXAnchor == containerView.centerXAnchor
            $0.widthAnchor == UIScreen.main.bounds.width
            $0.heightAnchor == 1.0
        }
    }
}
