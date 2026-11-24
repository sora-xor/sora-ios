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

final class OptionsView: SoramitsuView {

    let stackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.sora.axis = .horizontal
        view.sora.alignment = .center
        view.clipsToBounds = false
        view.spacing = 4
        return view
    }()
    
    public let slipageTitleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .fgSecondary
        label.sora.alignment = .center
        label.sora.text = R.string.localizable.slippage(preferredLanguages: .currentLocale)
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()
    
    public lazy var slipageButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .extraSmall, type: .bleached(.secondary))
        button.sora.horizontalOffset = 12
        button.sora.cornerRadius = .circle
        // A glyph says what the pad is; the word stays for VoiceOver.
        button.sora.leftImage = OptionsView.glyph("plusminus")
        button.sora.imageSize = 14
        button.accessibilityHint = R.string.localizable.slippage(preferredLanguages: .currentLocale)
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }()
    
    public let marketLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .fgSecondary
        label.sora.isHidden = true
        label.sora.alignment = .center
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.sora.text = R.string.localizable.polkaswapMarket(preferredLanguages: .currentLocale)
        return label
    }()
    
    public lazy var marketButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .extraSmall, type: .bleached(.secondary))
        button.sora.horizontalOffset = 12
        button.sora.title = "Smart"
        button.sora.cornerRadius = .circle
        button.sora.isHidden = true
        button.sora.leftImage = OptionsView.glyph("arrow.triangle.branch")
        button.sora.imageSize = 14
        button.accessibilityHint = R.string.localizable.polkaswapMarket(preferredLanguages: .currentLocale)
        // The pad's shadow falls outside it.
        button.clipsToBounds = false
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }()

    static func glyph(_ name: String) -> UIImage? {
        UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .bold))?
            .withTintColor(Lit.lacquerText, renderingMode: .alwaysOriginal)
    }
    
    init() {
        super.init(frame: .zero)
        setup()
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        clipsToBounds = false
        sora.backgroundColor = .custom(uiColor: .clear)
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        // Two pads with glyphs, no labels beside them: the labels were cut to "…" in Japanese.
        marketLabel.isHidden = true
        slipageTitleLabel.isHidden = true
        stackView.spacing = 12
        stackView.addArrangedSubviews(marketLabel, marketButton)
        stackView.addArrangedSubviews(slipageTitleLabel, slipageButton)
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
}
