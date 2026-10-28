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
