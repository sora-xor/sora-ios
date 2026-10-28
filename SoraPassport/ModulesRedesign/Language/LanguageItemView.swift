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
