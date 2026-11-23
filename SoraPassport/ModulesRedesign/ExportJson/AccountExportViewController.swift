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

import Foundation
import SoraFoundation
import SoraUIKit
import Anchorage

final class AccountExportViewController: SoramitsuViewController, ControllerBackedProtocol {

    var presenter: AccountExportPresenterProtocol!

    private var containerView: SoramitsuView = {
        SoramitsuView().then {
            $0.sora.backgroundColor = .bgSurface
            $0.sora.cornerRadius = .max
            $0.layer.masksToBounds = true
            $0.sora.shadow = .default
        }
    }()

    private var stackView: SoramitsuStackView = {
        SoramitsuStackView().then {
            $0.sora.axis = .vertical
            $0.spacing = 8
            $0.layer.cornerRadius = 0
            $0.sora.distribution = .fill
        }
    }()

    private var titleLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.font = FontType.textM
            $0.sora.textColor = .fgPrimary
            $0.numberOfLines = 0
        }
    }()

    private lazy var passwordInputField: InputField = {
        let view = InputField()
        view.sora.titleLabelText = R.string.localizable.exportJsonInputLabel(preferredLanguages: languages)
        view.sora.descriptionLabelText = R.string.localizable.backupPasswordPolicyRequirements(preferredLanguages: languages)
        view.sora.textFieldPlaceholder = R.string.localizable.exportJsonInputLabel(preferredLanguages: languages)
        view.sora.keyboardType = .alphabet
        view.sora.textContentType = .newPassword
        view.textField.autocapitalizationType = .none
        view.textField.autocorrectionType = .no
        view.textField.isSecureTextEntry = true
        view.sora.addHandler(for: .editingChanged) { [weak self] in
            self?.updateState()
        }
        return view
    }()

    private lazy var confirmPasswordInputField: InputField = {
        let view = InputField()
        view.sora.titleLabelText = R.string.localizable.exportJsonInputConfirmationLabel(preferredLanguages: languages)
        view.sora.textFieldPlaceholder = R.string.localizable.exportJsonInputConfirmationLabel(preferredLanguages: languages)
        view.sora.keyboardType = .alphabet
        view.sora.textContentType = .newPassword
        view.textField.autocapitalizationType = .none
        view.textField.autocorrectionType = .no
        view.textField.isSecureTextEntry = true
        view.sora.addHandler(for: .editingChanged) { [weak self] in
            self?.updateState()
        }
        return view
    }()

    private var downloadButton: SoramitsuButton = {
        SoramitsuButton().then {
            $0.sora.isEnabled = false
            $0.sora.cornerRadius = .circle
            $0.addTarget(nil, action: #selector(downloadTapped), for: .touchUpInside)
        }
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        configure()
    }

    // The card scrolls where it does not fit between the bar and the keyboard (an iPhone SE once both
    // password notes show, a folded cover, an unfolded screen in landscape): its top never goes under the
    // bar, and the field being typed in and Download can always be reached. Where there is room the card
    // stays where it was and nothing scrolls.
    private let scrollView: UIScrollView = {
        let view = UIScrollView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.keyboardDismissMode = .interactive
        view.showsVerticalScrollIndicator = false
        return view
    }()
    private var shownHeight: CGFloat = 0

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // The keyboard came or went: the field being typed in stays on screen.
        guard scrollView.bounds.height != shownHeight else { return }
        shownHeight = scrollView.bounds.height
        revealEditedField()
    }

    @objc private func revealEditedField() {
        guard let field = [passwordInputField, confirmPasswordInputField].first(where: { $0.textField.isFirstResponder })
        else { return }
        scrollView.layoutIfNeeded()
        scrollView.scrollRectToVisible(field.convert(field.bounds, to: scrollView).insetBy(dx: 0, dy: -8), animated: false)
    }

    private func configure() {
        navigationItem.backButtonTitle = ""
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.title = R.string.localizable.exportJsonDownloadJson(preferredLanguages: languages)
        titleLabel.sora.text = R.string.localizable.exportJsonDescription(preferredLanguages: languages)

        view.addSubview(scrollView)
        scrollView.addSubview(containerView)

        stackView.removeArrangedSubviews()
        containerView.addSubview(stackView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubviews([
            passwordInputField,
            confirmPasswordInputField
        ])

        stackView.setCustomSpacing(24, after: stackView.arrangedSubviews.last!)
        stackView.addArrangedSubview(downloadButton)
        stackView.setCustomSpacing(20, after: titleLabel)
        // 16 from each side on a phone; a readable column in the middle of a wider window.
        WalletDisplay.pinReadable(containerView, inScroll: scrollView, margin: 16)
        NSLayoutConstraint.activate([
            // Under the bar by the scroll view's own safe-area inset, down to the keyboard.
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            containerView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -8)
        ])
        [passwordInputField, confirmPasswordInputField].forEach {
            $0.textField.addTarget(self, action: #selector(revealEditedField), for: .editingDidBegin)
        }
        stackView.do {
            $0.horizontalAnchors == containerView.horizontalAnchors + 24
            $0.verticalAnchors == containerView.verticalAnchors + 24
        }
    }

    private func updateState() {

        let violation = BackupPasswordPolicy.violation(for: passwordInputField.sora.text ?? "")
        let isPasswordValid = violation == nil
        let isConfirmEmpty = confirmPasswordInputField.sora.text?.isEmpty ?? true
        let isMatching = passwordInputField.sora.text == confirmPasswordInputField.sora.text

        passwordInputField.sora.descriptionLabelText = BackupPasswordPolicy.guidance(for: violation, preferredLanguages: languages)
        passwordInputField.sora.state = isPasswordValid ? .success : .fail

        confirmPasswordInputField.sora.descriptionLabelText = isMatching ? "" : isConfirmEmpty ? "" :
            R.string.localizable.exportJsonInputMatchError(preferredLanguages: languages)
        confirmPasswordInputField.sora.state = isMatching ? .success : isConfirmEmpty ? .default : .fail

        downloadButton.sora.isEnabled = isPasswordValid && isMatching
    }

    @objc
    func downloadTapped(){
        guard let password = passwordInputField.sora.text,
              BackupPasswordPolicy.violation(for: password) == nil,
              password == confirmPasswordInputField.sora.text else { return }
        presenter.exportWith(password: password)
    }
}

