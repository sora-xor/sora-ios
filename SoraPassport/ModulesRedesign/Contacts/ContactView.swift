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
import SnapKit

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
        label.sora.numberOfLines = 2
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
    
    public lazy var button: SoramitsuButton = {
        let view = SoramitsuButton()
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
        stackView.sora.distribution = .equalSpacing
        stackView.spacing = 4
        return stackView
    }()
    
    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setupSubviews()
        setupConstrains()
    }

    private func setupSubviews() {
        sora.backgroundColor = .bgSurface
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(accountImageView)
        addSubview(arrowImageView)
        addSubview(contactStackView)
        addSubview(button)
        
        contactStackView.addArrangedSubviews([usernameTitle, accountTitle])
    }

    private func setupConstrains() {
        accountImageView.snp.makeConstraints { make in
            make.height.equalTo(40)
            make.width.equalTo(40)
            make.top.equalTo(self).offset(8)
            make.leading.equalTo(self).offset(24)
            make.centerY.equalTo(self)
        }
        
        arrowImageView.snp.makeConstraints { make in
            make.height.equalTo(24)
            make.width.equalTo(24)
            make.trailing.equalTo(self).offset(-16)
            make.centerY.equalTo(accountImageView)
        }
        
        contactStackView.snp.makeConstraints { make in
            make.leading.equalTo(accountImageView.snp.trailing).offset(8)
            make.trailing.equalTo(arrowImageView.snp.leading).offset(-8)
            make.centerY.equalTo(accountImageView)
        }
        
        button.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
    }
}
