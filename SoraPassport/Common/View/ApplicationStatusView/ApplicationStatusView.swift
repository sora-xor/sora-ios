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

final class ApplicationStatusView: UIView {
    let titleLabel = UILabel()

    var contentInsets = UIEdgeInsets.zero {
        didSet {
            setNeedsDisplay()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        configure()
    }

    private func configure() {
        titleLabel.backgroundColor = .clear
        titleLabel.textAlignment = .center

        addSubview(titleLabel)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let size = titleLabel.sizeThatFits(bounds.size)

        let origin = CGPoint(x: bounds.size.width / 2.0 - size.width / 2.0 + contentInsets.left - contentInsets.right,
                             y: bounds.size.height / 2.0 - size.height / 2.0 + contentInsets.top - contentInsets.bottom)

        titleLabel.frame = CGRect(origin: origin, size: size)
    }
}