extension AccountExportViewController: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    func applyLocalization() {
        downloadButton.sora.title = R.string.localizable.exportJsonDownloadJson(preferredLanguages: languages)
    }
}

final class PasswordView: SoramitsuView {

    private lazy var passwordView: SoramitsuImageView = {
        SoramitsuImageView().then {
            $0.sora.borderColor = .fgPrimary
            $0.sora.cornerRadius = .circle
            $0.sora.clipsToBounds = true
            $0.sora.borderWidth = 1
            $0.clipsToBounds = true
        }
    }()

    private lazy var textLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.numberOfLines = 0
            $0.sora.lineBreakMode = .byWordWrapping
        }
    }()

    var isSelected: Bool = false {
        didSet {
            passwordView.image = isSelected ? R.image.checkboxSelected() : nil
            passwordView.sora.borderWidth = isSelected ? 0 : 1
            sora.borderColor = isSelected ? .accentPrimary : .bgSurfaceVariant
        }
    }


    init(title: String) {
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false

        addSubview(passwordView)
        addSubview(textLabel)

        sora.cornerRadius = .large
        sora.backgroundColor = .bgSurface
        sora.borderColor = isSelected ? .accentPrimary : .bgSurfaceVariant
        sora.borderWidth = 1

        self.heightAnchor >= 56

        passwordView.do {
            $0.sizeAnchors == CGSize(width: 24, height: 24)
            $0.leadingAnchor == leadingAnchor + 16
            $0.centerYAnchor == centerYAnchor
        }

        textLabel.do {
            $0.verticalAnchors == verticalAnchors + 8
            $0.leadingAnchor == passwordView.trailingAnchor + 16
            $0.trailingAnchor == trailingAnchor - 16
            $0.sora.text = title
            $0.sora.font = FontType.textS
            $0.sora.textColor = .fgPrimary
        }
    }
}

extension AccountExportViewController: AccountExportViewProtocol {

}
