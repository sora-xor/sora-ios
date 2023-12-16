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
import SSFUtils
import Combine

final class SetupPasswordCell: SoramitsuTableViewCell {
    private var cancellables: Set<AnyCancellable> = []
    private let input: PassthroughSubject<SetupPasswordItem.Input, Never> = .init()
    
    private weak var item: SetupPasswordItem? {
        didSet {
            guard let item = item else { return }
            let output = item.transform(input: input.eraseToAnyPublisher())
            output
                .receive(on: DispatchQueue.main)
                .sink { [weak self] event in
                    switch event {
                    case .lowSecurityPassword:
                        let descriptionLabelText = R.string.localizable.backupPasswordRequirments(preferredLanguages: .currentLocale)
                        self?.setPasswordInputField.sora.descriptionLabelText = descriptionLabelText
                        self?.setPasswordInputField.sora.state = .fail
                    case .securedPassword:
                        let descriptionLabelText = R.string.localizable.backupPasswordMandatoryReqsFulfilled(preferredLanguages: .currentLocale)
                        self?.setPasswordInputField.sora.descriptionLabelText = descriptionLabelText
                        self?.setPasswordInputField.sora.state = .success
                    case .notMatchPasswords:
                        let descriptionLabelText = R.string.localizable.createBackupPasswordNotMatched(preferredLanguages: .currentLocale)
                        self?.confirmPasswordInputField.sora.descriptionLabelText = descriptionLabelText
                        self?.confirmPasswordInputField.sora.state = .fail
                    case .matchedPasswords:
                        let descriptionLabelText = R.string.localizable.createBackupPasswordMatched(preferredLanguages: .currentLocale)
                        self?.confirmPasswordInputField.sora.descriptionLabelText = descriptionLabelText
                        self?.confirmPasswordInputField.sora.state = .success
                    }
                }
                .store(in: &cancellables)
            
            item.$isButtonEnable
                .receive(on: DispatchQueue.main)
                .sink { [weak self] value in
                    self?.continueButton.sora.isEnabled = value
                }
                .store(in: &cancellables)
        }
    }

    private let descriptionLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 0
        label.sora.text = R.string.localizable.backupPasswordTitle(preferredLanguages: .currentLocale)
        return label
    }()
    
    private lazy var setPasswordInputField: InputField = {
        let view = InputField()
        view.textField.autocapitalizationType = .none
        view.textField.autocorrectionType = .no
        view.textField.spellCheckingType = .no
        view.sora.state = .default
        view.sora.titleLabelText = R.string.localizable.createBackupSetPassword(preferredLanguages: .currentLocale)
        view.sora.textFieldPlaceholder = R.string.localizable.createBackupSetPassword(preferredLanguages: .currentLocale)
        view.textField.returnKeyType = .next
        view.textField.isSecureTextEntry = true
        view.sora.descriptionLabelText = R.string.localizable.backupPasswordRequirments(preferredLanguages: .currentLocale)
        view.textField.sora.addHandler(for: .editingChanged) { [weak self] in
            self?.input.send(.passwordChanged(view.textField.text ?? ""))
        }
        view.textField.sora.addHandler(for: .editingDidEndOnExit) { [weak self] in
            self?.confirmPasswordInputField.textField.becomeFirstResponder()
        }
        return view
    }()
    
    private lazy var confirmPasswordInputField: InputField = {
        let view = InputField()
        view.textField.autocapitalizationType = .none
        view.textField.autocorrectionType = .no
        view.textField.spellCheckingType = .no
        view.sora.state = .default
        view.sora.titleLabelText = R.string.localizable.exportJsonInputLabel(preferredLanguages: .currentLocale)
        view.sora.textFieldPlaceholder = R.string.localizable.exportJsonInputLabel(preferredLanguages: .currentLocale)
        view.textField.returnKeyType = .go
        view.textField.isSecureTextEntry = true
        view.textField.sora.addHandler(for: .editingChanged) { [weak self] in
            self?.input.send(.confirmPasswordChanged(view.textField.text ?? ""))
        }
        return view
    }()
    
    private lazy var checkView: CheckView = {
        let view = CheckView(title: R.string.localizable.createBackupPasswordWarningText(preferredLanguages: .currentLocale))
        view.addTapGesture { [weak self] recognizer in
            guard let checkView = recognizer.view as? CheckView else { return }
            checkView.isSelected = !checkView.isSelected
            self?.input.send(.checkViewChanged(checkView.isSelected))
        }
        return view
    }()
    
    public lazy var continueButton: SoramitsuButton = {
        let button = SoramitsuButton()
        button.sora.title = R.string.localizable.createBackupPasswordButtonText(preferredLanguages: .currentLocale)
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .accentPrimary
        button.sora.horizontalOffset = 0
        button.sora.isEnabled = false
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.input.send(.setupPasswordButtonTapped)
        }
        return button
    }()
    
    private let containerView: SoramitsuView = {
        var view = SoramitsuView()
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerRadius = .max
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
    
    deinit {
        print("deinit")
    }
    
    private func setupView() {
        contentView.addSubview(containerView)
        containerView.addSubviews([
            descriptionLabel,
            setPasswordInputField,
            confirmPasswordInputField,
            checkView,
            continueButton
        ])
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
            
            setPasswordInputField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            setPasswordInputField.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            setPasswordInputField.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 24),
            
            confirmPasswordInputField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            confirmPasswordInputField.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            confirmPasswordInputField.topAnchor.constraint(equalTo: setPasswordInputField.bottomAnchor, constant: 16),
            confirmPasswordInputField.heightAnchor.constraint(equalToConstant: 76),
            
            checkView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            checkView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            checkView.topAnchor.constraint(equalTo: confirmPasswordInputField.bottomAnchor, constant: 16),
            
            continueButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            continueButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            continueButton.topAnchor.constraint(equalTo: checkView.bottomAnchor, constant: 24),
            continueButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24),
        ])
    }
}

extension SetupPasswordCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? SetupPasswordItem else { return }
        setPasswordInputField.textField.becomeFirstResponder()
        self.item = item
    }
}
