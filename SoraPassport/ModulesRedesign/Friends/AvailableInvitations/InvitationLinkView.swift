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
import Anchorage
import SoraUI
import SoraUIKit

protocol InvitationLinkViewDelegate: AnyObject {
    func shareButtonTapped(with text: String)
}

final class InvitationLinkView: SoramitsuView {

    weak var delegate: InvitationLinkViewDelegate?

    private lazy var shareButton: ImageButton = {
        ImageButton(size: CGSize(width: 24, height: 24)).then {
            $0.sora.image = R.image.shareIcon()
            $0.sora.tintColor = .fgSecondary
            $0.sora.backgroundColor = .custom(uiColor: .clear)
            $0.sora.addHandler(for: .touchUpInside) { [weak self] in
                self?.buttonTapped()
            }
        }
    }()

    let titleLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.text = R.string.localizable.referralYourInvitationLinkTitle(preferredLanguages: .currentLocale)
            $0.sora.textColor = .fgSecondary
            $0.sora.alignment = .right
            $0.sora.font = FontType.textXS
        }
    }()

    let linkLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.textColor = .fgPrimary
            $0.sora.alignment = .left
            $0.sora.font = FontType.textM
        }
    }()

    init() {
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func buttonTapped() {
        delegate?.shareButtonTapped(with: linkLabel.sora.text ?? "")
        UIPasteboard.general.string = linkLabel.sora.text
    }
}

private extension InvitationLinkView {
    func configure() {
        sora.backgroundColor = .custom(uiColor: .clear)
        sora.borderColor = .bgSurfaceVariant
        sora.borderWidth = 1.0
        sora.shadow = .small
        sora.cornerRadius = .circle

        addSubview(shareButton)
        addSubview(titleLabel)
        addSubview(linkLabel)

        shareButton.do {
            $0.trailingAnchor == trailingAnchor - 8
            $0.centerYAnchor == centerYAnchor
        }

        titleLabel.do {
            $0.topAnchor == topAnchor + 10
            $0.leadingAnchor == leadingAnchor + 16
            $0.heightAnchor == 16
        }

        linkLabel.do {
            $0.topAnchor == titleLabel.bottomAnchor + 4
            $0.leadingAnchor == leadingAnchor + 16
            $0.trailingAnchor == shareButton.leadingAnchor - 14
            $0.bottomAnchor == bottomAnchor - 10
            $0.heightAnchor == 16
        }
    }
}
