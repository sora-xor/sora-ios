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

final class RecipientAddressView: SoramitsuView {

    public let titleLabel: SoramitsuLabel = {
        var label = SoramitsuLabel()
        label.sora.textColor = .fgSecondary
        label.sora.font = FontType.headline4
        label.sora.text = R.string.localizable.recipientAddress(preferredLanguages: .currentLocale).uppercased()
        return label
    }()
    
    public let contactView: ContactView = {
        let view = ContactView()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.button.sora.isHidden = false
        return view
    }()
    
    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setupSubviews()
        setupConstrains()
    }

    private func setupSubviews() {
        sora.shadow = .small
        sora.cornerRadius = .max
        sora.backgroundColor = .bgSurface
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        addSubview(contactView)
    }

    private func setupConstrains() {
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),

            contactView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            contactView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contactView.centerXAnchor.constraint(equalTo: centerXAnchor),
            contactView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
        ])
    }
}
