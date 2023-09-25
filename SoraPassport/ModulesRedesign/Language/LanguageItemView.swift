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
import SoraFoundation

final class LanguageItemView: SoramitsuView {
    
    private let localizationManager = LocalizationManager.shared
    
    let stack: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.axis = .vertical
        view.sora.distribution = .fillProportionally
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.layoutMargins = UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)
        view.isLayoutMarginsRelativeArrangement = true
        view.spacing = 8
        return view
    }()
    
    let checkmarkImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.sora.isUserInteractionEnabled = false
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.image = R.image.profile.checkmarkGreen()
        return view
    }()

    let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.alignment = .left
        label.sora.numberOfLines = 1
        label.sora.backgroundColor = .custom(uiColor: .clear)
        label.sora.font = FontType.textM
        label.sora.textColor = .fgPrimary
        return label
    }()
    
    let subtitleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.alignment = .left
        label.sora.numberOfLines = 1
        label.sora.backgroundColor = .custom(uiColor: .clear)
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .fgSecondary
        return label
    }()
    
    let leftImageView: SoramitsuImageView = {
        let imageView = SoramitsuImageView()
        return imageView
    }()
    
    public var isSelectedLanguage: Bool = false {
        didSet {
            checkmarkImageView.sora.isHidden = !isSelectedLanguage
        }
    }
    
    var onTap: (()->())?
    
    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setupSubviews()
        setupConstrains()
    }

    private func setupSubviews() {
        sora.backgroundColor = .custom(uiColor: .clear)

        addSubview(checkmarkImageView)
        addSubview(stack)

        stack.addArrangedSubviews(titleLabel)
        stack.addArrangedSubviews(subtitleLabel)
    }

    private func setupConstrains() {
        checkmarkImageView.widthAnchor == 12
        checkmarkImageView.heightAnchor == 12
        checkmarkImageView.leadingAnchor == self.leadingAnchor + 20
        checkmarkImageView.centerYAnchor == self.centerYAnchor
        
        stack.leadingAnchor == checkmarkImageView.trailingAnchor
    }
    
    @objc func didTap() {
        onTap?()
    }
}
