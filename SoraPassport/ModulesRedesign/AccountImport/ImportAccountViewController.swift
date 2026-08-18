// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

import UIKit
import SoraUIKit
import SoraFoundation
import UniformTypeIdentifiers

func recoveryText(_ key: String, fallback: String) -> String {
    let selectedLocalization = LocalizationManager.shared.selectedLocalization
    let languageCode = Locale.components(fromIdentifier: selectedLocalization)[
        NSLocale.Key.languageCode.rawValue
    ]
    let candidates = [selectedLocalization, languageCode, "en"].compactMap { $0 }

    for localization in candidates where !localization.isEmpty {
        guard let path = Bundle.main.path(forResource: localization, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            continue
        }

        return bundle.localizedString(
            forKey: key,
            value: fallback,
            table: "Localizable"
        )
    }

    return fallback
}

final class ImportAccountViewController: SoramitsuViewController {
    var presenter: AccountImportPresenterProtocol?

    private(set) var displayedSourceType: AccountImportSource?
    private(set) var recoveryAccount: AccountItem?
    private(set) var isRecoveryMode = false

    private var sourceViewModel: InputViewModelProtocol?
    private var passwordViewModel: InputViewModelProtocol?
    private var derivationPathViewModel: InputViewModelProtocol?
    private var isLoading = false
    private var interactivePopWasEnabled: Bool?
    private var backButtonWasHidden: Bool?
    private var closeButtonWasEnabled: Bool?
    private var navigationWasModalInPresentation: Bool?
    private var isNavigationLocked = false
    private var jsonFileLoadID: UUID?

    private let scrollView: UIScrollView = {
        let view = UIScrollView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.alwaysBounceVertical = true
        view.keyboardDismissMode = .interactive
        return view
    }()

    private let contentStack: UIStackView = {
        let view = UIStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.axis = .vertical
        view.spacing = 16
        return view
    }()

