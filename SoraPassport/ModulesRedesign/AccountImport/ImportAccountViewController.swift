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
import SoraFoundation

final class ImportAccountViewController: SoramitsuViewController {
    var presenter: AccountImportPresenterProtocol?
    
    private let scrollView = UIScrollView()

    private var viewModel: InputViewModelProtocol?
    private var sourceViewModel: InputViewModelProtocol?
    private var derivationPathModel: InputViewModelProtocol?
    private var passwordModel: InputViewModelProtocol?
    private let optionsStack = UIStackView()
    private let advancedStack = UIStackView()
    private let cryptoButton = UIButton(type: .system)
    private let pathField = UITextField()
    private let passwordField = UITextField()
    private let passwordLabel = WalletUX.label(WalletUX.text("Backup file password"), style: .subheadline)
    private lazy var advancedButton: UIButton = WalletUX.button(WalletUX.text("Advanced options")) { [weak self] in
        guard let self else { return }
        self.advancedStack.isHidden.toggle()
        self.advancedButton.accessibilityValue = self.advancedStack.isHidden
            ? WalletUX.text("Collapsed") : WalletUX.text("Expanded")
    }

    
    let containerView: SoramitsuView = {
        let view = SoramitsuView()
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerRadius = .max
        view.sora.clipsToBounds = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let subtitleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.numberOfLines = 0
        label.sora.font = FontType.paragraphM
        label.sora.dynamicTextStyle = .body
        label.sora.textColor = .fgPrimary
        label.sora.text = R.string.localizable.onboardingCreateAccountDescription(preferredLanguages: .currentLocale)
        label.sora.alignment = .left
        return label
    }()
    
    private lazy var usernameField: InputTextView = {
        InputTextView().then {
            $0.sora.state = .default
            $0.textView.sora.isScrollEnabled = false
            $0.textView.sora.dynamicTextStyle = .body
            $0.textView.autocorrectionType = .no
            $0.textView.returnKeyType = .done
            $0.textView.autocapitalizationType = .none
            $0.delegate = self
            $0.accessibilityIdentifier = "textView"
        }
    }()

    private lazy var createAccountButton: UIButton = {
        let button = WalletUX.button(R.string.localizable.transactionContinue(preferredLanguages: .currentLocale), primary: true) { [weak self] in
            guard let self else { return }
            self.view.endEditing(true)
            self.presenter?.proceed()
        }
        button.isEnabled = false
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.backButtonTitle = ""
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        setupView()
        setupConstraints()
        presenter?.setup()
        usernameField.textView.becomeFirstResponder()
    }
    
    func setupView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)
        scrollView.addSubview(containerView)
        createAccountButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubviews(subtitleLabel, usernameField, optionsStack, createAccountButton)
        optionsStack.axis = .vertical
        optionsStack.spacing = 12
        optionsStack.translatesAutoresizingMaskIntoConstraints = false
        advancedStack.axis = .vertical
        advancedStack.spacing = 10
        advancedStack.isHidden = true
        optionsStack.addArrangedSubview(passwordLabel)
        optionsStack.addArrangedSubview(passwordField)
        optionsStack.addArrangedSubview(advancedButton)
        optionsStack.addArrangedSubview(advancedStack)
        advancedButton.accessibilityIdentifier = "wallet-import-advanced"
        advancedStack.addArrangedSubview(WalletUX.label(WalletUX.text("Key type"), style: .subheadline))
        advancedStack.addArrangedSubview(cryptoButton)
        cryptoButton.contentHorizontalAlignment = .leading
        cryptoButton.titleLabel?.font = .preferredFont(forTextStyle: .body)
        cryptoButton.showsMenuAsPrimaryAction = true
        cryptoButton.accessibilityIdentifier = "wallet-import-crypto-type"
        advancedStack.addArrangedSubview(WalletUX.label(WalletUX.text("Derivation path (optional)"), style: .subheadline))
        advancedStack.addArrangedSubview(pathField)
        for field in [pathField, passwordField] {
            field.borderStyle = .roundedRect
            field.font = .preferredFont(forTextStyle: .body)
            field.adjustsFontForContentSizeCategory = true
            field.autocorrectionType = .no
            field.autocapitalizationType = .none
            field.spellCheckingType = .no
            field.delegate = self
            field.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            field.addTarget(self, action: #selector(importOptionChanged(_:)), for: .editingChanged)
        }
        pathField.accessibilityIdentifier = "wallet-import-derivation-path"
        passwordField.accessibilityIdentifier = "wallet-import-json-password"
        passwordField.isSecureTextEntry = true
        passwordField.textContentType = .password
        passwordField.placeholder = WalletUX.text("Backup file password")
        passwordLabel.isHidden = true
        passwordField.isHidden = true
    }
    
    @objc private func importOptionChanged(_ field: UITextField) {
        let model = field === pathField ? derivationPathModel : passwordModel
        model?.inputHandler.changeValue(to: field.text ?? "")
    }

    func setupConstraints() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            containerView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            containerView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            containerView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            containerView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32),
            
            subtitleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            subtitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            subtitleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            usernameField.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            usernameField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            usernameField.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            optionsStack.topAnchor.constraint(equalTo: usernameField.bottomAnchor, constant: 16),
            optionsStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            optionsStack.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            createAccountButton.topAnchor.constraint(equalTo: optionsStack.bottomAnchor, constant: 24),
            createAccountButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            createAccountButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            createAccountButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24),
        ])
    }
}

