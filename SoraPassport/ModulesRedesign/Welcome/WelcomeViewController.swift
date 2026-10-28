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
import SoraKeystore
import SoraUIKit
import Nantes

final class WelcomeViewController: SoramitsuViewController {
    var presenter: OnboardingMainPresenterProtocol!
    
    let logo: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.image = R.image.soraLogoBig()
        view.sora.cornerRadius = .circle
        view.sora.backgroundColor = .bgSurface
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 112).isActive = true
        view.widthAnchor.constraint(equalToConstant: 112).isActive = true
        return view
    }()
    
    let containerView: SoramitsuView = {
        let view = SoramitsuView()
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerRadius = .max
        view.sora.clipsToBounds = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let titleLabel: SoramitsuLabel = {
        let title = SoramitsuTextItem(text:  R.string.localizable.tutorialManyWorld(preferredLanguages: .currentLocale),
                                      fontData: FontType.headline1,
                                      textColor: .fgPrimary,
                                      alignment: .center)
        
        let sora = SoramitsuTextItem(text:  "\nSORA",
                                     fontData: FontType.headline1,
                                     textColor: .accentPrimary,
                                     alignment: .center)
        let label = SoramitsuLabel()
        label.sora.numberOfLines = 0
        label.sora.attributedText = [ title, sora ]
        label.sora.dynamicTextStyle = .title1
        return label
    }()
    
    let subtitleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.numberOfLines = 0
        label.sora.font = FontType.paragraphS
        label.sora.dynamicTextStyle = .body
        label.sora.textColor = .fgPrimary
        label.sora.text = R.string.localizable.onboardingDescription(preferredLanguages: .currentLocale)
        label.sora.alignment = .center
        return label
    }()
    
    private lazy var googleButton: SoramitsuButton = {
        let title = SoramitsuTextItem(text: R.string.localizable.onboardingContinueWithGoogle(preferredLanguages: .currentLocale),
                                      fontData: FontType.buttonM,
                                      textColor: .accentSecondary,
                                      alignment: .center)
        
        let button = SoramitsuButton()
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .custom(uiColor: .clear)
        button.sora.attributedText = title
        button.sora.imageSize = 37
        button.sora.leftImage = R.image.googleIcon()
        button.sora.borderColor = .accentSecondary
        button.sora.borderWidth = 1
        button.sora.isHidden = true
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.googleButton.isUserInteractionEnabled = false
            self?.loadingView.isHidden = false
            self?.presenter.activateCloudStorageConnection()
        }
        return button
    }()
    
    private lazy var createAccountButton = WalletUX.button(
        R.string.localizable.create_account_title(preferredLanguages: .currentLocale), primary: true
    ) { [weak self] in self?.presenter.activateSignup() }

    private lazy var importAccountButton = WalletUX.button(
        R.string.localizable.recoveryTitleV2(preferredLanguages: .currentLocale)
    ) { [weak self] in self?.presenter.activateAccountRestore() }

    private lazy var earlierDataButton: WalletNeonButton = {
        let button = WalletSafeMode.button(.secondary, title: WalletUX.text("Use the earlier wallet data again"))
        button.accessibilityIdentifier = "wallet-onboarding-earlier-data"
        button.isHidden = true
        button.addTarget(self, action: #selector(restoreEarlierData), for: .touchUpInside)
        return button
    }()
    private lazy var actionsStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [createAccountButton, importAccountButton, earlierDataButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    @objc private func restoreEarlierData() {
        WalletPreservedDataRestoration.present(on: self) { [weak self] in
            guard let window = self?.view.window as? SoraWindow else { return }
            RootWireframe.restartStartup(on: window)
        }
    }

    private let scrollView = UIScrollView()

    lazy var termDecorator: AttributedStringDecoratorProtocol = {
        CompoundAttributedStringDecorator.legalRedesign(for: Locale.current)
    }()
    
    let loadingView: SoramitsuLoadingView = {
        let view = SoramitsuLoadingView()
        view.isHidden = true
        view.isUserInteractionEnabled = true
        return view
    }()

    public lazy var termsLabel: NantesLabel = {
        let label = NantesLabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text =  R.string.localizable.tutorialTermsAndConditionsRecovery(preferredLanguages: .currentLocale)
        label.delegate = self
        return label
    }()
    
    let linkDecorator = LinkDecoratorFactory.termsDecorator()
    /// The terms text with its link markers removed, and the links found in
    /// it; kept so the label can be re-coloured after a theme change.
    private var termsContent: (text: String, links: [(URL, NSRange)])?
    
    func decorate(label: NantesLabel) {
        label.delegate = self
        // Links are cyan and underlined, so colour is never the only signal
        // (spec §8.2, §10.1). Re-applied on every theme change.
        let link = NeonTokens.current.link
        label.linkAttributes = [
            .foregroundColor: link,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .underlineColor: link
        ]
        label.activeLinkAttributes = [
            .foregroundColor: link.withAlphaComponent(0.7),
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .underlineColor: link.withAlphaComponent(0.7)
        ]
        if termsContent == nil {
            var text = label.text ?? ""
            let links = linkDecorator.links(inText: &text)
            termsContent = (text, links)
        }
        let text = termsContent?.text ?? ""
        let links = termsContent?.links ?? []
        
        // Terms are `textXS` `text.secondary` (spec §8.2).
        let attributedText = SoramitsuTextItem(text: text,
                                     fontData: FontType.textXS,
                                     textColor: .fgSecondary,
                                     alignment: .center).attributedString
        
        let scaledText = NSMutableAttributedString(attributedString: attributedText)
        scaledText.addAttribute(.font, value: UIFontMetrics(forTextStyle: .caption1).scaledFont(for: FontType.textXS.font), range: NSRange(location: 0, length: scaledText.length))
        label.attributedText = scaledText
        label.adjustsFontForContentSizeCategory = true
        for link in links {
            label.addLink(to: link.0, withRange: link.1)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.backButtonTitle = ""
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        setupView()
        setupConstraints()
        presenter.setup()
        SoramitsuUI.updates.addObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        presenter.viewWillAppear()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    func setupView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(containerView)
        createAccountButton.translatesAutoresizingMaskIntoConstraints = false
        importAccountButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubviews(titleLabel, subtitleLabel, googleButton, actionsStack, termsLabel)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let available = (try? WalletLocalStateSetAside.Paths.production()).map {
                !WalletPreservedGeneration.available(paths: $0, settings: SettingsManager.shared).isEmpty
            } ?? false
            DispatchQueue.main.async { self?.earlierDataButton.isHidden = !available }
        }
        // The logo overlaps the card's top edge. It sits above the card, not
        // inside it: the card draws its hairline over its own subviews,
        // which put a line across the logo.
        scrollView.addSubview(logo)
        decorate(label: termsLabel)
        view.addSubview(loadingView)
    }
    
    func setupConstraints() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            containerView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 72),
            containerView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            containerView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            containerView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32),
            
            logo.topAnchor.constraint(equalTo: containerView.topAnchor, constant: -56),
            logo.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 80),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            subtitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            subtitleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            actionsStack.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 16),
            actionsStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            actionsStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            termsLabel.topAnchor.constraint(equalTo: actionsStack.bottomAnchor, constant: 16),
            termsLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            termsLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            termsLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24),

            loadingView.widthAnchor.constraint(equalTo: view.widthAnchor),
            loadingView.heightAnchor.constraint(equalTo: view.heightAnchor),
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }
}

extension WelcomeViewController: NantesLabelDelegate {
    func attributedLabel(_ label: NantesLabel, didSelectLink link: URL) {
        UIApplication.shared.open(link, options: [:], completionHandler: nil)
    }
}

extension WelcomeViewController: OnboardingMainViewProtocol {
    func showLoading() {
        loadingView.isHidden = false
    }
    
    func hideLoading() {
        googleButton.isUserInteractionEnabled = true
        loadingView.isHidden = true
    }
}

extension WelcomeViewController: SoramitsuObserver {
    /// The terms label is plain attributed text: re-colour it with the theme.
    func styleDidChange(options: UpdateOptions) {
        guard options.contains(.palette), isViewLoaded else { return }
        decorate(label: termsLabel)
    }
}