    private let recoveryIntroLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgSecondary
        label.sora.numberOfLines = 0
        label.sora.text = recoveryText(
            "wallet.recovery.form.intro",
            fallback: "We’ll verify this backup matches your wallet before changing anything."
        )
        return label
    }()

    private let walletContextView: SoramitsuView = {
        let view = SoramitsuView()
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerRadius = .large
        view.sora.borderWidth = 1
        view.sora.borderColor = .bgSurfaceVariant
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let walletNameLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline3
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 1
        return label
    }()

    private let walletAddressLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textS
        label.sora.textColor = .fgSecondary
        label.sora.numberOfLines = 1
        label.sora.lineBreakMode = .byTruncatingMiddle
        return label
    }()

    private let subtitleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.numberOfLines = 0
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgSecondary
        return label
    }()

    private let sourceTitleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldS
        label.sora.textColor = .fgPrimary
        return label
    }()

    private lazy var pasteButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .small, type: .text(.primary))
        button.sora.title = recoveryText("wallet.recovery.paste", fallback: "Paste")
        button.accessibilityIdentifier = "walletRecovery.paste"
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.pasteSource()
        }
        return button
    }()

    private lazy var chooseFileButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .small, type: .text(.primary))
        button.sora.title = recoveryText("wallet.recovery.choose.file", fallback: "Choose file")
        button.accessibilityIdentifier = "walletRecovery.chooseFile"
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.chooseJSONFile()
        }
        button.sora.isHidden = true
        return button
    }()

    private lazy var sourceActions: UIStackView = {
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let stack = UIStackView(
            arrangedSubviews: [spacer, chooseFileButton, pasteButton]
        )
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8
        return stack
    }()

    private lazy var sourceHeader: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [sourceTitleLabel, sourceActions])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 4
        return stack
    }()

    private let sourceContainer: UIView = {
        let view = UIView()
        let palette = SoramitsuUI.shared.theme.palette
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = palette.color(.bgSurface)
        view.layer.borderColor = palette.color(.bgSurfaceVariant).cgColor
        view.layer.borderWidth = 1
        view.layer.cornerRadius = 24
        return view
    }()

    private(set) lazy var sourceTextView: UITextView = {
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.backgroundColor = .clear
        textView.font = FontType.textM.font
        textView.textColor = SoramitsuUI.shared.theme.palette.color(.fgPrimary)
        textView.tintColor = SoramitsuUI.shared.theme.palette.color(.accentPrimary)
        textView.textContainerInset = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.spellCheckingType = .no
        textView.returnKeyType = .done
        textView.isScrollEnabled = true
        textView.delegate = self
        textView.accessibilityIdentifier = "walletRecovery.source"
        return textView
    }()

    private let sourcePlaceholderLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.sora.font = FontType.textM
        label.sora.textColor = .fgSecondary
        label.sora.numberOfLines = 0
        label.isUserInteractionEnabled = false
        return label
    }()

    private let warningLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphXS
        label.sora.textColor = .statusError
        label.sora.numberOfLines = 0
        label.sora.isHidden = true
        label.accessibilityIdentifier = "walletRecovery.warning"
        return label
    }()

    private(set) lazy var passwordField: InputField = {
        let field = InputField()
        field.sora.titleLabelText = recoveryText(
            "wallet.recovery.json.password",
            fallback: "JSON backup password"
        )
        field.sora.textFieldPlaceholder = recoveryText(
            "wallet.recovery.json.password",
            fallback: "JSON backup password"
        )
        field.sora.descriptionLabelText = recoveryText(
            "wallet.recovery.json.password.hint",
            fallback: "Use the password created when this JSON backup was exported."
        )
        field.sora.textContentType = .password
        field.textField.autocapitalizationType = .none
        field.textField.autocorrectionType = .no
        field.textField.spellCheckingType = .no
        field.textField.returnKeyType = .done
        field.textField.isSecureTextEntry = true
        field.textField.delegate = self
        field.textField.tag = FieldTag.password.rawValue
        field.sora.buttonImage = UIImage(systemName: "eye")
        field.sora.buttonImageTintColor = .fgSecondary
        field.button.accessibilityLabel = recoveryText(
            "wallet.recovery.show.password",
            fallback: "Show password"
        )
        field.button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.togglePasswordVisibility()
        }
        field.sora.addHandler(for: .editingChanged) { [weak self] in
            self?.synchronizeTextFields()
        }
        field.accessibilityIdentifier = "walletRecovery.password"
        field.sora.isHidden = true
        return field
    }()

    private lazy var advancedButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .small, type: .text(.primary))
        button.sora.title = recoveryText(
            "wallet.recovery.advanced",
            fallback: "Advanced: derivation path"
        )
        button.accessibilityIdentifier = "walletRecovery.advanced"
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.toggleAdvanced()
        }
        button.sora.isHidden = true
        return button
    }()

    private(set) lazy var derivationPathField: InputField = {
        let field = InputField()
        field.sora.titleLabelText = recoveryText(
            "wallet.recovery.derivation",
            fallback: "Derivation path (optional)"
        )
        field.sora.textFieldPlaceholder = recoveryText(
            "wallet.recovery.derivation",
            fallback: "Derivation path (optional)"
        )
        field.sora.descriptionLabelText = recoveryText(
            "wallet.recovery.derivation.hint",
            fallback: "Only enter this if the original wallet used a custom derivation path."
        )
        field.textField.autocapitalizationType = .none
        field.textField.autocorrectionType = .no
        field.textField.spellCheckingType = .no
        field.textField.returnKeyType = .done
        field.textField.delegate = self
        field.textField.tag = FieldTag.derivation.rawValue
        field.sora.addHandler(for: .editingChanged) { [weak self] in
            self?.synchronizeTextFields()
        }
        field.accessibilityIdentifier = "walletRecovery.derivation"
        field.sora.isHidden = true
        return field
    }()

    private(set) lazy var verifyButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .large, type: .filled(.primary))
        button.sora.cornerRadius = .circle
        button.sora.isEnabled = false
        button.sora.title = R.string.localizable.transactionContinue(preferredLanguages: .currentLocale)
        button.accessibilityIdentifier = "walletRecovery.verify"
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            guard let self else { return }
            self.view.endEditing(true)
            self.presenter?.proceed()
        }
        return button
    }()

    private var sourceHeightConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.backButtonTitle = ""
        navigationItem.largeTitleDisplayMode = .never
        soramitsuView.sora.backgroundColor = .bgPage
        setupView()
        setupConstraints()
        configureCloseButtonIfNeeded()
        presenter?.setup()
    }

    private func setupView() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        walletContextView.addSubviews(walletNameLabel, walletAddressLabel)
        sourceContainer.addSubview(sourceTextView)
        sourceContainer.addSubview(sourcePlaceholderLabel)

        contentStack.addArrangedSubview(recoveryIntroLabel)
        contentStack.addArrangedSubview(walletContextView)
        contentStack.addArrangedSubview(subtitleLabel)
        contentStack.addArrangedSubview(sourceHeader)
        contentStack.addArrangedSubview(sourceContainer)
        contentStack.addArrangedSubview(warningLabel)
        contentStack.addArrangedSubview(passwordField)
        contentStack.addArrangedSubview(advancedButton)
        contentStack.addArrangedSubview(derivationPathField)
        contentStack.addArrangedSubview(verifyButton)

        contentStack.setCustomSpacing(24, after: walletContextView)
        contentStack.setCustomSpacing(8, after: sourceHeader)
        contentStack.setCustomSpacing(8, after: sourceContainer)
        contentStack.setCustomSpacing(24, after: derivationPathField)
    }

    private func setupConstraints() {
        let sourceHeightConstraint = sourceContainer.heightAnchor.constraint(equalToConstant: 156)
        self.sourceHeightConstraint = sourceHeightConstraint

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),

            walletNameLabel.topAnchor.constraint(equalTo: walletContextView.topAnchor, constant: 16),
            walletNameLabel.leadingAnchor.constraint(equalTo: walletContextView.leadingAnchor, constant: 16),
            walletNameLabel.trailingAnchor.constraint(equalTo: walletContextView.trailingAnchor, constant: -16),
            walletAddressLabel.topAnchor.constraint(equalTo: walletNameLabel.bottomAnchor, constant: 6),
            walletAddressLabel.leadingAnchor.constraint(equalTo: walletNameLabel.leadingAnchor),
            walletAddressLabel.trailingAnchor.constraint(equalTo: walletNameLabel.trailingAnchor),
            walletAddressLabel.bottomAnchor.constraint(equalTo: walletContextView.bottomAnchor, constant: -16),

            sourceHeightConstraint,
            sourceTextView.topAnchor.constraint(equalTo: sourceContainer.topAnchor),
            sourceTextView.leadingAnchor.constraint(equalTo: sourceContainer.leadingAnchor),
            sourceTextView.trailingAnchor.constraint(equalTo: sourceContainer.trailingAnchor),
            sourceTextView.bottomAnchor.constraint(equalTo: sourceContainer.bottomAnchor),
            sourcePlaceholderLabel.topAnchor.constraint(equalTo: sourceContainer.topAnchor, constant: 14),
            sourcePlaceholderLabel.leadingAnchor.constraint(equalTo: sourceContainer.leadingAnchor, constant: 17),
            sourcePlaceholderLabel.trailingAnchor.constraint(equalTo: sourceContainer.trailingAnchor, constant: -17)
        ])
    }

    private func configureCloseButtonIfNeeded() {
        guard navigationController?.viewControllers.first === self else { return }
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeTapped)
        )
        navigationItem.leftBarButtonItem?.accessibilityLabel = R.string.localizable.commonCancel(
            preferredLanguages: .currentLocale
        )
    }

    @objc private func closeTapped() {
        guard !isLoading else { return }
        dismiss(animated: true)
    }

    private func pasteSource() {
        guard let text = UIPasteboard.general.string else { return }
        guard applyPastedSource(text) else { return }

        UIAccessibility.post(
            notification: .announcement,
            argument: recoveryText("wallet.recovery.pasted", fallback: "Backup pasted")
        )
    }

    @discardableResult
    func applyPastedSource(_ text: String) -> Bool {
        guard let sourceType = displayedSourceType,
              let sourceViewModel else { return false }

        let normalizedText = Self.normalizedPastedSource(text, sourceType: sourceType)
        let currentValue = sourceViewModel.inputHandler.value as NSString
        let previousValue = sourceViewModel.inputHandler.value
        let accepted = sourceViewModel.inputHandler.didReceiveReplacement(
            normalizedText,
            for: NSRange(location: 0, length: currentValue.length)
        )

        guard accepted, sourceViewModel.inputHandler.completed else {
            sourceViewModel.inputHandler.changeValue(to: previousValue)
            setUploadWarning(
                message: recoveryText(
                    "wallet.recovery.paste.failed",
                    fallback: "This content could not be pasted. Check that you selected the correct recovery method."
                )
            )
            return false
        }

        setUploadWarning(message: "")
        sourceTextView.text = sourceViewModel.inputHandler.normalizedValue
        sourceTextDidChange()
        return true
    }

    static func normalizedPastedSource(
        _ text: String,
        sourceType: AccountImportSource
    ) -> String {
        switch sourceType {
        case .mnemonic:
            return MneminicProcessor()
                .process(text: text)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        case .seed, .keystore:
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func chooseJSONFile() {
        guard !isLoading, jsonFileLoadID == nil else { return }

        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.json, .plainText],
            asCopy: true
        )
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    private func showUnreadableFileError() {
        setUploadWarning(
            message: recoveryText(
                "wallet.recovery.file.unreadable",
                fallback: "This JSON file could not be read. Choose the original wallet export."
            )
        )
    }

    private func loadJSONFile(_ url: URL) {
        let loadID = UUID()
        jsonFileLoadID = loadID
        chooseFileButton.sora.isEnabled = false

        Task { [weak self] in
            let text: String? = await Task.detached(priority: .userInitiated) {
                let didAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if didAccess { url.stopAccessingSecurityScopedResource() }
                }

                guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
                      (values.fileSize ?? 0) <= 1_000_000,
                      let data = try? Data(contentsOf: url, options: .mappedIfSafe),
                      data.count <= 1_000_000 else {
                    return nil
                }

                return String(data: data, encoding: .utf8)
            }.value

            guard let self, self.jsonFileLoadID == loadID else { return }
            self.jsonFileLoadID = nil
            self.chooseFileButton.sora.isEnabled = !self.isLoading

            guard let text, self.applyPastedSource(text) else {
                self.showUnreadableFileError()
                return
            }

            UIAccessibility.post(
                notification: .announcement,
                argument: recoveryText("wallet.recovery.file.loaded", fallback: "JSON backup loaded")
            )
        }
    }

    private func togglePasswordVisibility() {
        passwordField.textField.isSecureTextEntry.toggle()
        let isSecure = passwordField.textField.isSecureTextEntry
        passwordField.sora.buttonImage = UIImage(systemName: isSecure ? "eye" : "eye.slash")
        passwordField.button.accessibilityLabel = recoveryText(
            isSecure ? "wallet.recovery.show.password" : "wallet.recovery.hide.password",
            fallback: isSecure ? "Show password" : "Hide password"
        )
    }

    private func toggleAdvanced() {
        derivationPathField.sora.isHidden.toggle()
        if !derivationPathField.sora.isHidden {
            derivationPathField.textField.becomeFirstResponder()
        }
    }

    private func synchronizeTextFields() {
        passwordViewModel?.inputHandler.changeValue(to: passwordField.textField.text ?? "")
        derivationPathViewModel?.inputHandler.changeValue(to: derivationPathField.textField.text ?? "")
        updateVerifyButton()
    }

    private func sourceTextDidChange() {
        sourcePlaceholderLabel.sora.isHidden = !sourceTextView.text.isEmpty
        updateVerifyButton()
    }

    private func updateVerifyButton() {
        verifyButton.sora.isEnabled = !isLoading && !(sourceTextView.text ?? "").isEmpty
    }
}

