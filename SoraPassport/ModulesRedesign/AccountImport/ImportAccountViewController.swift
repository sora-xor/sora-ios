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
    
    private var viewModel: InputViewModelProtocol?
    private var sourceViewModel: InputViewModelProtocol?
    
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
        label.sora.textColor = .fgPrimary
        label.sora.text = R.string.localizable.onboardingCreateAccountDescription(preferredLanguages: .currentLocale)
        label.sora.alignment = .left
        return label
    }()
    
    private lazy var usernameField: InputTextView = {
        InputTextView().then {
            $0.sora.state = .default
            $0.textView.sora.isScrollEnabled = false
            $0.textView.autocorrectionType = .no
            $0.textView.returnKeyType = .done
            $0.textView.autocapitalizationType = .none
            $0.delegate = self
            $0.accessibilityIdentifier = "textView"
        }
    }()

    private lazy var createAccountButton: SoramitsuButton = {
        let button = SoramitsuButton()
        button.sora.horizontalOffset = 0
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .accentPrimary
        button.sora.isEnabled = false
        button.sora.title = R.string.localizable.transactionContinue(preferredLanguages: .currentLocale)
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            guard let self = self else { return }
            self.usernameField.textView.resignFirstResponder()
            self.presenter?.proceed()
        }
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
        view.addSubview(containerView)
        containerView.addSubviews(subtitleLabel, usernameField, createAccountButton)
    }
    
    func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
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
        
        guard let viewModel = viewModel else {
            return true
        }
        
        let shouldApply = viewModel.inputHandler.didReceiveReplacement(string, for: range)
        
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

        let shouldApply = model.inputHandler.didReceiveReplacement(text, for: range)

        if !shouldApply, textView.text != model.inputHandler.value {
            textView.text = model.inputHandler.normalizedValue
            createAccountButton.sora.isEnabled = !textView.text.isEmpty
        }

        return shouldApply
    }
    
    func textViewDidChange(_ textView: UITextView) {
        createAccountButton.sora.isEnabled = !textView.text.isEmpty
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
    }

    func setSource(viewModel: InputViewModelProtocol) {
        sourceViewModel = viewModel
    }

    func setName(viewModel: InputViewModelProtocol) {}

    func setPassword(viewModel: InputViewModelProtocol) {}

    func setDerivationPath(viewModel: InputViewModelProtocol) {}

    func setUploadWarning(message: String) {}
    
    func dismissPresentedController() {
        dismiss(animated: true)
    }
}
