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

final class FeeView: SoramitsuView {
    
    let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.text = R.string.localizable.networkFee()
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .fgSecondary
        label.sora.numberOfLines = 0
        return label
    }()
    
    let infoButton: ImageButton = {
        let button = ImageButton(size: CGSize(width: 14, height: 14))
        button.sora.image = R.image.wallet.info()
        button.sora.tintColor = .fgSecondary
        return button
    }()
    
    let feeLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textS
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 0
        return label
    }()
    
    init() {
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension FeeView {
    
    func configure() {
        sora.backgroundColor = .custom(uiColor: .clear)
        
        addSubviews([
            titleLabel,
            infoButton,
            feeLabel
        ])
        
        titleLabel.snp.makeConstraints { make in
            make.top.bottom.leading.equalTo(self)
        }
        
        infoButton.snp.makeConstraints { make in
            make.top.bottom.equalTo(self)
            make.leading.equalTo(titleLabel.snp.trailing).offset(5)
        }
        
        feeLabel.snp.makeConstraints { make in
            make.top.bottom.trailing.equalTo(self)
        }
    }
}