private extension ImportAccountViewController {
    enum FieldTag: Int {
        case password = 1
        case derivation = 2
    }
}

extension ImportAccountViewController: UITextViewDelegate {
    func textView(
        _ textView: UITextView,
        shouldChangeTextIn range: NSRange,
        replacementText text: String
    ) -> Bool {
        if text == "\n" {
            textView.resignFirstResponder()
            return false
        }

        #if arch(x86_64)
        return true
        #endif

        guard let model = sourceViewModel else { return false }
        let shouldApply = model.inputHandler.didReceiveReplacement(text, for: range)
        if !shouldApply {
            textView.text = model.inputHandler.normalizedValue
            sourceTextDidChange()
        }
        return shouldApply
    }

    func textViewDidChange(_ textView: UITextView) {
        #if arch(x86_64)
        sourceViewModel?.inputHandler.changeValue(to: textView.text)
        #endif
        sourceTextDidChange()
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        sourceContainer.layer.borderColor = SoramitsuUI.shared.theme.palette.color(.fgPrimary).cgColor
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        sourceContainer.layer.borderColor = SoramitsuUI.shared.theme.palette.color(.bgSurfaceVariant).cgColor
    }
}

extension ImportAccountViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }

    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        let model: InputViewModelProtocol?
        switch FieldTag(rawValue: textField.tag) {
        case .password:
            model = passwordViewModel
        case .derivation:
            model = derivationPathViewModel
        case .none:
            model = nil
        }

        #if arch(x86_64)
        return true
        #endif

        guard let model else { return true }
        let shouldApply = model.inputHandler.didReceiveReplacement(string, for: range)
        if !shouldApply {
            textField.text = model.inputHandler.normalizedValue
        }
        return shouldApply
    }
}

