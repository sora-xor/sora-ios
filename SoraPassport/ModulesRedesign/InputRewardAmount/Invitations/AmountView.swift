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

import UIKit
import SoraUIKit
import Anchorage

final class AmountView: SoramitsuView {

    let plusButton: ImageButton = {
        ImageButton(size: CGSize(width: 24, height: 24)).then {
            $0.sora.image = R.image.roundPlus()
            $0.sora.tintColor = .fgSecondary
        }
    }()

    let minusButton: ImageButton = {
        ImageButton(size: CGSize(width: 24, height: 24)).then {
            $0.sora.image = R.image.roundMinus()
            $0.sora.tintColor = .fgSecondary
        }
    }()

    let textField: SoramitsuTextField = {
        SoramitsuTextField().then {
            $0.sora.font = FontType.displayM
            $0.sora.placeholder = "0"
            $0.sora.tintColor = .custom(uiColor: .clear)
            $0.sora.textColor = .fgPrimary
            $0.sora.placeholderColor = .fgSecondary
            $0.textAlignment = .center
            $0.keyboardType = .numberPad
        }
    }()

    let underMinusLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.font = FontType.textXS
            $0.sora.textColor = .fgSecondary
            $0.sora.alignment = .left
        }
    }()

    let underPlusLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.font = FontType.textXS
            $0.sora.textColor = .fgSecondary
            $0.sora.alignment = .right
        }
    }()

    init() {
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension AmountView {
    func configure() {
        sora.backgroundColor = .bgSurface
        sora.borderColor = .fgPrimary
        sora.cornerRadius = .max
        sora.borderWidth = 1.0

        addSubview(plusButton)
        addSubview(minusButton)
        addSubview(textField)
        addSubview(underPlusLabel)
        addSubview(underMinusLabel)

        minusButton.do {
            $0.topAnchor == topAnchor + 16
            $0.leadingAnchor == leadingAnchor + 16
        }
        
        plusButton.do {
            $0.topAnchor == minusButton.topAnchor
            $0.trailingAnchor == trailingAnchor - 16
        }

        textField.do {
            $0.centerXAnchor == centerXAnchor
            $0.centerYAnchor == plusButton.centerYAnchor
            $0.heightAnchor == 32
        }

        underMinusLabel.do {
            $0.topAnchor == minusButton.bottomAnchor + 12
            $0.leadingAnchor == leadingAnchor + 16
            $0.trailingAnchor == underPlusLabel.leadingAnchor - 10
            $0.bottomAnchor == bottomAnchor - 16
        }

        underPlusLabel.do {
            $0.topAnchor == plusButton.bottomAnchor + 12
            $0.trailingAnchor == trailingAnchor - 16
            $0.bottomAnchor == bottomAnchor - 16
        }
    }
}
