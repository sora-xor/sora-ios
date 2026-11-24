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

import UIKit
import SoraFoundation
import SoraUI
import SoraUIKit
import Anchorage
import SSFCloudStorage

final class AccountCreateViewController: SoramitsuViewController {
    enum Mode {
        case registration
        case registrationWithoutAccessToGoogle
        case view
        
        var nextButtonTitle: String {
            switch self {
            case .registrationWithoutAccessToGoogle:
                return R.string.localizable.accountConfirmationTitleV2(preferredLanguages: .currentLocale)
            case .view, .registration:
                return R.string.localizable.transactionContinue(preferredLanguages: .currentLocale)
            }
        }
    }

    var presenter: AccountCreatePresenterProtocol!
    var mode: Mode = .registration
    private let scrollView = UIScrollView()
    private var phraseWords: [String] = []
    private var phraseRevealed = false
    private var hideTimer: Timer?
    private lazy var revealButton: WalletNeonButton = {
        let button = WalletSafeMode.button(.secondary, title: WalletUX.text("Show my recovery phrase"))
        button.accessibilityIdentifier = "wallet-backup-reveal"
        button.addTarget(self, action: #selector(togglePhrase), for: .touchUpInside)
        return button
    }()

    private let containerView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .bgSurface
        view.sora.material = .solid
        view.sora.axis = .vertical
        view.sora.shadow = .default
        view.spacing = 24
        view.sora.cornerRadius = .max
        view.sora.distribution = .fill
        view.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }()

