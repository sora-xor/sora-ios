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
