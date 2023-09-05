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
                                      fontData: ScreenSizeMapper.value(small: FontType.displayS, medium: FontType.displayL, large: FontType.displayL),
                                      textColor: .fgPrimary,
                                      alignment: .center)
        
        let sora = SoramitsuTextItem(text:  "\nSORA",
                                     fontData: ScreenSizeMapper.value(small: FontType.displayS, medium: FontType.displayL, large: FontType.displayL),
                                     textColor: .accentPrimary,
                                     alignment: .center)
        let label = SoramitsuLabel()
        label.sora.numberOfLines = 0
        label.sora.attributedText = [ title, sora ]
        return label
    }()
    
    let subtitleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.numberOfLines = 0
        label.sora.font = FontType.paragraphS
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
    
    private lazy var createAccountButton: SoramitsuButton = {
        let title = SoramitsuTextItem(text: R.string.localizable.create_account_title(preferredLanguages: .currentLocale),
                                      fontData: FontType.buttonM,
                                      textColor: .bgSurface,
                                      alignment: .center)
        
        let button = SoramitsuButton()
        button.sora.horizontalOffset = 0
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .accentPrimary
        button.sora.attributedText = title
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.presenter.activateSignup()
        }
        return button
    }()
    
    private lazy var importAccountButton: SoramitsuButton = {
        let title = SoramitsuTextItem(text: R.string.localizable.recoveryTitleV2(preferredLanguages: .currentLocale),
                                      fontData: FontType.buttonM,
                                      textColor: .accentPrimary,
                                      alignment: .center)
        
        let button = SoramitsuButton()
        button.sora.horizontalOffset = 0
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .custom(uiColor: .clear)
        button.sora.attributedText = title
        button.sora.borderColor = .accentPrimary
        button.sora.borderWidth = 1
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.presenter.activateAccountRestore()
        }
        return button
    }()
    
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
    
    func decorate(label: NantesLabel) {
        label.delegate = self
        label.linkAttributes = [
            NSAttributedString.Key.foregroundColor: SoramitsuUI.shared.theme.palette.color(.accentPrimary)
        ]
        var text = label.text ?? ""
        let links: [(URL, NSRange)] = linkDecorator.links(inText: &text)
        
        let attributedText = SoramitsuTextItem(text: text,
                                     fontData: FontType.textXS,
                                     textColor: .fgPrimary,
                                     alignment: .center).attributedString
        
        label.attributedText = attributedText
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
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        presenter.viewWillAppear()
    }
    
    func setupView() {
        view.addSubview(containerView)
        containerView.addSubviews(logo, titleLabel, subtitleLabel, googleButton, createAccountButton, importAccountButton, termsLabel)
        decorate(label: termsLabel)
        view.addSubview(loadingView)
    }
    
    func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            logo.topAnchor.constraint(equalTo: containerView.topAnchor, constant: -56),
            logo.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 80),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            subtitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            subtitleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            createAccountButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 16),
            createAccountButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            createAccountButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            importAccountButton.topAnchor.constraint(equalTo: createAccountButton.bottomAnchor, constant: 16),
            importAccountButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            importAccountButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            termsLabel.topAnchor.constraint(equalTo: importAccountButton.bottomAnchor, constant: 16),
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