extension ImportAccountViewController: AccountImportViewProtocol {
    func resetFocus() {
        sourceTextView.becomeFirstResponder()
    }

    func setRecoveryMode(_ isRecovery: Bool, account: AccountItem?) {
        isRecoveryMode = isRecovery
        recoveryAccount = account
        recoveryIntroLabel.sora.isHidden = !isRecovery
        walletContextView.sora.isHidden = !isRecovery

        if let account {
            walletNameLabel.sora.text = account.username.isEmpty
                ? recoveryText("wallet.recovery.wallet", fallback: "Wallet")
                : account.username
            walletAddressLabel.sora.text = account.address
            walletContextView.isAccessibilityElement = true
            walletContextView.accessibilityLabel = "\(walletNameLabel.sora.text ?? ""), \(account.address)"
        }

        verifyButton.sora.title = isRecovery
            ? recoveryText("wallet.recovery.verify", fallback: "Verify and restore")
            : R.string.localizable.transactionContinue(preferredLanguages: .currentLocale)
    }

    func setSource(type: AccountImportSource) {
        displayedSourceType = type
        chooseFileButton.sora.isHidden = type != .keystore
        if isRecoveryMode {
            switch type {
            case .mnemonic:
                title = recoveryText("wallet.recovery.passphrase.title", fallback: "Restore from passphrase")
                subtitleLabel.sora.text = recoveryText(
                    "wallet.recovery.passphrase.help",
                    fallback: "Enter the recovery words for this exact wallet."
                )
                sourceTitleLabel.sora.text = R.string.localizable.commonPassphraseTitle(
                    preferredLanguages: .currentLocale
                )
                sourceHeightConstraint?.constant = 156
            case .seed:
                title = recoveryText("wallet.recovery.seed.title", fallback: "Restore from raw seed")
                subtitleLabel.sora.text = recoveryText(
                    "wallet.recovery.seed.help",
                    fallback: "Enter the 64-character hexadecimal seed for this wallet."
                )
                sourceTitleLabel.sora.text = R.string.localizable.commonRawSeed(
                    preferredLanguages: .currentLocale
                )
                sourceHeightConstraint?.constant = 96
            case .keystore:
                title = recoveryText("wallet.recovery.json.title", fallback: "Restore from JSON backup")
                subtitleLabel.sora.text = recoveryText(
                    "wallet.recovery.json.help",
                    fallback: "Paste the complete JSON export and enter its backup password."
                )
                sourceTitleLabel.sora.text = recoveryText(
                    "wallet.recovery.json.label",
                    fallback: "JSON backup"
                )
                sourceHeightConstraint?.constant = 188
            }
        } else {
            title = type.navigationTitle
            subtitleLabel.sora.text = type.containerTitle
            sourceTitleLabel.sora.text = type.titleForLocale(Locale.current)
        }
    }

