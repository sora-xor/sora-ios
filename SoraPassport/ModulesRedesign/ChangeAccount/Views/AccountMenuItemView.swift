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

import Foundation
import SoraUIKit
import Anchorage

final class AccountMenuItemView: SoramitsuView {
    private let titleLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.font = FontType.textM
            $0.sora.textColor = .fgPrimary
            $0.sora.backgroundColor = .custom(uiColor: .clear)
            $0.numberOfLines = 1
            $0.lineBreakMode = .byTruncatingTail
        }
    }()

    private let checkmarkView: UIImageView = {
        UIImageView().then {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }()

    private let iconView: UIImageView = {
        UIImageView().then {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }()

    private lazy var moreButton: ImageButton = {
        ImageButton(size: CGSize(width: 44, height: 44)).then {
            $0.sora.image = R.image.iconMenuInfo()
            $0.sora.tintColor = .accentTertiary
            $0.sora.addHandler(for: .touchUpInside) { [weak self] in
                self?.onMoreTap()
            }
            $0.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        }
    }()

    private var model: AccountMenuItem?

    override init(frame: CGRect) {
        super.init(frame: frame)

        translatesAutoresizingMaskIntoConstraints = false
        addSubview(checkmarkView)
        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(moreButton)

        checkmarkView.do {
            $0.centerYAnchor == centerYAnchor
            $0.leadingAnchor == leadingAnchor
            $0.widthAnchor == 24
            $0.heightAnchor == 24
        }

        iconView.do {
            $0.centerYAnchor == centerYAnchor
            $0.leadingAnchor == checkmarkView.trailingAnchor + 21
            $0.sizeAnchors == CGSize(width: 40, height: 40)
            $0.topAnchor == topAnchor + 16
            $0.bottomAnchor == bottomAnchor - 16
        }

        titleLabel.do {
            $0.leadingAnchor == iconView.trailingAnchor + 8
            $0.trailingAnchor == moreButton.leadingAnchor - 8
            $0.centerYAnchor == centerYAnchor
        }

        moreButton.do {
            $0.centerYAnchor == centerYAnchor
            $0.trailingAnchor == trailingAnchor - 4
            $0.sizeAnchors == CGSize(width: 44, height: 44)
        }
        
        sora.backgroundColor = .custom(uiColor: .clear)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(model: AccountMenuItem) {
        titleLabel.sora.text = model.title
        checkmarkView.image = model.isSelected ?
        (model.isMultiselectionMode ? R.image.checkboxSelected() : R.image.checkSmall()?.tinted(with: UIColor(hex: "#EE2233"))) : (model.isMultiselectionMode ? R.image.checkboxDefault() : nil)

        moreButton.isHidden = model.isMultiselectionMode
        
        if let image = model.image {
            iconView.image = image
            iconView.isHidden = false
            iconView.widthAnchor == 40
        } else {
            iconView.isHidden = true
            iconView.widthAnchor == 0
        }
        self.model = model
    }


    @objc
    func onMoreTap() {
        if let model = self.model,
           let more = model.onMore {
            more()
        }
    }
}
