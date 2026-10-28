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
import SoraUIKit
import SoraFoundation

final class SetupAccountNameViewController: SoramitsuViewController {
    var presenter: UsernameSetupPresenterProtocol?
    
    private let scrollView = UIScrollView()

    private var viewModel: InputViewModelProtocol?
    
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
    
    private lazy var usernameField: InputField = {
        let view = InputField()
        view.textField.sora.dynamicTextStyle = .body
        view.textField.accessibilityLabel = R.string.localizable.personalInfoUsernameV1(preferredLanguages: .currentLocale)
        view.titleLabel.sora.dynamicTextStyle = .caption1
        view.descriptionLabel.sora.dynamicTextStyle = .caption1
        view.textField.textContentType = .nickname
        view.textField.autocapitalizationType = .none
        view.textField.autocorrectionType = .no
        view.textField.spellCheckingType = .no
        view.textField.keyboardType = .alphabet
        view.sora.state = .default
        view.sora.titleLabelText = R.string.localizable.personalInfoUsernameV1(preferredLanguages: .currentLocale)
        view.textField.returnKeyType = .done
        view.textField.sora.placeholder = R.string.localizable.personalInfoUsernameV1(preferredLanguages: .currentLocale)
        view.sora.descriptionLabelText = R.string.localizable.onboardingCreateAccountSubtitle(preferredLanguages: .currentLocale)
        view.textField.delegate = self
        #if (arch(x86_64))
        view.textField.sora.addHandler(for: .editingChanged) { [weak self] in
            //INFO: Added for autotests
            self?.viewModel?.inputHandler.changeValue(to: view.textField.sora.text ?? "")
        }
        #endif
        return view
    }()

    private lazy var createAccountButton: UIButton = {
        let button = WalletUX.button(R.string.localizable.transactionContinue(preferredLanguages: .currentLocale), primary: true) { [weak self] in
            guard let self else { return }
            self.usernameField.textField.resignFirstResponder()
            self.presenter?.userName = self.usernameField.textField.text
            self.presenter?.proceed()
        }
        button.isEnabled = true
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.backButtonTitle = ""
        navigationItem.largeTitleDisplayMode = .never
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        title = R.string.localizable.onboardingCreateAccountTitle(preferredLanguages: .currentLocale)
        setupView()
        setupConstraints()
        presenter?.setup()
        usernameField.textField.becomeFirstResponder()
    }
    
    func setupView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)
        scrollView.addSubview(containerView)
        createAccountButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubviews(subtitleLabel, usernameField, createAccountButton)
        for child in usernameField.subviews {
            for constraint in child.constraints where constraint.firstAttribute == .height && constraint.secondItem == nil && constraint.constant == 56 {
                constraint.isActive = false
                child.heightAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true
            }
        }
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
            
            createAccountButton.topAnchor.constraint(equalTo: usernameField.bottomAnchor, constant: 24),
            createAccountButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            createAccountButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            createAccountButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24),
        ])
    }
}

extension SetupAccountNameViewController: UITextFieldDelegate {
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

        guard let viewModel = viewModel else {
            return true
        }

        let shouldApply = viewModel.inputHandler.didReceiveReplacement(string,
                                                                       for: range,
                                                                       displayedText: textField.text ?? "")

        if !shouldApply, textField.text != viewModel.inputHandler.value {
            textField.text = viewModel.inputHandler.value
        }

        return shouldApply
    }
}


extension SetupAccountNameViewController: UsernameSetupViewProtocol {
    func set(viewModel: InputViewModelProtocol) {
        self.viewModel = viewModel
    }
    
    func resetFocus() {
        usernameField.becomeFirstResponder()
    }
}
