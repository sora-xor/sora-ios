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
import UIKit
import SoraUIKit
import SnapKit
import SoraFoundation

final class EnabledView: SoramitsuView {
    
    public let stackView: SoramitsuStackView = {
        let stackView = SoramitsuStackView()
        stackView.sora.axis = .horizontal
        stackView.spacing = 8
        stackView.sora.isUserInteractionEnabled = false
        return stackView
    }()
    
    public let checkmarkButton: ImageButton = {
        let button = ImageButton(size: CGSize(width: 24, height: 24))
        button.sora.isUserInteractionEnabled = false
        return button
    }()
    
    public lazy var titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textM
        label.sora.textColor = .fgPrimary
        label.sora.isUserInteractionEnabled = false
        label.sora.alignment = localizationManager.isRightToLeft ? .right : .left
        return label
    }()

    public let tappableArea: SoramitsuControl = {
        let view = SoramitsuControl()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.sora.isHidden = true
        return view
    }()
    
    private let localizationManager = LocalizationManager.shared
    
    init() {
        super.init(frame: .zero)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

private extension EnabledView {
    func setup() {
        addSubview(stackView)
        addSubview(tappableArea)
        
        stackView.addArrangedSubviews([
            titleLabel,
            checkmarkButton
        ])
        
        tappableArea.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
        
        stackView.snp.makeConstraints { make in
            make.edges.equalTo(self)
            make.height.equalTo(56)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(stackView)
        }
        
        checkmarkButton.snp.makeConstraints { make in
            make.trailing.equalTo(stackView)
        }
    }
}
