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
import Then
import Anchorage
import SSFCloudStorage

final class AccountOptionsViewController: SoramitsuViewController {
    var presenter: AccountOptionsPresenterProtocol!

    private lazy var scrollView: SoramitsuScrollView = {
        let scrollView = SoramitsuScrollView()
        scrollView.sora.keyboardDismissMode = .onDrag
        scrollView.sora.showsVerticalScrollIndicator = false
        scrollView.delegate = self
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()
    
    private let stackView: SoramitsuStackView = {
        SoramitsuStackView().then {
            $0.sora.axis = .vertical
            $0.spacing = 16
            $0.sora.cornerRadius = .large
            $0.sora.distribution = .fill
            $0.layoutMargins = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
            $0.isLayoutMarginsRelativeArrangement = true
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }()
    
    private lazy var addressView: SoramitsuControl = {
        SoramitsuControl().then {
            $0.sora.cornerRadius = .max
            $0.sora.backgroundColor = .bgSurface
            $0.sora.shadow = .small
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.sora.addHandler(for: .touchUpInside) { [weak self] in
                self?.presenter.copyToClipboard()
            }
        }
    }()

    lazy var titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline4
        label.sora.textColor = .fgSecondary
        label.sora.text = R.string.localizable.accountAddress(preferredLanguages: .currentLocale).uppercased()
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    lazy var addressLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var usernameField: InputField = {
        InputField().then {
            $0.sora.leftImage = R.image.profile.editName()?.tinted(with: SoramitsuUI.shared.theme.palette.color(.fgSecondary))
            $0.sora.state = .default
            $0.sora.titleLabelText = R.string.localizable.personalInfoUsernameV1(preferredLanguages: .currentLocale)
            $0.textField.returnKeyType = .done
            $0.textField.sora.placeholder = R.string.localizable.personalInfoUsernameV1(preferredLanguages: .currentLocale)
            $0.textField.sora.addHandler(for: .editingChanged) { [weak self] in
                self?.presenter.didUpdateUsername(self?.usernameField.textField.text ?? "")
            }
        }
    }()
    
    private let loadingView: SoramitsuLoadingView = {
        let view = SoramitsuLoadingView()
        view.isHidden = true
        view.isUserInteractionEnabled = true
        return view
    }()

    private let optionsCard: Card  = {
        Card().then {
            $0.sora.cornerRadius = .max
        }
    }()

    private lazy var logoutButton: SoramitsuButton = {
        SoramitsuButton(size:.large, type: .tonal(.tertiary)).then {
            $0.sora.cornerRadius = .circle
            $0.addTarget(nil, action: #selector(logoutTapped), for: .touchUpInside)
        }
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        configure()
        addCloseButton()
        presenter.setup()
    }

    private func configure() {
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.title = R.string.localizable.accountOptions(preferredLanguages: .currentLocale)
        
        addressView.addSubviews(titleLabel, addressLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: addressView.leadingAnchor, constant: 24),
            titleLabel.centerXAnchor.constraint(equalTo: addressView.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: addressView.topAnchor, constant: 24),
            
            addressLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            addressLabel.leadingAnchor.constraint(equalTo: addressView.leadingAnchor, constant: 24),
            addressLabel.centerXAnchor.constraint(equalTo: addressView.centerXAnchor),
            addressLabel.bottomAnchor.constraint(equalTo: addressView.bottomAnchor, constant: -24),
        ])

        scrollView.addSubview(stackView)
        
        view.addSubviews(scrollView)
        view.addSubview(loadingView)
                
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),

            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            loadingView.widthAnchor.constraint(equalTo: view.widthAnchor),
            loadingView.heightAnchor.constraint(equalTo: view.heightAnchor),
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        
        stackView.addArrangedSubviews(usernameField, addressView, optionsCard, logoutButton)
        stackView.setCustomSpacing(12, after: usernameField)

        usernameField.do {
            $0.sora.titleLabelText = R.string.localizable
                .personalInfoUsernameV1(preferredLanguages: languages)
        }

        optionsCard.do {
            $0.headerText = R.string.localizable.exportAccountDetailsBackupOptions(preferredLanguages: languages).uppercased()
            $0.footerText = R.string.localizable.exportAccountDetailsBackupDescription(preferredLanguages: languages)
        }

        logoutButton.do {
            $0.sora.title = R.string.localizable.forgetAccount(preferredLanguages: languages)
        }
        
        view.setNeedsLayout()
    }

