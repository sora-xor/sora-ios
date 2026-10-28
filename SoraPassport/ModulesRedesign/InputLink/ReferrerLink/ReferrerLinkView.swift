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

import UIKit
import SoraUIKit
import SnapKit
import SoraFoundation

final class ReferrerLinkView: SoramitsuView {

    private lazy var stackView: SoramitsuStackView = {
        let stackView = SoramitsuStackView()
        stackView.sora.axis = .vertical
        stackView.sora.backgroundColor = .custom(uiColor: .clear)
        stackView.sora.distribution = .fill
        stackView.spacing = 0
        return stackView
    }()
    
    private lazy var titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.text = R.string.localizable.referralReferralLink(preferredLanguages: .currentLocale)
        label.sora.textColor = .fgSecondary
        label.sora.font = FontType.textXS
        label.sora.alignment = LocalizationManager.shared.isRightToLeft ? .right : .left
        return label
    }()
    
    let textField: SoramitsuTextField = {
        let textField = SoramitsuTextField()
        textField.sora.backgroundColor = .custom(uiColor: .clear)
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        return textField
    }()
    
    init() {
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension ReferrerLinkView {
    func configure() {
        sora.backgroundColor = .custom(uiColor: .clear)
        sora.cornerRadius = .max
        sora.cornerMask = .all
        sora.borderColor = .fgPrimary
        sora.borderWidth = 1.0
        
        addSubview(stackView)
        stackView.addArrangedSubviews([titleLabel, textField])
        
        stackView.snp.makeConstraints { make in
            make.top.equalTo(self).offset(14)
            make.leading.equalTo(self).offset(16)
            make.center.equalTo(self)
        }
    }
}
