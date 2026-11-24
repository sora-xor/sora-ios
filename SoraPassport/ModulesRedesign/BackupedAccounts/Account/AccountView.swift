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

import SoraUIKit
import Anchorage

final class AccountView: SoramitsuView {
    
    public var topConstraint: NSLayoutConstraint?
    public var bottomConstraint: NSLayoutConstraint?
    
    public let accountImageView: SoramitsuImageView = {
        let imageView = SoramitsuImageView()
        imageView.sora.tintColor = .fgSecondary
        imageView.sora.shadow = .extraSmall
        imageView.sora.cornerRadius = .circle
        imageView.sora.backgroundColor = .bgSurface
        return imageView
    }()
    
    public let accountTitle: SoramitsuLabel = {
        var label = SoramitsuLabel()
        label.sora.textColor = .fgPrimary
        label.sora.font = FontType.textBoldS
        label.sora.dynamicTextStyle = .body
        label.sora.numberOfLines = 0
        label.sora.isHidden = true
        return label
    }()
    
    public let accountAddress: SoramitsuLabel = {
        var label = SoramitsuLabel()
        label.sora.textColor = .fgSecondary
        label.sora.font = FontType.mono
        label.sora.dynamicTextStyle = .caption1
        label.sora.numberOfLines = 0
        return label
    }()
    
    private let mainStackView: SoramitsuStackView = {
        var mainStackView = SoramitsuStackView()
        mainStackView.sora.backgroundColor = .custom(uiColor: .clear)
        mainStackView.sora.axis = .vertical
        mainStackView.sora.alignment = .fill
        mainStackView.sora.clipsToBounds = false
        mainStackView.spacing = 4
        return mainStackView
    }()
    
    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setupSubviews()
        setupConstrains()
    }

    private func setupSubviews() {
        sora.backgroundColor = .bgSurface
        translatesAutoresizingMaskIntoConstraints = false
        mainStackView.addArrangedSubviews(accountTitle, accountAddress)
        addSubview(accountImageView)
        addSubview(mainStackView)
    }

    private func setupConstrains() {
        topConstraint = accountImageView.topAnchor.constraint(equalTo: topAnchor, constant: 18)
        bottomConstraint = accountImageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18)
        
        // The icon sets the minimum natural row height. Wrapped text can make the row taller.
        bottomConstraint?.priority = .defaultLow
        NSLayoutConstraint.activate([
            accountImageView.heightAnchor.constraint(equalToConstant: 40),
            accountImageView.widthAnchor.constraint(equalToConstant: 40),
            topConstraint,
            accountImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            bottomConstraint,
            
            mainStackView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 8),
            mainStackView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -8),
            mainStackView.leadingAnchor.constraint(equalTo: accountImageView.trailingAnchor, constant: 8),
            mainStackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            mainStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
        ])
    }
}
