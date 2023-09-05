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
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
        }
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
        button.clipsToBounds = true
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
        }
        return button
    }()
    
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
        stackView.addArrangedSubviews(marketLabel, marketButton)
        stackView.setCustomSpacing(16, after: marketButton)
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
