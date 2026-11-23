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
import UIKit

final class ContactView: SoramitsuView {
    
    public var onTap: (() -> Void)?
    
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
        label.sora.font = FontType.textS
        label.sora.dynamicTextStyle = .body
        label.sora.numberOfLines = 0
        label.sora.lineBreakMode = .byCharWrapping
        label.semanticContentAttribute = .forceLeftToRight
        label.sora.text = R.string.localizable.selectRecipient(preferredLanguages: .currentLocale)
        return label
    }()
    
    public let usernameTitle: SoramitsuLabel = {
        var label = SoramitsuLabel()
        label.sora.textColor = .fgSecondary
        label.sora.font = FontType.textBoldXS
        label.sora.numberOfLines = 1
        return label
    }()
    
    public let arrowImageView: SoramitsuImageView = {
        let imageView = SoramitsuImageView()
        imageView.image = R.image.wallet.rightArrow()
        imageView.sora.tintColor = .fgSecondary
        return imageView
    }()
    
    public lazy var button: SoramitsuControl = {
        let view = SoramitsuControl()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isAccessibilityElement = true
        view.accessibilityTraits = .button
        view.accessibilityLabel = R.string.localizable.selectRecipient(preferredLanguages: .currentLocale)
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.sora.isHidden = true
        view.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.onTap?()
        }
        return view
    }()
    
    private let contactStackView: SoramitsuStackView = {
        let stackView = SoramitsuStackView()
        stackView.sora.axis = .vertical
        stackView.sora.distribution = .fill
        stackView.spacing = 4
        return stackView
    }()
    
    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setupSubviews()
    }

    private func setupSubviews() {
        sora.backgroundColor = .bgSurface
        translatesAutoresizingMaskIntoConstraints = false
        let row = UIStackView(arrangedSubviews: [accountImageView, contactStackView, arrowImageView])
        row.alignment = .center
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        addSubview(button)
        contactStackView.addArrangedSubviews([usernameTitle, accountTitle])
        let arrowWidth = arrowImageView.widthAnchor.constraint(equalToConstant: 20)
        arrowWidth.priority = UILayoutPriority(999)
        NSLayoutConstraint.activate([
            arrowWidth,
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            accountImageView.widthAnchor.constraint(equalToConstant: 40),
            accountImageView.heightAnchor.constraint(equalTo: accountImageView.widthAnchor),
            arrowImageView.heightAnchor.constraint(equalTo: arrowImageView.widthAnchor),
            button.topAnchor.constraint(equalTo: topAnchor), button.bottomAnchor.constraint(equalTo: bottomAnchor),
            button.leadingAnchor.constraint(equalTo: leadingAnchor), button.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
}