    private let titleLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.font = FontType.paragraphM
            $0.sora.dynamicTextStyle = .body
            $0.sora.textColor = .fgPrimary
            $0.numberOfLines = 0
        }
    }()

    private let mnemonicView: MnemonicDisplayView = {
        MnemonicDisplayView(frame: .zero).then {
            $0.indexTitleColorInColumn = .fgPrimary
            $0.wordTitleColorInColumn = .fgPrimary
            $0.indexFontInColumn = FontType.mono
            $0.wordFontInColumn =  FontType.phraseWord
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.accessibilityIdentifier = "wallet-backup-words"
            $0.isHidden = true
        }
    }()

    private var nextButton: SoramitsuButton = {
        SoramitsuButton().then {
            $0.sora.cornerRadius = .circle
            $0.addTarget(nil, action: #selector(actionNext), for: .touchUpInside)
        }
    }()
    
    let loadingView: SoramitsuLoadingView = {
        let view = SoramitsuLoadingView()
        view.isHidden = true
        view.isUserInteractionEnabled = true
        return view
    }()
    
    private lazy var googleButton: SoramitsuButton = {
        let title = SoramitsuTextItem(
            text: R.string.localizable.onboardingContinueWithGoogle(preferredLanguages: .currentLocale),
            fontData: FontType.buttonM,
            textColor: .accentSecondary,
            alignment: .center
        )
        
        let button = SoramitsuButton()
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .custom(uiColor: .clear)
        button.sora.attributedText = title
        button.sora.imageSize = 37
        button.sora.leftImage = R.image.googleIcon()
        button.sora.borderColor = .accentSecondary
        button.sora.borderWidth = 1
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.hidePhrase()
            self?.googleButton.isUserInteractionEnabled = false
            self?.loadingView.isHidden = false
            self?.presenter.backupToGoogle()
        }
        return button
    }()

    private var derivationPathModel: InputViewModelProtocol?
    private var backupPath = ""
    private let backupPathLabel = UILabel()
    private let copyBackupPathButton = WalletSafeMode.button(.tertiary, title: WalletUX.text("Copy derivation path"))

    var keyboardHandler: KeyboardHandler?

    var advancedAppearanceAnimator = TransitionAnimator(type: .push,
                                                        duration: 0.35,
                                                        subtype: .fromBottom,
                                                        curve: .easeOut)

    var advancedDismissalAnimator = TransitionAnimator(type: .push,
                                                       duration: 0.35,
                                                       subtype: .fromTop,
                                                       curve: .easeIn)

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.backButtonTitle = ""

        setupNavigationItem()
        setupLocalization()
        configure()

        presenter.setup()
        // Also when the scene moves to another screen (a phone folded or unfolded): words shown on
        // one screen are not carried onto the other.
        [UIApplication.willResignActiveNotification, UIScreen.capturedDidChangeNotification,
         UIApplication.userDidTakeScreenshotNotification, WalletDisplay.screenDidChangeNotification].forEach {
            NotificationCenter.default.addObserver(self, selector: #selector(hidePhrase), name: $0, object: nil)
        }
        hidePhrase()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appEnterToForeground),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
    }

    deinit {
        hideTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    @objc
    func appEnterToForeground() {
        presenter?.restoredApp()
    }

    private func configure() {

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(containerView)
        view.addSubview(loadingView)
        backupPathLabel.numberOfLines = 0
        backupPathLabel.textColor = .label
        backupPathLabel.font = .preferredFont(forTextStyle: .body)
        backupPathLabel.adjustsFontForContentSizeCategory = true
        backupPathLabel.isHidden = true
        copyBackupPathButton.setTitle(WalletUX.text("Copy derivation path"), for: .normal)
        copyBackupPathButton.tintColor = WalletUX.tokens.cyan
        copyBackupPathButton.titleLabel?.numberOfLines = 0
        copyBackupPathButton.titleLabel?.adjustsFontForContentSizeCategory = true
        copyBackupPathButton.addTarget(self, action: #selector(copyBackupPath), for: .touchUpInside)
        copyBackupPathButton.isHidden = true
        containerView.addArrangedSubviews([
            titleLabel,
            revealButton,
            mnemonicView,
            backupPathLabel,
            copyBackupPathButton,
            nextButton,
            googleButton
        ])

        containerView.setCustomSpacing(16, after: nextButton)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            containerView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16)
        ])
        // 16 from each side on a phone; a readable column in the middle of a wider window.
        WalletDisplay.pinReadable(containerView, inScroll: scrollView, margin: 16)
        
        NSLayoutConstraint.activate([
            loadingView.widthAnchor.constraint(equalTo: view.widthAnchor),
            loadingView.heightAnchor.constraint(equalTo: view.heightAnchor),
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        soramitsuView.sora.backgroundColor = .bgPage

        googleButton.isHidden = mode == .view || mode == .registration
        nextButton.isHidden = mode == .view
    }

    override func viewWillDisappear(_ animated: Bool) {
        hidePhrase()
        super.viewWillDisappear(animated)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if isViewLoaded { updatePhraseVisibility() }
    }

    static func phraseColumns(canvas: LayoutCanvas, accessibilitySize: Bool) -> Int {
        if accessibilitySize { return 1 }
        return canvas.isWide ? 3 : 2
    }

    @objc private func togglePhrase() {
        if phraseRevealed { hidePhrase(); return }
        guard !phraseWords.isEmpty, UIApplication.shared.applicationState == .active,
              !(view.window?.windowScene?.screen.isCaptured ?? UIScreen.main.isCaptured) else { return }
        phraseRevealed = true
        updatePhraseVisibility()
        hideTimer?.invalidate()
        let timer = Timer(timeInterval: 60, repeats: false) { [weak self] _ in self?.hidePhrase() }
        hideTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    @objc private func hidePhrase() {
        phraseRevealed = false
        hideTimer?.invalidate(); hideTimer = nil
        updatePhraseVisibility()
    }

    private func updatePhraseVisibility() {
        var words = phraseRevealed ? phraseWords : []
        // Two columns on a phone. A wide window (an unfolded screen) has room for three, so even a
        // 24-word phrase is on screen at once, to be copied down without scrolling.
        let columns = Self.phraseColumns(canvas: WalletDisplay.canvas(for: viewIfLoaded),
                                         accessibilitySize: traitCollection.preferredContentSizeCategory.isAccessibilityCategory)
        while words.count % columns != 0 { words.append("") }
        mnemonicView.bind(words: words, columnsCount: columns)
        mnemonicView.isHidden = !phraseRevealed
        mnemonicView.accessibilityElementsHidden = !phraseRevealed
        backupPathLabel.text = phraseRevealed ? WalletUX.text("Also save this derivation path:") + "\n" + backupPath : nil
        backupPathLabel.isHidden = !phraseRevealed || backupPath.isEmpty
        copyBackupPathButton.isHidden = !phraseRevealed || !WalletSecretCopy.allowsCopying(derivationPath: backupPath)
        revealButton.setTitle(phraseRevealed ? R.string.localizable.commonHide(preferredLanguages: .currentLocale) : WalletUX.text("Show my recovery phrase"), for: .normal)
    }

    private func setupNavigationItem() {
        navigationItem.rightBarButtonItem = createRightButtonItem()
    }

    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        title = R.string.localizable.mnemonicTitle(preferredLanguages: locale.rLanguages).capitalized
        titleLabel.sora.text = R.string.localizable.mnemonicText(preferredLanguages: locale.rLanguages)
        nextButton.sora.title = mode.nextButtonTitle
        
        navigationItem.rightBarButtonItem = createRightButtonItem()
    }

    @IBAction private func actionNext() {
        hidePhrase()
        presenter.proceed()
    }

    
    @objc private func actionOpenInfo() {
        presenter.activateInfo()
    }

    @objc private func actionSkip() {
        let title = R.string.localizable.importAccountNotBackedUp(preferredLanguages: .currentLocale)
        let message = R.string.localizable.importAccountNotBackedUpAlertDescription(preferredLanguages: .currentLocale)
        let alertView = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(
            title: R.string.localizable.commonCancel(preferredLanguages: .currentLocale),
            style: .cancel) { (_: UIAlertAction) -> Void in
            }
        let useAction = UIAlertAction(
            title: R.string.localizable.importAccountNotBackedUpAlertActionTitle(preferredLanguages: .currentLocale),
            style: .destructive) { [weak self] (_: UIAlertAction) -> Void in
                self?.presenter.skip()
            }
        alertView.addAction(useAction)
        alertView.addAction(cancelAction)
        
        present(alertView, animated: true)
    }
    
    private func createRightButtonItem() -> UIBarButtonItem? {
        switch mode {
        case .registrationWithoutAccessToGoogle:
            let skipButton = UIBarButtonItem(title: R.string.localizable.commonSkip(preferredLanguages: .currentLocale),
                                             style: .plain,
                                             target: self,
                                             action: #selector(actionSkip))
            // Styled by the bar appearance (`NeonChrome`): no red text on bars.
            return skipButton
        case .view:
            let infoItem = UIBarButtonItem(image: R.image.linkInfo(),
                                           style: .plain,
                                           target: self,
                                           action: #selector(actionOpenInfo))
            infoItem.tintColor = SoramitsuUI.shared.theme.palette.color(.accentTertiary)
            return infoItem
        case .registration:
            return nil
        }
    }
}

extension AccountCreateViewController: AccountCreateViewProtocol {
    func set(backupDerivationPath: String) {
        backupPath = backupDerivationPath
        updatePhraseVisibility()
    }

    @objc private func copyBackupPath() {
        guard phraseRevealed, WalletSecretCopy.allowsCopying(derivationPath: backupPath) else { return }
        UIPasteboard.general.setItems([["public.utf8-plain-text": backupPath]],
            options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(45)])
    }

    func set(mnemonic: [String]) {
        phraseWords = mnemonic
        hidePhrase()
    }

    func showLoading() {
        loadingView.isHidden = false
    }
    
    func hideLoading() {
        googleButton.isUserInteractionEnabled = true
        loadingView.isHidden = true
    }
}

extension AccountCreateViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