    @objc
    func passphraseTapped() {
        presenter.showPassphrase()
    }

    @objc
    func rawSeedTapped() {
        presenter.showRawSeed()
    }

    @objc
    func jsoneTapped() {
        presenter.showJson()
    }

    @objc
    func logoutTapped() {
        presenter.doLogout()
    }
    
    func deleteBackup() {
        let title = R.string.localizable.deleteBackupAlertTitle(preferredLanguages: .currentLocale)
        let message = R.string.localizable.deleteBackupAlertDescription(preferredLanguages: .currentLocale)
        let alertView = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(
            title: R.string.localizable.commonCancel(preferredLanguages: .currentLocale),
            style: .cancel) { (_: UIAlertAction) -> Void in
            }
        let useAction = UIAlertAction(
            title: R.string.localizable.commonDelete(preferredLanguages: .currentLocale),
            style: .destructive) { [weak self] (_: UIAlertAction) -> Void in
                self?.presenter.deleteBackup()
            }
        alertView.addAction(useAction)
        alertView.addAction(cancelAction)
        
        present(alertView, animated: true)
    }
}

extension AccountOptionsViewController: AccountOptionsViewProtocol {
    func didReceive(username: String) {
        self.usernameField.sora.text = username
    }
    
    func didReceive(address: String) {
        addressLabel.sora.text = address
    }
    
    func setupOptions(with backUpState: BackupState, hasEntropy: Bool) {
        var options: [SoramitsuView] = []
        
        if hasEntropy {
            options.append(AccountOptionItem().then({
                $0.titleLabel.sora.text = R.string.localizable.exportAccountDetailsShowPassphrase(preferredLanguages: languages)
                $0.leftImageView.image = R.image.profile.passPhrase()
                $0.addArrow()
                $0.addTapGesture { [weak self] recognizer in
                    self?.passphraseTapped()
                }
            }))
            options.append(AccountOptionSeparator())
        }
            
        options.append(contentsOf: [
            AccountOptionItem().then({
                $0.titleLabel.sora.text = R.string.localizable.exportAccountDetailsShowRawSeed(preferredLanguages: languages)
                $0.leftImageView.image = R.image.profile.seed()
                $0.addArrow()
                $0.addTapGesture { [weak self] recognizer in
                    self?.rawSeedTapped()
                }
            }),
            AccountOptionSeparator(),
            AccountOptionItem().then({
                $0.titleLabel.sora.text = R.string.localizable.exportProtectionJsonTitle(preferredLanguages: languages)
                $0.leftImageView.image = R.image.profile.export()
                $0.addArrow()
                $0.addTapGesture { [weak self] recognizer in
                    self?.jsoneTapped()
                }
            }),
            AccountOptionSeparator(),
            AccountOptionItem().then({
                $0.titleLabel.sora.textColor = backUpState.optionTitleColor
                $0.titleLabel.sora.text = backUpState.optionTitle
                $0.leftImageView.image = R.image.googleOptionIcon()
                $0.addArrow()
                $0.addTapGesture { [weak self] recognizer in
                    if backUpState == .backedUp {
                        self?.deleteBackup()
                    } else {
                        self?.presenter.createBackup()
                    }
                }
            })
        ])

        optionsCard.stackContents = options
    }

    func showLoading() {
        loadingView.isHidden = false
    }

    func hideLoading() {
        DispatchQueue.main.async {
            self.loadingView.isHidden = true
        }
    }
}


extension AccountOptionsViewController: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    func applyLocalization() {
        navigationItem.title = R.string.localizable.exportAccountOptions(preferredLanguages: languages)

        usernameField.do {
            $0.sora.titleLabelText = R.string.localizable
                .personalInfoUsernameV1(preferredLanguages: languages)
        }

        optionsCard.do {
            $0.headerText = R.string.localizable.exportAccountDetailsBackupOptions(preferredLanguages: languages)
            $0.footerText = R.string.localizable.exportAccountDetailsBackupDescription(preferredLanguages: languages)
        }

        logoutButton.do {
            $0.sora.title = R.string.localizable.forgetAccount(preferredLanguages: languages)
        }
    }
}