    func setSource(viewModel: InputViewModelProtocol) {
        sourceViewModel = viewModel
        sourceTextView.text = viewModel.inputHandler.value
        sourceTextView.autocapitalizationType = viewModel.autocapitalization
        sourcePlaceholderLabel.sora.text = viewModel.placeholder
        sourceTextView.accessibilityLabel = sourceTitleLabel.sora.text
        sourceTextDidChange()
    }

    func setName(viewModel: InputViewModelProtocol) {}

    func setPassword(viewModel: InputViewModelProtocol) {
        passwordViewModel = viewModel
        passwordField.sora.text = viewModel.inputHandler.value
        passwordField.sora.isHidden = false
        updateVerifyButton()
    }

    func setDerivationPath(viewModel: InputViewModelProtocol) {
        derivationPathViewModel = viewModel
        derivationPathField.sora.text = viewModel.inputHandler.value
        derivationPathField.sora.textFieldPlaceholder = viewModel.placeholder.isEmpty
            ? recoveryText("wallet.recovery.derivation", fallback: "Derivation path (optional)")
            : viewModel.placeholder
        advancedButton.sora.isHidden = false
        derivationPathField.sora.isHidden = viewModel.inputHandler.value.isEmpty
    }

    func setUploadWarning(message: String) {
        warningLabel.sora.text = message
        warningLabel.sora.isHidden = message.isEmpty
        if !message.isEmpty {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }

    func setLoading(_ isLoading: Bool) {
        self.isLoading = isLoading
        setNavigationLocked(isLoading)
        sourceTextView.isEditable = !isLoading
        passwordField.sora.isEnabled = !isLoading
        derivationPathField.sora.isEnabled = !isLoading
        pasteButton.sora.isEnabled = !isLoading
        chooseFileButton.sora.isEnabled = !isLoading && jsonFileLoadID == nil
        advancedButton.sora.isEnabled = !isLoading
        verifyButton.sora.title = isLoading
            ? recoveryText("wallet.recovery.verifying", fallback: "Verifying…")
            : isRecoveryMode
                ? recoveryText("wallet.recovery.verify", fallback: "Verify and restore")
                : R.string.localizable.transactionContinue(preferredLanguages: .currentLocale)
        updateVerifyButton()

        if isLoading {
            UIAccessibility.post(notification: .announcement, argument: recoveryText(
                "wallet.recovery.verifying",
                fallback: "Verifying…"
            ))
        }
    }

    private func setNavigationLocked(_ isLocked: Bool) {
        if isLocked {
            if !isNavigationLocked {
                interactivePopWasEnabled = navigationController?
                    .interactivePopGestureRecognizer?.isEnabled
                backButtonWasHidden = navigationItem.hidesBackButton
                closeButtonWasEnabled = navigationItem.leftBarButtonItem?.isEnabled
                navigationWasModalInPresentation = navigationController?.isModalInPresentation
                isNavigationLocked = true
            }

            navigationController?.isModalInPresentation = true
            navigationController?.interactivePopGestureRecognizer?.isEnabled = false
            navigationItem.setHidesBackButton(true, animated: false)
            navigationItem.leftBarButtonItem?.isEnabled = false
        } else if isNavigationLocked {
            if let navigationWasModalInPresentation {
                navigationController?.isModalInPresentation = navigationWasModalInPresentation
            }

            if let interactivePopWasEnabled {
                navigationController?.interactivePopGestureRecognizer?.isEnabled = interactivePopWasEnabled
            }
            if let backButtonWasHidden {
                navigationItem.setHidesBackButton(backButtonWasHidden, animated: false)
            }
            if let closeButtonWasEnabled {
                navigationItem.leftBarButtonItem?.isEnabled = closeButtonWasEnabled
            }

            interactivePopWasEnabled = nil
            backButtonWasHidden = nil
            closeButtonWasEnabled = nil
            navigationWasModalInPresentation = nil
            isNavigationLocked = false
        }
    }

    func dismissPresentedController(completion: (() -> Void)?) {
        dismiss(animated: true, completion: completion)
    }
}

extension ImportAccountViewController: UIDocumentPickerDelegate {
    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]
    ) {
        guard let url = urls.first else {
            showUnreadableFileError()
            return
        }

        loadJSONFile(url)
    }
}

