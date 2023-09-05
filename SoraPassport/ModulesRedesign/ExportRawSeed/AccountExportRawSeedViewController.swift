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
import SoraFoundation
import SoraUIKit
import Anchorage

final class AccountExportRawSeedViewController: SoramitsuViewController, ControllerBackedProtocol {

    var presenter: AccountExportRawSeedPresenterProtocol!

    private var containerView: SoramitsuView = {
        SoramitsuView().then {
            $0.sora.backgroundColor = .bgSurface
            $0.sora.cornerRadius = .max
            $0.layer.masksToBounds = true
            $0.sora.shadow = .default
        }
    }()

    private var stackView: SoramitsuStackView = {
        SoramitsuStackView().then {
            $0.sora.axis = .vertical
            $0.spacing = 24
            $0.layer.cornerRadius = 0
            $0.sora.distribution = .fill
        }
    }()

    private var titleLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.font = FontType.textM
            $0.sora.textColor = .fgPrimary
            $0.numberOfLines = 0
        }
    }()

    private var descriptionLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.font = FontType.paragraphBoldM
            $0.sora.textColor = .fgPrimary
            $0.numberOfLines = 0
        }
    }()

    private var copyButton: SoramitsuButton = {
        SoramitsuButton(size: .large, type: .tonal(.tertiary)).then {
            $0.sora.leftImage = R.image.copyNeu()
            $0.addTarget(nil, action: #selector(copyTapped), for: .touchUpInside)
            $0.sora.cornerRadius = .circle
        }
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        configure()
        presenter.exportRawSeed()
    }

    func set(rawSeed: String) {
        descriptionLabel.sora.text = rawSeed
    }

    private func configure() {
        navigationItem.backButtonTitle = ""
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.title = R.string.localizable.commonRawSeed(preferredLanguages: languages)
        titleLabel.sora.text = R.string.localizable.mnemonicText(preferredLanguages: languages)

        view.addSubview(containerView)

        stackView.removeArrangedSubviews()
        containerView.addSubview(stackView)
        stackView.addArrangedSubviews([
            titleLabel,
            descriptionLabel,
            copyButton
        ])
        containerView.do {
            $0.horizontalAnchors == view.horizontalAnchors + 16
            $0.topAnchor == view.soraSafeTopAnchor
        }
        stackView.do {
            $0.horizontalAnchors == containerView.horizontalAnchors + 24
            $0.verticalAnchors == containerView.verticalAnchors + 24
        }
    }

    @objc
    private func copyTapped(){
        copyButton.sora.title = R.string.localizable.commonCopied(preferredLanguages: .currentLocale)
        presenter.copyRawSeed()
    }
}

extension AccountExportRawSeedViewController: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    func applyLocalization() {
        copyButton.sora.title = R.string.localizable.copyToClipboard(preferredLanguages: languages)
    }
}

extension AccountExportRawSeedViewController: AccountExportRawSeedViewProtocol {}
