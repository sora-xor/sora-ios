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
import SoraFoundation

final class FarmSliderView: SoramitsuView {
    
    private let localizationManager = LocalizationManager.shared
    
    private lazy var stackView: SoramitsuStackView = {
        let stackView = SoramitsuStackView()
        stackView.sora.axis = .vertical
        stackView.sora.distribution = .fill
        stackView.sora.backgroundColor = .custom(uiColor: .clear)
        stackView.spacing = 8
        stackView.clipsToBounds = false
        return stackView
    }()
    
    private lazy var controlView: SoramitsuStackView = {
        let stackView = SoramitsuStackView()
        stackView.sora.backgroundColor = .custom(uiColor: .clear)
        stackView.sora.axis = .horizontal
        return stackView
    }()
    
    public lazy var percentageLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.text = "0%"
        label.sora.textColor = .fgPrimary
        label.sora.alignment = localizationManager.isRightToLeft ? .right : .left
        label.sora.font = FontType.displayL
        return label
    }()
    
    public lazy var maxButton: SoramitsuButton = {
        let attributedText = SoramitsuTextItem(text: R.string.localizable.commonMax(preferredLanguages: .currentLocale).uppercased(),
                                               fontData: FontType.textBoldS,
                                               textColor: .accentPrimary,
                                               alignment: .center)
        let button = SoramitsuButton()
        button.sora.attributedText = attributedText
        button.sora.backgroundColor = .accentPrimaryContainer
        button.sora.cornerRadius = .circle
        button.sora.horizontalOffset = 12
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }()
    
    public lazy var slider: UISlider = {
        let slider = UISlider()
        slider.minimumTrackTintColor = SoramitsuUI.shared.theme.palette.color(.additionalPolkaswap)
        slider.maximumTrackTintColor = SoramitsuUI.shared.theme.palette.color(.bgSurfaceVariant)
        slider.thumbTintColor = SoramitsuUI.shared.theme.palette.color(.additionalPolkaswap)
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.clipsToBounds = false
        return slider
    }()
    
    
    init() {
        super.init(frame: .zero)
        setupHierarchy()
        setupLayout()
    }
    
    private func setupHierarchy() {
        addSubview(stackView)
        
        stackView.addArrangedSubviews(controlView, slider)
        
        controlView.addArrangedSubviews(percentageLabel, maxButton)
    }
    
    
    private func setupLayout() {
        stackView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
        
        maxButton.snp.makeConstraints { make in
            make.trailing.centerY.equalTo(controlView)
            make.height.equalTo(32)
        }
    }
}