enum RecoveryGoogleAccountStatus: Equatable {
    case notChecked
    case checking
    case available(email: String)
    case notSaved
    case unavailable
}

final class RetainedWalletRecoveryViewController: SoramitsuViewController {
    let account: AccountItem
    var onGoogleBackup: (() -> Void)?
    var onManualSource: ((AccountImportSource) -> Void)?
    var onCancel: (() -> Void)?

    private(set) var methodControls: [RecoveryMethodControl] = []
    private(set) var googleAccountStatus: RecoveryGoogleAccountStatus = .notChecked
    private var isMethodSelectionInProgress = false
    private var googleMethodControl: RecoveryMethodControl?

    private let scrollView: UIScrollView = {
        let view = UIScrollView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.alwaysBounceVertical = true
        return view
    }()

    private let contentStack: UIStackView = {
        let view = UIStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.axis = .vertical
        view.spacing = 12
        return view
    }()

    private let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline1
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 0
        label.sora.text = recoveryText("wallet.recovery.title", fallback: "Restore wallet access")
        return label
    }()

    private let descriptionLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgSecondary
        label.sora.numberOfLines = 0
        label.sora.text = recoveryText(
            "wallet.recovery.description",
            fallback: "Your balances are safe. Restore this wallet’s key to sign transactions again."
        )
        return label
    }()

    private let walletView: SoramitsuView = {
        let view = SoramitsuView()
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerRadius = .large
        view.sora.borderWidth = 1
        view.sora.borderColor = .bgSurfaceVariant
        return view
    }()

    private let walletNameLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline3
        label.sora.textColor = .fgPrimary
        return label
    }()

    private let walletAddressLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textS
        label.sora.textColor = .fgSecondary
        label.sora.lineBreakMode = .byTruncatingMiddle
        return label
    }()

    private let methodLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldS
        label.sora.textColor = .fgPrimary
        label.sora.text = recoveryText("wallet.recovery.choose.method", fallback: "Choose a recovery method")
        return label
    }()

    init(account: AccountItem) {
        self.account = account
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = recoveryText("wallet.recovery.navigation", fallback: "Restore access")
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeTapped)
        )
        navigationItem.rightBarButtonItem?.accessibilityLabel = R.string.localizable.commonCancel(
            preferredLanguages: .currentLocale
        )
        soramitsuView.sora.backgroundColor = .bgPage
        configureContent()
    }

    private func configureContent() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        walletView.addSubviews(walletNameLabel, walletAddressLabel)
        walletNameLabel.sora.text = account.username.isEmpty
            ? recoveryText("wallet.recovery.wallet", fallback: "Wallet")
            : account.username
        walletAddressLabel.sora.text = account.address
        walletView.isAccessibilityElement = true
        walletView.accessibilityLabel = "\(walletNameLabel.sora.text ?? ""), \(account.address)"

        let google = RecoveryMethodControl(
            image: R.image.googleOptionIcon(),
            title: recoveryText("wallet.recovery.method.google", fallback: "Google Drive backup"),
            subtitle: Self.googleAccountSubtitle(for: googleAccountStatus)
        ) { [weak self] in self?.onGoogleBackup?() }
        googleMethodControl = google
        let passphrase = RecoveryMethodControl(
            image: UIImage(systemName: "text.word.spacing"),
            title: R.string.localizable.commonPassphraseTitle(preferredLanguages: .currentLocale),
            subtitle: recoveryText(
                "wallet.recovery.method.passphrase.help",
                fallback: "Enter the wallet’s recovery words."
            )
        ) { [weak self] in self?.onManualSource?(.mnemonic) }
        let seed = RecoveryMethodControl(
            image: UIImage(systemName: "key.horizontal"),
            title: R.string.localizable.commonRawSeed(preferredLanguages: .currentLocale),
            subtitle: recoveryText(
                "wallet.recovery.method.seed.help",
                fallback: "Enter the wallet’s hexadecimal raw seed."
            )
        ) { [weak self] in self?.onManualSource?(.seed) }
        let json = RecoveryMethodControl(
            image: UIImage(systemName: "doc.text"),
            title: recoveryText("wallet.recovery.method.json", fallback: "JSON backup"),
            subtitle: recoveryText(
                "wallet.recovery.method.json.help",
                fallback: "Paste an encrypted wallet export."
            )
        ) { [weak self] in self?.onManualSource?(.keystore) }
        methodControls = [google, passphrase, seed, json]

        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(descriptionLabel)
        contentStack.addArrangedSubview(walletView)
        contentStack.addArrangedSubview(methodLabel)
        methodControls.forEach(contentStack.addArrangedSubview)
        contentStack.setCustomSpacing(24, after: descriptionLabel)
        contentStack.setCustomSpacing(28, after: walletView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -28),
            walletNameLabel.topAnchor.constraint(equalTo: walletView.topAnchor, constant: 16),
            walletNameLabel.leadingAnchor.constraint(equalTo: walletView.leadingAnchor, constant: 16),
            walletNameLabel.trailingAnchor.constraint(equalTo: walletView.trailingAnchor, constant: -16),
            walletAddressLabel.topAnchor.constraint(equalTo: walletNameLabel.bottomAnchor, constant: 6),
            walletAddressLabel.leadingAnchor.constraint(equalTo: walletNameLabel.leadingAnchor),
            walletAddressLabel.trailingAnchor.constraint(equalTo: walletNameLabel.trailingAnchor),
            walletAddressLabel.bottomAnchor.constraint(equalTo: walletView.bottomAnchor, constant: -16)
        ])
    }

    @objc private func closeTapped() {
        guard !isMethodSelectionInProgress else { return }
        onCancel?()
    }

    @discardableResult
    func beginMethodSelection() -> Bool {
        guard !isMethodSelectionInProgress else { return false }

        isMethodSelectionInProgress = true
        methodControls.forEach { $0.isEnabled = false }
        navigationItem.rightBarButtonItem?.isEnabled = false
        return true
    }

    func endMethodSelection() {
        isMethodSelectionInProgress = false
        methodControls.forEach { $0.isEnabled = true }
        navigationItem.rightBarButtonItem?.isEnabled = true
    }

    func setGoogleAccountStatus(_ status: RecoveryGoogleAccountStatus) {
        googleAccountStatus = status
        googleMethodControl?.setSubtitle(Self.googleAccountSubtitle(for: status))
    }

    static func googleAccountSubtitle(for status: RecoveryGoogleAccountStatus) -> String {
        switch status {
        case .notChecked:
            return recoveryText(
                "wallet.recovery.google.account.check",
                fallback: "Tap to check for a Google account saved on this phone."
            )
        case .checking:
            return recoveryText(
                "wallet.recovery.google.account.checking",
                fallback: "Checking this phone for a saved Google sign-in…"
            )
        case .available(let email):
            let label = recoveryText(
                "wallet.recovery.google.account.signed.in",
                fallback: "Signed in as"
            )
            return "\(label) \(email)"
        case .notSaved:
            return recoveryText(
                "wallet.recovery.google.account.not.saved",
                fallback: "SORA did not save the Google email for this backup. Choose the account you used."
            )
        case .unavailable:
            return recoveryText(
                "wallet.recovery.google.account.unavailable",
                fallback: "The saved Google account could not be checked. You can choose an account."
            )
        }
    }
}

