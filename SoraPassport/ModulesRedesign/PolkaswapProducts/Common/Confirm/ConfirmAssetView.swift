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

import Foundation
import SoraUIKit
import UIKit

final class ConfirmAssetView: SoramitsuStackView {

    public let imageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        view.heightAnchor.constraint(equalToConstant: 48).isActive = true
        view.widthAnchor.constraint(equalToConstant: 48).isActive = true
        return view
    }()
    
    public let amountLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldS
        label.sora.textColor = .fgPrimary
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()
    
    public let symbolLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .fgSecondary
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    
    init() {
        super.init(frame: .zero)
        setup()
        sora.alignment = .center
        sora.axis = .vertical
        spacing = 8
        layoutMargins = UIEdgeInsets(top: 24, left: 0, bottom: 24, right: 0)
        isLayoutMarginsRelativeArrangement = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        sora.backgroundColor = .custom(uiColor: .clear)
        
        addArrangedSubviews(imageView, amountLabel, symbolLabel)
    }
}
