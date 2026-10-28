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
import SoraUI

class TitleWithAccessoryView: UIView {
    private(set) var titleView: ImageWithTitleView!
    private(set) var accessoryLabel: UILabel!

    override var intrinsicContentSize: CGSize {
        let height = max(titleView.intrinsicContentSize.height,
                         accessoryLabel.intrinsicContentSize.height)
        let width = titleView.intrinsicContentSize.width + accessoryLabel.intrinsicContentSize.width
        return CGSize(width: width, height: height)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        configure()
    }

    func invalidateLayout() {
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    private func configure() {
        backgroundColor = .clear

        titleView = ImageWithTitleView()
        titleView.translatesAutoresizingMaskIntoConstraints = false
        titleView.layoutType = .horizontalImageFirst
        addSubview(titleView)

        accessoryLabel = UILabel()
        accessoryLabel.translatesAutoresizingMaskIntoConstraints = false
        accessoryLabel.textAlignment = .right
        addSubview(accessoryLabel)

        titleView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        titleView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true

        accessoryLabel.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        accessoryLabel.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true

        titleView.trailingAnchor.constraint(equalTo: accessoryLabel.leadingAnchor).isActive = true

        titleView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        accessoryLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        titleView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        accessoryLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }
}