final class RecoveryMethodControl: UIControl {
    let methodTitle: String
    private(set) var methodSubtitle: String
    private let action: () -> Void
    private let subtitleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphXS
        label.sora.textColor = .fgSecondary
        label.sora.numberOfLines = 0
        return label
    }()

    init(image: UIImage?, title: String, subtitle: String, action: @escaping () -> Void) {
        methodTitle = title
        methodSubtitle = subtitle
        self.action = action
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let palette = SoramitsuUI.shared.theme.palette
        backgroundColor = palette.color(.bgSurface)
        layer.borderColor = palette.color(.bgSurfaceVariant).cgColor
        layer.borderWidth = 1
        layer.cornerRadius = 20

        let iconBackground = UIView()
        iconBackground.translatesAutoresizingMaskIntoConstraints = false
        iconBackground.backgroundColor = palette.color(.accentPrimaryContainer)
        iconBackground.layer.cornerRadius = 18

        let iconView = UIImageView(image: image)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = palette.color(.accentPrimary)

        let titleLabel = SoramitsuLabel()
        titleLabel.sora.font = FontType.headline4
        titleLabel.sora.textColor = .fgPrimary
        titleLabel.sora.text = title
        titleLabel.sora.numberOfLines = 0

        subtitleLabel.sora.text = subtitle

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.spacing = 4

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.tintColor = palette.color(.fgSecondary)
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        addSubview(iconBackground)
        iconBackground.addSubview(iconView)
        addSubview(textStack)
        addSubview(chevron)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 76),
            iconBackground.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            iconBackground.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconBackground.widthAnchor.constraint(equalToConstant: 36),
            iconBackground.heightAnchor.constraint(equalToConstant: 36),
            iconView.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 21),
            iconView.heightAnchor.constraint(equalToConstant: 21),
            textStack.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 14),
            textStack.leadingAnchor.constraint(equalTo: iconBackground.trailingAnchor, constant: 14),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -14),
            chevron.leadingAnchor.constraint(equalTo: textStack.trailingAnchor, constant: 10),
            chevron.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 8)
        ])

        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = title
        accessibilityHint = subtitle
        accessibilityIdentifier = "walletRecovery.method.\(title)"
        addTarget(self, action: #selector(activate), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.72 : 1 }
    }

    func setSubtitle(_ subtitle: String) {
        methodSubtitle = subtitle
        subtitleLabel.sora.text = subtitle
        accessibilityHint = subtitle
    }

    @objc private func activate() {
        action()
    }
}