extension ImportAccountViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        
        return false
    }
    
    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        
        //INFO: on x86_64 architecture it called twice and make crash of app in didReceiveReplacement method. Added for autotests
        #if (arch(x86_64))
            return true
        #endif
        
        guard let viewModel = textField === pathField ? derivationPathModel : passwordModel else {
            return true
        }
        
        let shouldApply = viewModel.inputHandler.didReceiveReplacement(string,
                                                                       for: range,
                                                                       displayedText: textField.text ?? "")
        
        if !shouldApply, textField.text != viewModel.inputHandler.value {
            textField.text = viewModel.inputHandler.normalizedValue
        }
        
        return shouldApply
    }
}

extension ImportAccountViewController: InputTextViewDelegate {
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        //INFO: on x86_64 architecture it called twice and make crash of app in didReceiveReplacement method. Added for autotests
        #if (arch(x86_64))
            return true
        #endif

        guard let model = sourceViewModel else {
            return false
        }

        let shouldApply = model.inputHandler.didReceiveReplacement(text,
                                                                   for: range,
                                                                   displayedText: textView.text ?? "")

        if !shouldApply, textView.text != model.inputHandler.value {
            textView.text = model.inputHandler.normalizedValue
            createAccountButton.isEnabled = !textView.text.isEmpty
        }

        return shouldApply
    }
    
    func textViewDidChange(_ textView: UITextView) {
        createAccountButton.isEnabled = !textView.text.isEmpty
        //INFO: Added for autotests
        #if (arch(x86_64))
            sourceViewModel?.inputHandler.changeValue(to: textView.text)
        #endif
    }
}

extension ImportAccountViewController: AccountImportViewProtocol {
    func resetFocus() {
        usernameField.textView.becomeFirstResponder()
    }
    
    func setSource(type: AccountImportSource) {
        title = type.navigationTitle
        subtitleLabel.sora.text = type.containerTitle
        let isJSON = type == .keystore
        advancedButton.isHidden = isJSON
        advancedStack.isHidden = true
        passwordField.isHidden = !isJSON
        passwordLabel.isHidden = !isJSON
    }

    func setSource(viewModel: InputViewModelProtocol) {
        sourceViewModel = viewModel
        usernameField.textView.text = viewModel.inputHandler.value
        createAccountButton.isEnabled = !viewModel.inputHandler.value.isEmpty
    }

    func setName(viewModel: InputViewModelProtocol) {}

    func setPassword(viewModel: InputViewModelProtocol) {
        passwordModel = viewModel
        passwordField.text = viewModel.inputHandler.value
    }

    func setDerivationPath(viewModel: InputViewModelProtocol) {
        derivationPathModel = viewModel
        pathField.text = viewModel.inputHandler.value
        pathField.placeholder = viewModel.placeholder
    }

    func setCryptoType(_ type: CryptoType, available: [CryptoType]) {
        cryptoButton.setTitle(type.typeString, for: .normal)
        cryptoButton.menu = UIMenu(children: available.map { choice in
            UIAction(title: choice.typeString, state: choice == type ? .on : .off) { [weak self] _ in
                self?.presenter?.selectCryptoType(choice)
            }
        })
    }

    func setUploadWarning(message: String) {}
    
    func dismissPresentedController() {
        dismiss(animated: true)
    }
}
