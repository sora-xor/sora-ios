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
import SnapKit

struct WarningViewModel {
    let title: String
    let descriptionText: String
    var isHidden: Bool
    let containterBackgroundColor: SoramitsuColor
    let contentColor: SoramitsuColor
    
    init(title: String = "",
         descriptionText: String,
         isHidden: Bool,
         containterBackgroundColor: SoramitsuColor,
         contentColor: SoramitsuColor) {
        self.title = title
        self.descriptionText = descriptionText
        self.isHidden = isHidden
        self.containterBackgroundColor = containterBackgroundColor
        self.contentColor = contentColor
    }
}

final class WarningView: SoramitsuView {

    let containterView: SoramitsuView = {
        let view = SoramitsuView()
        view.sora.cornerRadius = .max
        return view
    }()
    
    let stackView: SoramitsuStackView = {
        let stackView = SoramitsuStackView()
        stackView.sora.alignment = .fill
        stackView.sora.axis = .vertical
        stackView.sora.distribution = .fill
        stackView.spacing = 8
        return stackView
    }()
    
    let descriptionLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.numberOfLines = 0
        label.sora.alignment = .center
        label.sora.font = FontType.paragraphXS
        label.sora.textColor = .statusError
        return label
    }()

    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setupSubviews()
        setupConstrains()
    }
    
    func setupView(with model: WarningViewModel) {
        descriptionLabel.sora.text = model.descriptionText
        descriptionLabel.sora.textColor = model.contentColor
        
        containterView.sora.borderColor = model.contentColor
        containterView.sora.backgroundColor = model.containterBackgroundColor
        
        sora.isHidden = model.isHidden
    }

    private func setupSubviews() {
        addSubview(containterView)
        containterView.addSubviews(stackView)
        stackView.addArrangedSubviews(descriptionLabel)
    }

    private func setupConstrains() {
        let verticalOffset = 16
        let horizontalOffset = 24
        
        containterView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
        
        stackView.snp.makeConstraints { make in
            make.leading.equalTo(containterView).offset(horizontalOffset)
            make.centerX.equalTo(containterView)
            make.top.equalTo(containterView).offset(verticalOffset)
            make.centerY.equalTo(containterView)
        }
    }
}
