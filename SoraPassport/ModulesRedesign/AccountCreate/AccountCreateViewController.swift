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

    private let containerView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .bgSurface
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
            $0.sora.textColor = .fgPrimary
            $0.numberOfLines = 0
        }
    }()

    private let mnemonicView: MnemonicDisplayView = {
        MnemonicDisplayView(frame: .zero).then {
            $0.indexTitleColorInColumn = .fgPrimary
            $0.wordTitleColorInColumn = .fgPrimary
            $0.indexFontInColumn = ScreenSizeMapper.value(small: FontType.textS, medium: FontType.textL, large: FontType.textL)
            $0.wordFontInColumn =  ScreenSizeMapper.value(small: FontType.textBoldS, medium: FontType.textBoldL, large: FontType.textBoldL)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }()

    private var shareButton: SoramitsuButton = {
        SoramitsuButton(size: .large, type: .tonal(.tertiary)).then {
            $0.sora.leftImage = R.image.copyNeu()
            $0.addTarget(nil, action: #selector(actionShare), for: .touchUpInside)
            $0.sora.cornerRadius = .circle
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
            self?.googleButton.isUserInteractionEnabled = false
            self?.loadingView.isHidden = false
            self?.presenter.backupToGoogle()
        }
        return button
    }()

    private var derivationPathModel: InputViewModelProtocol?

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

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appEnterToForeground),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc
    func appEnterToForeground() {
        presenter?.restoredApp()
    }

    private func configure() {

        view.addSubview(containerView)
        view.addSubview(loadingView)
        containerView.addArrangedSubviews([
            titleLabel,
            mnemonicView,
            shareButton,
            nextButton,
            googleButton
        ])

        containerView.setCustomSpacing(16, after: nextButton)
        containerView.do {
            $0.topAnchor == view.soraSafeTopAnchor
            $0.bottomAnchor <= view.soraSafeBottomAnchor
            $0.horizontalAnchors == view.horizontalAnchors + 16
        }
        
        NSLayoutConstraint.activate([
            loadingView.widthAnchor.constraint(equalTo: view.widthAnchor),
            loadingView.heightAnchor.constraint(equalTo: view.heightAnchor),
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        view.backgroundColor = .clear

        shareButton.isHidden = mode == .registration || mode == .registrationWithoutAccessToGoogle
        googleButton.isHidden = mode == .view || mode == .registration
        nextButton.isHidden = mode == .view
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
        presenter.proceed()
    }

    @IBAction private func actionShare() {
        shareButton.sora.title = R.string.localizable.commonCopied(preferredLanguages: .currentLocale)
        presenter.share()
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
            skipButton.setTitleTextAttributes([
                .font: FontType.textBoldS.font,
                .foregroundColor: SoramitsuUI.shared.theme.palette.color(.accentPrimary)
            ], for: .normal)
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
    func set(mnemonic: [String]) {
        var conditionedMnemonic = mnemonic
        if mnemonic.count % 2 == 1 {
            conditionedMnemonic.append("") //Quick fix for legacy 15-word mnemonics
        }
        mnemonicView.bind(words: conditionedMnemonic, columnsCount: 2)
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

