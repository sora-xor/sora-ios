// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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
