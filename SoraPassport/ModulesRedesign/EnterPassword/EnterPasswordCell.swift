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

import SoraUIKit
import Anchorage
import FearlessUtils

final class EnterPasswordCell: SoramitsuTableViewCell {
    
    private weak var item: EnterPasswordItem?
    private let generator = PolkadotIconGenerator()

    private let descriptionLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 0
        label.sora.text = R.string.localizable.enterPasswordDescription(preferredLanguages: .currentLocale)
        return label
    }()
    
    private let accountView: AccountView = {
        let view = AccountView()
        view.sora.backgroundColor = .bgPage
        return view
    }()
    
    private lazy var passwordInputField: InputField = {
        let view = InputField()
        view.textField.autocapitalizationType = .none
        view.textField.autocorrectionType = .no
        view.textField.spellCheckingType = .no
        view.textField.keyboardType = .alphabet
        view.sora.state = .default
        view.sora.titleLabelText = R.string.localizable.enterPasswordTitle(preferredLanguages: .currentLocale)
        view.sora.textFieldPlaceholder = R.string.localizable.enterPasswordTitle(preferredLanguages: .currentLocale)
        view.textField.returnKeyType = .go
        view.textField.isSecureTextEntry = true
        return view
    }()
    
    private lazy var continueButton: SoramitsuButton = {
        let button = SoramitsuButton()
        button.sora.title = R.string.localizable.transactionContinue(preferredLanguages: .currentLocale)
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .accentPrimary
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            guard let passwordText = self?.passwordInputField.textField.text else { return }
            self?.item?.continueButtonHandler?(passwordText)
        }
        return button
    }()
    
    private let containerView: SoramitsuView = {
        var view = SoramitsuView()
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerRadius = .max
        view.sora.clipsToBounds = false
        return view
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        contentView.addSubview(containerView)
        containerView.addSubviews([descriptionLabel, accountView, passwordInputField, continueButton])
    }
    
    func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            descriptionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            descriptionLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            descriptionLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            
            accountView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            accountView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            accountView.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 16),
            
            passwordInputField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            passwordInputField.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            passwordInputField.topAnchor.constraint(equalTo: accountView.bottomAnchor, constant: 24),
            passwordInputField.heightAnchor.constraint(equalToConstant: 76),
            
            continueButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            continueButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            continueButton.topAnchor.constraint(equalTo: passwordInputField.bottomAnchor, constant: 8),
            continueButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24),
        ])
    }
}

extension EnterPasswordCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? EnterPasswordItem else {
            return
        }
        accountView.accountTitle.sora.text = item.accountName
        accountView.accountTitle.sora.isHidden = item.accountName?.isEmpty ?? true
        accountView.accountAddress.sora.text = item.accountAddress
        accountView.accountImageView.image = try? generator.generateFromAddress(item.accountAddress)
            .imageWithFillColor(.white,
                                size: CGSize(width: 40.0, height: 40.0),
                                contentScale: UIScreen.main.scale)
        passwordInputField.textField.becomeFirstResponder()

        if !item.errorText.isEmpty {
            passwordInputField.sora.descriptionLabelText = R.string.localizable.enterPasswordIncorectTitle(preferredLanguages: .currentLocale)
            passwordInputField.sora.state = .fail
        }
        
        self.item = item
    }
}
