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
import UIKit

final class WalletHeaderView: SoramitsuControl {
    private let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline2
        label.sora.textColor = .fgPrimary
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    private let imageView: SoramitsuImageView = {
        let image = SoramitsuImageView()
        image.transform = CGAffineTransform(rotationAngle: .pi)
        image.sora.picture = .icon(image: R.image.arrow()!, color: .fgPrimary)
        image.setContentCompressionResistancePriority(.required, for: .horizontal)
        return image
    }()

    init() {
        super.init(frame: .zero)
        setup()
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        sora.backgroundColor = .custom(uiColor: .clear)
        addSubview(titleLabel)
        addSubview(imageView)
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            imageView.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 10),
            imageView.heightAnchor.constraint(equalToConstant: 16),
            imageView.widthAnchor.constraint(equalToConstant: 16),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    func configure(title: String, isExpand: Bool) {
        titleLabel.sora.text = title

        UIView.animate(withDuration: 0.3) {
            self.imageView.transform = isExpand ? CGAffineTransform(rotationAngle: .pi) : CGAffineTransform.identity
        }
    }
}
