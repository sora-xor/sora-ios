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
    private var hasSeed = false
    private var rawSeed = ""
    private var revealed = false
    private var hideTimer: Timer?
    private let scrollView = UIScrollView()
    private lazy var revealButton: WalletNeonButton = {
        let button = WalletSafeMode.button(.secondary, title: R.string.localizable.commonShow(preferredLanguages: .currentLocale))
        button.accessibilityIdentifier = "wallet-raw-seed-reveal"
        button.addTarget(self, action: #selector(toggleReveal), for: .touchUpInside)
        return button
    }()
    private var backupPath = ""
    private let pathLabel = UILabel()
    private let copyPathButton = WalletSafeMode.button(.tertiary, title: WalletUX.text("Copy derivation path"))

    private var containerView: SoramitsuView = {
        SoramitsuView().then {
            $0.sora.backgroundColor = .bgSurface
            $0.sora.material = .solid
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
            $0.sora.dynamicTextStyle = .body
            $0.sora.textColor = .fgPrimary
            $0.numberOfLines = 0
        }
    }()

    private var descriptionLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.font = FontType.mono
            $0.sora.dynamicTextStyle = .body
            $0.sora.lineBreakMode = .byCharWrapping
            $0.accessibilityIdentifier = "wallet-raw-seed-value"
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
        soramitsuView.sora.backgroundColor = .bgPage
        configure()
        [UIApplication.willResignActiveNotification, UIScreen.capturedDidChangeNotification,
         UIApplication.userDidTakeScreenshotNotification].forEach {
            NotificationCenter.default.addObserver(self, selector: #selector(hideSeed), name: $0, object: nil)
        }
        presenter.exportRawSeed()
    }

    func set(rawSeed: String, derivationPath: String) {
        backupPath = derivationPath
        self.rawSeed = rawSeed
        hasSeed = !rawSeed.isEmpty
        hideSeed()
    }

    deinit { hideTimer?.invalidate(); NotificationCenter.default.removeObserver(self) }

    override func viewWillDisappear(_ animated: Bool) {
        hideSeed()
        super.viewWillDisappear(animated)
    }

    @objc private func toggleReveal() {
        if revealed { hideSeed(); return }
        guard hasSeed, UIApplication.shared.applicationState == .active,
              !(view.window?.windowScene?.screen.isCaptured ?? UIScreen.main.isCaptured) else { return }
        revealed = true
        updateVisibility()
        hideTimer?.invalidate()
        let timer = Timer(timeInterval: 60, repeats: false) { [weak self] _ in self?.hideSeed() }
        hideTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    @objc private func hideSeed() {
        revealed = false
        hideTimer?.invalidate(); hideTimer = nil
        updateVisibility()
    }

    private func updateVisibility() {
        descriptionLabel.sora.text = hasSeed ? (revealed ? rawSeed : nil) : WalletUX.text(
            "No matching raw seed is available on this iPhone. Use JSON export to back up a verified signing key.")
        descriptionLabel.isHidden = hasSeed && !revealed
        pathLabel.text = revealed ? WalletUX.text("Also save this derivation path:") + "\n" + backupPath : nil
        pathLabel.isHidden = !revealed || backupPath.isEmpty
        copyPathButton.isHidden = !revealed || backupPath.isEmpty
        copyButton.isEnabled = !hasSeed || revealed
        copyButton.sora.title = hasSeed ? R.string.localizable.copyToClipboard(preferredLanguages: languages) : WalletUX.text("Export JSON")
        revealButton.isHidden = !hasSeed
        revealButton.setTitle(revealed ? R.string.localizable.commonHide(preferredLanguages: .currentLocale) : R.string.localizable.commonShow(preferredLanguages: .currentLocale), for: .normal)
    }

    private func configure() {
        navigationItem.backButtonTitle = ""
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.title = R.string.localizable.commonRawSeed(preferredLanguages: languages)
        titleLabel.sora.text = R.string.localizable.mnemonicText(preferredLanguages: languages)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(containerView)

        pathLabel.numberOfLines = 0
        pathLabel.textColor = .label
        pathLabel.font = .preferredFont(forTextStyle: .body)
        pathLabel.adjustsFontForContentSizeCategory = true
        copyPathButton.tintColor = WalletUX.tokens.cyan
        pathLabel.isHidden = true
        copyPathButton.setTitle(WalletUX.text("Copy derivation path"), for: .normal)
        copyPathButton.addTarget(self, action: #selector(copyPath), for: .touchUpInside)
        copyPathButton.isHidden = true
        stackView.removeArrangedSubviews()
        containerView.addSubview(stackView)
        stackView.addArrangedSubviews([
            titleLabel,
            revealButton,
            descriptionLabel,
            copyButton,
            pathLabel,
            copyPathButton
        ])
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            containerView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            containerView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32)
        ])
        stackView.do {
            $0.horizontalAnchors == containerView.horizontalAnchors + 24
            $0.verticalAnchors == containerView.verticalAnchors + 24
        }
    }

    @objc private func copyPath() {
        guard revealed, !backupPath.isEmpty else { return }
        UIPasteboard.general.setItems([["public.utf8-plain-text": backupPath]],
            options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(45)])
    }

    @objc
    private func copyTapped(){
        guard hasSeed else { presenter.exportJSON(); return }
        guard revealed else { return }
        copyButton.sora.title = R.string.localizable.commonCopied(preferredLanguages: .currentLocale)
        presenter.copyRawSeed()
    }
}

extension AccountExportRawSeedViewController: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    func applyLocalization() {
        if isViewLoaded { updateVisibility() }
    }
}

extension AccountExportRawSeedViewController: AccountExportRawSeedViewProtocol {}
