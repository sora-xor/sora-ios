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

final class AccountView: SoramitsuView {
    
    public var onTap: (() -> Void)?
    
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
        label.sora.font = FontType.textS
        label.sora.numberOfLines = 2
        label.sora.isHidden = true
        label.sora.text = R.string.localizable.selectRecipient(preferredLanguages: .currentLocale)
        return label
    }()
    
    public let accountAddress: SoramitsuLabel = {
        var label = SoramitsuLabel()
        label.sora.textColor = .accentTertiary
        label.sora.font = FontType.textBoldS
        label.sora.numberOfLines = 2
        label.sora.text = R.string.localizable.selectRecipient(preferredLanguages: .currentLocale)
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
    
    public lazy var button: SoramitsuButton = {
        let view = SoramitsuButton()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.sora.isHidden = true
        view.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.onTap?()
        }
        return view
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
        addSubview(button)
    }

    private func setupConstrains() {
        topConstraint = accountImageView.topAnchor.constraint(equalTo: topAnchor, constant: 18)
        bottomConstraint = accountImageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18)
        
        NSLayoutConstraint.activate([
            accountImageView.heightAnchor.constraint(equalToConstant: 40),
            accountImageView.widthAnchor.constraint(equalToConstant: 40),
            topConstraint,
            accountImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            bottomConstraint,
            
            mainStackView.leadingAnchor.constraint(equalTo: accountImageView.trailingAnchor, constant: 8),
            mainStackView.centerYAnchor.constraint(equalTo: accountImageView.centerYAnchor),
            mainStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            
            button.topAnchor.constraint(equalTo: topAnchor),
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.centerYAnchor.constraint(equalTo: centerYAnchor),
            button.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }
}
