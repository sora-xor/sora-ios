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
import Anchorage

final class Card: SoramitsuView {

    private let titleLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.font = FontType.headline4
            $0.sora.textColor = .fgSecondary
            $0.numberOfLines = 1
        }
    }()

    private let bottomLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.font = FontType.paragraphXS
            $0.sora.textColor = .fgSecondary
            $0.numberOfLines = 0
            $0.lineBreakMode = .byWordWrapping
        }
    }()

    private let stackView: SoramitsuStackView = {
        SoramitsuStackView().then {
            $0.sora.axis = .vertical
            $0.spacing = 0
            $0.sora.distribution = .fill
        }
    }()

    public var headerText: String = "" {
        didSet {
            titleLabel.sora.text = headerText
        }
    }

    public var footerText: String = "" {
        didSet {
            bottomLabel.sora.text = footerText
        }
    }

    public var stackContents: [UIView] = [] {
        didSet {
            stackView.removeArrangedSubviews()
            stackView.addArrangedSubviews(stackContents)
        }
    }

    init() {
        super.init(frame: .zero)
        sora.backgroundColor = .bgSurface
        layer.cornerRadius = 32
        layer.masksToBounds = true
        sora.shadow = .default
        layoutMargins = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)

        addSubviews(titleLabel, stackView, bottomLabel)

        titleLabel.do {
            $0.topAnchor == topAnchor + 24
            $0.horizontalAnchors == horizontalAnchors + 24
            $0.bottomAnchor == stackView.topAnchor - 8
        }
        stackView.do {
            $0.horizontalAnchors == horizontalAnchors
        }
        bottomLabel.do {
            $0.topAnchor == stackView.bottomAnchor + 8
            $0.horizontalAnchors == horizontalAnchors + 24
            $0.bottomAnchor == bottomAnchor - 24
        }
    }
}
